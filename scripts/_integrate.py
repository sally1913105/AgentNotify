#!/usr/bin/env python3
"""JSON surgery for install_integrations.sh.

Kept out of the shell script because macOS still ships bash 3.2, which mangles
heredocs nested inside command substitution.

    _integrate.py snippet     <hook-command>
    _integrate.py claude      <hook-command> <settings.json>
    _integrate.py kiro        <hook-command> <template.json> <dest.json>
"""

import json
import sys

CLAUDE_EVENTS = [
    # Stop has no matcher support: it always fires when the turn ends.
    ("Stop", None),
    # The moments where the agent is waiting on a human.
    ("Notification", "permission_prompt|agent_needs_input|elicitation_dialog"),
]


def handler(command: str) -> dict:
    return {"type": "command", "command": command, "timeout": 15}


def groups_for(command: str) -> dict:
    hooks: dict = {}
    for event, matcher in CLAUDE_EVENTS:
        group = {"hooks": [handler(command)]}
        if matcher:
            group["matcher"] = matcher
        hooks[event] = [group]
    return hooks


def cmd_snippet(command: str) -> int:
    print(json.dumps({"hooks": groups_for(command)}, indent=2, ensure_ascii=False))
    return 0


def cmd_claude(command: str, path: str) -> int:
    try:
        with open(path) as handle:
            settings = json.load(handle)
        if not isinstance(settings, dict):
            settings = {}
    except (FileNotFoundError, ValueError):
        settings = {}

    hooks = settings.get("hooks")
    if not isinstance(hooks, dict):
        hooks = settings["hooks"] = {}

    for event, matcher in CLAUDE_EVENTS:
        existing = hooks.get(event)
        if not isinstance(existing, list):
            existing = hooks[event] = []

        already = any(
            isinstance(entry, dict)
            and any(
                isinstance(h, dict) and h.get("command") == command
                for h in entry.get("hooks", [])
            )
            for entry in existing
        )
        if already:
            print(f"    {event}: already present, skipped")
            continue

        group = {"hooks": [handler(command)]}
        if matcher:
            group["matcher"] = matcher
        existing.append(group)
        print(f"    {event}: added")

    with open(path, "w") as handle:
        json.dump(settings, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    print(f"==> Updated {path}")
    return 0


def cmd_kiro(command: str, template_path: str, dest: str) -> int:
    with open(template_path) as handle:
        template = json.load(handle)
    for hook in template.get("hooks", []):
        action = hook.get("action")
        if isinstance(action, dict) and action.get("command") == "__HOOK__":
            action["command"] = command
    with open(dest, "w") as handle:
        json.dump(template, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    return 0


def main(argv: list) -> int:
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    mode = argv[0]
    if mode == "snippet":
        return cmd_snippet(argv[1])
    if mode == "claude":
        return cmd_claude(argv[1], argv[2])
    if mode == "kiro":
        return cmd_kiro(argv[1], argv[2], argv[3])
    print(f"unknown mode: {mode}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
