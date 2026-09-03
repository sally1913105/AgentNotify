#!/bin/bash
# Universal agent hook -> AgentNotify popup.
#
# Wire this to a "the agent stopped" or "the agent needs the user" event in any
# agent that runs a shell command and hands it JSON on stdin (Claude Code
# Stop / Notification, Kiro Stop / PostTaskExec, ...).
#
# Design rules:
#   - never break the host agent: always exit 0, tolerate empty/unknown stdin
#   - stay quiet when the agent already sent a better message itself
#   - dig a task description out of the payload when one is there
#
# Env overrides:
#   AGENT_NOTIFY_HOOK_AGENT    name shown on the card (default: sniffed)
#   AGENT_NOTIFY_HOOK_DEDUPE   seconds to stay quiet after a manual send (45)
#   AGENT_NOTIFY_HOOK_LEVEL    force the level for stop-style events

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARSER="$HERE/parse_payload.py"

# ---------------------------------------------------------------- locate CLI
CLI="$(command -v agent-notify 2>/dev/null || true)"
if [ -z "$CLI" ]; then
    for candidate in \
        "$HOME/.local/bin/agent-notify" \
        "$HOME/Applications/AgentNotify.app/Contents/MacOS/AgentNotify" \
        "/Applications/AgentNotify.app/Contents/MacOS/AgentNotify"; do
        if [ -x "$candidate" ]; then
            CLI="$candidate"
            break
        fi
    done
fi
[ -n "$CLI" ] || exit 0
[ -f "$PARSER" ] || exit 0

PAYLOAD="$(cat 2>/dev/null || true)"

# ------------------------------------------------------------------- agent id
AGENT="${AGENT_NOTIFY_HOOK_AGENT:-}"
if [ -z "$AGENT" ]; then
    if [ -n "${CLAUDE_PROJECT_DIR:-}${CLAUDECODE:-}${CLAUDE_CODE_ENTRYPOINT:-}" ]; then
        AGENT="claude-code"
    elif [ -n "${KIRO_WORKSPACE:-}${KIRO_SESSION_ID:-}${KIRO_IDE:-}" ]; then
        AGENT="kiro"
    else
        AGENT="agent"
    fi
fi
AGENT="$AGENT (auto)"

# --------------------------------------------------------------------- dedupe
# The CLI records "<epoch><TAB><agent>" on every send. When the last send came
# from an agent writing its own message (no "(auto)" tag), that message beats
# anything this hook can synthesize, so stay out of the way.
MARKER="$HOME/Library/Application Support/AgentNotify/last_sent"
WINDOW="${AGENT_NOTIFY_HOOK_DEDUPE:-45}"
if [ -f "$MARKER" ]; then
    LAST_LINE="$(head -1 "$MARKER" 2>/dev/null || true)"
    LAST_TS="${LAST_LINE%%$'\t'*}"
    LAST_BY="${LAST_LINE#*$'\t'}"
    case "$LAST_TS" in
        ''|*[!0-9]*) ;;
        *)
            AGE=$(( $(date +%s) - LAST_TS ))
            if [ "$AGE" -ge 0 ] && [ "$AGE" -lt "$WINDOW" ]; then
                case "$LAST_BY" in
                    *"(auto)"*) ;;
                    *) exit 0 ;;
                esac
            fi
            ;;
    esac
fi

# ------------------------------------------------------------- parse payload
PARSED="$(AN_PAYLOAD="$PAYLOAD" python3 "$PARSER" 2>/dev/null)"
[ -n "$PARSED" ] || exit 0

IFS=$'\t' read -r LEVEL TITLE BODY PROJECT <<< "$PARSED"
[ -n "${TITLE:-}" ] || exit 0

ARGS=(send --agent "$AGENT" --level "${LEVEL:-success}" --title "$TITLE" --quiet)
[ -n "${BODY:-}" ] && ARGS+=(--body "$BODY")
[ -n "${PROJECT:-}" ] && ARGS+=(--project "$PROJECT")
case "${LEVEL:-}" in
    action|error) ARGS+=(--sticky) ;;
esac

"$CLI" "${ARGS[@]}" >/dev/null 2>&1 || true
exit 0
