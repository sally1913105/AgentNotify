---
name: agent-notify
description: Show macOS menu bar notifications for agent task completion, progress, errors, or requests for human input. Use when a long task finishes, a decision is needed, work is blocked, or the user explicitly asks to be notified.
---

# AgentNotify integration

Use the `agent-notify` CLI to notify the user about meaningful task outcomes. Install the app first from the repository with `bash scripts/install.sh`, then send a card:

```bash
agent-notify send --agent <agent-name> --level <level> \
  --title "<conclusion>" \
  --body "<what changed, result, and next action>" \
  --project "$PWD"
```

Use `success` for completed work, `info` for useful progress, `action` when the user must decide or confirm something, and `error` when work is blocked or failed. `action` and `error` cards are sticky; `success` and `info` cards dismiss after 15 seconds.

Send one concise notification per meaningful task. Keep the title as a conclusion and the body to two or three sentences. Always include `--project "$PWD"` so the project is identifiable.

See the canonical package at [`skills/agent-notify/SKILL.md`](../skills/agent-notify/SKILL.md).
