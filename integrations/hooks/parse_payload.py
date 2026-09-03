#!/usr/bin/env python3
"""Turn an agent hook payload into AgentNotify card fields.

Reads the raw JSON from the AN_PAYLOAD environment variable (not stdin, so the
calling shell keeps control of it) and prints one tab-separated line:

    level <TAB> title <TAB> body <TAB> project

Exit codes:
    0  fields printed
    3  nothing worth announcing (caller should stay silent)
"""

import json
import os
import re
import sys

MAX_TITLE = 46
MAX_BODY = 260
NEEDS_USER_TYPES = {
    "permission_prompt",
    "agent_needs_input",
    "elicitation_dialog",
    "elicitation_url_dialog",
}
NEEDS_USER_EVENTS = {"notification", "teammateidle", "permissionrequest"}


def load() -> dict:
    raw = os.environ.get("AN_PAYLOAD", "").strip()
    if not raw.startswith("{"):
        return {}
    try:
        parsed = json.loads(raw)
    except ValueError:
        return {}
    return parsed if isinstance(parsed, dict) else {}


def pick(data: dict, *keys: str) -> str:
    for key in keys:
        value = data.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return ""


def collapse(text: str) -> str:
    """Flatten agent markdown into one readable line."""
    if not text:
        return ""
    fence = chr(96) * 3
    text = re.sub(re.escape(fence) + ".*?" + re.escape(fence), " ", text, flags=re.S)
    text = re.sub(r"^\s*[-*+]\s+", " ", text, flags=re.M)
    text = re.sub(r"^\s*#+\s*", "", text, flags=re.M)
    text = re.sub("[" + chr(96) + r"*_#>|]", "", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def head_sentence(text: str, limit: int = MAX_TITLE) -> str:
    parts = re.split(r"(?<=[。！？!?.])\s*", text)
    head = parts[0].strip() if parts else ""
    if not head or len(head) > limit:
        head = text[:limit].strip()
    return head


def tail_after(text: str, head: str) -> str:
    """Body text with the part already shown as the title removed."""
    if not text or not head:
        return text
    if text.startswith(head):
        return text[len(head):].lstrip(" 　·-—:：,，。.")
    return text


def main() -> int:
    data = load()

    # Claude Code sets this while it is already continuing because of a stop
    # hook; announcing again would double up.
    if data.get("stop_hook_active") is True:
        return 3

    event = pick(data, "hook_event_name", "trigger", "event", "eventName").lower()
    ntype = pick(data, "notification_type")
    cwd = pick(data, "cwd", "workspace", "workspaceRoot", "projectPath", "project")
    summary = collapse(pick(data, "last_assistant_message", "message", "text", "summary"))

    needs_user = ntype in NEEDS_USER_TYPES or event in NEEDS_USER_EVENTS or bool(ntype)

    if needs_user:
        level = "action"
        title = head_sentence(summary, 56) if summary else "Agent needs your input"
        body = tail_after(summary, title) or "An operation is waiting for your confirmation. Check the session."
    else:
        level = os.environ.get("AGENT_NOTIFY_HOOK_LEVEL", "").strip() or "success"
        if summary:
            title = head_sentence(summary)
            # May be empty when the summary is a single sentence; the card just
            # renders the title in that case.
            body = tail_after(summary, title)
        else:
            project_name = os.path.basename(cwd.rstrip("/")) if cwd else ""
            title = f"Task complete: {project_name}" if project_name else "Agent task complete"
            body = "This task has finished."

    if len(body) > MAX_BODY:
        body = body[:MAX_BODY].rstrip() + "…"

    fields = [f.replace("\t", " ") for f in (level, title, body, cwd)]
    sys.stdout.write("\t".join(fields) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
