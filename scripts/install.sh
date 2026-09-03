#!/bin/bash
# Build AgentNotify.app, install it to ~/Applications, and expose the
# `agent-notify` CLI on PATH.
#
#   bash scripts/install.sh            build + install + relaunch
#   bash scripts/install.sh --login    also start it automatically at login
set -euo pipefail
cd "$(dirname "$0")/.."
REPO="$PWD"

APP_DEST="${APP_DEST:-$HOME/Applications}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
APP="$APP_DEST/AgentNotify.app"
EXE="$APP/Contents/MacOS/AgentNotify"
LOCK="$HOME/Library/Application Support/AgentNotify/agentnotify.lock"
LOGIN_ITEM=0

for arg in "$@"; do
    case "$arg" in
        --login) LOGIN_ITEM=1 ;;
        *) echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done

bash scripts/make_app.sh

# Stop the resident instance so we don't overwrite a running binary.
if [[ -f "$LOCK" ]]; then
    PID="$(head -1 "$LOCK" 2>/dev/null | tr -d '[:space:]')"
    if [[ "$PID" =~ ^[0-9]+$ ]] && kill -0 "$PID" 2>/dev/null; then
        echo "==> Stopping the running instance (pid $PID)"
        kill "$PID" 2>/dev/null || true
        for _ in 1 2 3 4 5 6 7 8 9 10; do
            kill -0 "$PID" 2>/dev/null || break
            sleep 0.2
        done
    fi
fi

echo "==> Installing to $APP"
mkdir -p "$APP_DEST"
# ditto overwrites in place, so there is nothing to delete first.
ditto build/AgentNotify.app "$APP"

echo "==> Linking CLI to $BIN_DIR/agent-notify"
mkdir -p "$BIN_DIR"
ln -sf "$EXE" "$BIN_DIR/agent-notify"

if [[ "$LOGIN_ITEM" == "1" ]]; then
    PLIST="$HOME/Library/LaunchAgents/com.hjh.agentnotify.plist"
    echo "==> Writing login item $PLIST"
    mkdir -p "$HOME/Library/LaunchAgents"
    cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.hjh.agentnotify</string>
    <key>ProgramArguments</key>
    <array>
        <string>$EXE</string>
        <string>--ui</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>ProcessType</key>
    <string>Interactive</string>
</dict>
</plist>
PLIST_EOF
    launchctl bootout "gui/$UID/com.hjh.agentnotify" 2>/dev/null || true
    launchctl bootstrap "gui/$UID" "$PLIST" 2>/dev/null || \
        launchctl load -w "$PLIST" 2>/dev/null || \
        echo "    (launchctl registration failed; the login item may still start it after reboot)"
fi

echo "==> Starting AgentNotify"
open -g "$APP"
sleep 1.5
"$EXE" doctor || true

case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *)
        echo
        echo "!! $BIN_DIR is not on PATH. Add this line to ~/.zshrc:"
        echo "   export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo "   (The app still works without this; the absolute path is $EXE)"
        ;;
esac

echo
echo "Installation complete. Try it:"
echo "  agent-notify send -a test -l success -t \"Installation complete\" -b \"A card should slide in from the bottom-right corner.\" -p \"$REPO\""
echo "Install agent integrations: bash scripts/install_integrations.sh"
