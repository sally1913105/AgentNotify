#!/bin/bash
# Wire AgentNotify into your agents.
#
#   bash scripts/install_integrations.sh
#       Install the skill for Codex, Cursor, Kiro, and Claude Code (additive, reversible).
#
#   bash scripts/install_integrations.sh --claude-hooks
#       Also merge Stop / Notification hooks into ~/.claude/settings.json, so
#       every finished turn pops a card without the model having to remember.
#       A timestamped backup is written first.
#
#   bash scripts/install_integrations.sh --kiro-hook /path/to/project
#       Also drop a Kiro Stop hook into that project's .kiro/hooks/.
set -euo pipefail
cd "$(dirname "$0")/.."
REPO="$PWD"

SKILL_SRC="$REPO/skills/agent-notify/SKILL.md"
CODEX_META_SRC="$REPO/skills/agent-notify/agents/openai.yaml"
HOOK="bash \"$REPO/integrations/hooks/notify_hook.sh\""
HELPER="$REPO/scripts/_integrate.py"
DO_CLAUDE_HOOKS=0
KIRO_PROJECT=""

while [ $# -gt 0 ]; do
    case "$1" in
        --claude-hooks) DO_CLAUDE_HOOKS=1 ;;
        --kiro-hook)
            shift
            [ $# -gt 0 ] || { echo "--kiro-hook requires a project path" >&2; exit 2; }
            KIRO_PROJECT="$1"
            ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

# ------------------------------------------------------------------- skills
# Copy the skill instead of symlinking it, so it remains usable after the
# repository is moved or removed.
for skills_root in "$HOME/.agents/skills" "$HOME/.codex/skills" "$HOME/.kiro/skills" "$HOME/.claude/skills" "$HOME/.cursor/skills"; do
    target="$skills_root/agent-notify"
    mkdir -p "$target/agents"
    cp "$SKILL_SRC" "$target/SKILL.md"
    cp "$CODEX_META_SRC" "$target/agents/openai.yaml"
    echo "==> skill: $target/SKILL.md (copied)"
done

# -------------------------------------------------------------- claude hooks
if [ "$DO_CLAUDE_HOOKS" = "1" ]; then
    SETTINGS="$HOME/.claude/settings.json"
    mkdir -p "$HOME/.claude"
    if [ -f "$SETTINGS" ]; then
        BACKUP="$SETTINGS.bak-$(date +%Y%m%d%H%M%S)"
        cp "$SETTINGS" "$BACKUP"
        echo "==> Backed up $BACKUP"
    fi
    python3 "$HELPER" claude "$HOOK" "$SETTINGS"
else
    echo
    echo "Claude Code automatic popups (optional): merge into ~/.claude/settings.json,"
    echo "or run bash scripts/install_integrations.sh --claude-hooks"
    python3 "$HELPER" snippet "$HOOK"
fi

# ----------------------------------------------------------------- kiro hook
if [ -n "$KIRO_PROJECT" ]; then
    if [ ! -d "$KIRO_PROJECT" ]; then
        echo "!! Directory does not exist: $KIRO_PROJECT" >&2
        exit 1
    fi
    DEST_DIR="$KIRO_PROJECT/.kiro/hooks"
    mkdir -p "$DEST_DIR"
    python3 "$HELPER" kiro "$HOOK" \
        "$REPO/integrations/kiro/agent-notify-on-stop.json" \
        "$DEST_DIR/agent-notify-on-stop.json"
    echo "==> Kiro hook: $DEST_DIR/agent-notify-on-stop.json"
fi

echo
echo "Verify with: agent-notify doctor"
echo "Restart the agent session so it can discover the updated Skill."
