---
name: agent-notify
description: Show macOS menu bar notifications for agent task completion, progress, errors, or requests for human input. Use when a long task finishes, a decision is needed, work is blocked, or the user explicitly asks to be notified.
---

# AgentNotify

Use the `agent-notify` CLI to tell the user when work finishes or needs attention. The menu bar app shows a toast card and keeps unread history.

## Prerequisite

The macOS app and CLI must be installed before sending a notification. From a clone of the AgentNotify repository, run:

```bash
bash scripts/install.sh
```

If the command is not on `PATH`, use `$HOME/.local/bin/agent-notify` or `~/Applications/AgentNotify.app/Contents/MacOS/AgentNotify`.

## Command

```bash
agent-notify send --agent <agent-name> --level <level> \
  --title "<conclusion>" \
  --body "<what changed, result, and next action>" \
  --project "$PWD"
```

Check the installation with `agent-notify doctor`.

## Optional iMessage forwarding

AgentNotify can forward selected cards through macOS Messages to a configured iMessage recipient. It is disabled by default. Enable it in `~/Library/Application Support/AgentNotify/config.json`:

```json
"imessage": {
  "enabled": true,
  "recipient": "you@example.com",
  "levels": ["action", "error"]
}
```

The Mac must be signed in to Messages. On the first forwarded message, allow AgentNotify to control Messages in the macOS automation prompt. Keep credentials and private source code out of forwarded message bodies.

## Levels

| Level | Use | Behavior |
| --- | --- | --- |
| `success` | Work completed normally | Auto-dismisses after 15 seconds |
| `info` | Useful progress update | Auto-dismisses after 15 seconds |
| `action` | User must decide, confirm, or provide information | Sticky |
| `error` | Work failed or is blocked | Sticky |

Send one useful notification per task, not one for every file edit. Do not send a start message for a short task when the user is already watching the conversation.

## Writing cards

Make `--title` a conclusion that can be understood at a glance:

```text
Good: "Auth refactor complete: all tests pass"
Weak: "I finished the task you asked for"
```

Use `--body` for two or three short sentences covering what changed, the result, and what the user should do next. Keep it under 200 characters when possible. Always include `--project "$PWD"` so the project is identifiable when several repositories are open.

## Examples

```bash
agent-notify send --agent codex --level success \
  --title "Auth refactor complete" \
  --body "Extracted TokenStore and SessionGuard; all six tests pass." \
  --project "$PWD"
```

```bash
agent-notify send --agent claude-code --level action --sticky \
  --title "Migration strategy needs confirmation" \
  --body "The migration can briefly stop writes or use a slower zero-downtime rollout. Choose one and I will continue." \
  --project "$PWD"
```

```bash
pytest 2>&1 | tail -20 | agent-notify send --agent cursor --level error \
  --title "Three tests failed" --body - --project "$PWD"
```
