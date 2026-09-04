#!/bin/bash
# Build AgentNotify.app — a menu bar agent notifier with bottom-right toasts.
# No Xcode project needed, just Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")/.."

ARCH="$(uname -m)"
DEPLOY="${DEPLOY:-13.0}"
TARGET="${ARCH}-apple-macosx${DEPLOY}"
BIN_NAME="AgentNotify"
APP="build/${BIN_NAME}.app"

# Command Line Tools ship SDKs that can be newer than the bundled swiftc
# (e.g. an SDK built with Swift 6.2 against a 6.1 compiler refuses to load).
# Probe the installed SDKs newest-first and take the first one that compiles.
pick_sdk() {
    if [[ -n "${SDK:-}" ]]; then
        echo "$SDK"
        return
    fi
    local probe out sdk found=""
    local -a candidates=()
    probe="$(mktemp -d)"
    printf 'print("ok")\n' > "$probe/probe.swift"
    out="$probe/probe.bin"

    while IFS= read -r sdk; do
        [[ -n "$sdk" ]] && candidates+=("$sdk")
    done < <({
        xcrun --show-sdk-path 2>/dev/null || true
        ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX*.sdk 2>/dev/null | sort -Vr
        ls -d /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX*.sdk 2>/dev/null | sort -Vr
    } | awk 'NF && !seen[$0]++')

    for sdk in "${candidates[@]}"; do
        if swiftc -sdk "$sdk" -target "$TARGET" -o "$out" "$probe/probe.swift" >/dev/null 2>&1; then
            found="$sdk"
            break
        fi
    done

    rm -rf "$probe"
    [[ -n "$found" ]] || return 1
    echo "$found"
}

SDK="$(pick_sdk || true)"
if [[ -z "$SDK" ]]; then
    echo "!! Could not find a macOS SDK compatible with the current swiftc" >&2
    echo "   swiftc: $(swiftc --version | head -1)" >&2
    exit 1
fi

echo "==> SDK    : $SDK"
echo "==> Target : $TARGET"

mkdir -p build
echo "==> Compiling..."
swiftc -O \
    -sdk "$SDK" \
    -target "$TARGET" \
    -o "build/$BIN_NAME" \
    Sources/AgentNotify/*.swift \
    -framework AppKit

echo "==> Assembling bundle..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "build/$BIN_NAME" "$APP/Contents/MacOS/$BIN_NAME"
cp resources/Info.plist "$APP/Contents/Info.plist"
if [[ ! -f resources/AppIcon.icns ]]; then
    echo "==> Generating application icon..."
    python3 scripts/generate_icon.py
fi
cp resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc signature keeps macOS from complaining about an unsigned bundle and
# gives the app a stable identity for the Accessibility permission list.
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || \
    echo "    (codesign skipped)"

echo "==> Done: $APP"
