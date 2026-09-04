# AgentNotify

AgentNotify is a lightweight macOS menu bar app and CLI for AI coding agents. It shows task completion, progress, errors, and requests for human input as unobtrusive toast cards in the corner of the active display. Unread messages remain available from the menu bar.

The repository contains the native AppKit app, the `agent-notify` CLI, cross-agent hooks, and an installable Agent Skill. It works with any agent that can run a shell command, including Codex, Claude Code, Cursor, and Kiro.

## Requirements

- macOS 13 or newer
- Xcode Command Line Tools (`xcode-select --install`)
- Python 3 for hook payload parsing

No Xcode project or full Xcode installation is required. The build script compiles the Swift sources directly and selects a compatible macOS SDK.

## Install the app and CLI

### Prebuilt npm installation (recommended)

Published releases include prebuilt Apple Silicon and Intel app bundles. This is the simplest installation path and does not require Xcode or Xcode Command Line Tools:

```bash
npm install -g @sallyhuang/agent-notify@latest
```

The npm package installs the app, the `agent-notify` CLI, and the Skill for Codex, Claude Code, and Cursor. It supports macOS only. npm lifecycle scripts must be enabled (do not use `--ignore-scripts`).

Version 1.0.2 includes a bundled Apple Silicon app with a custom AgentNotify application icon. Intel installations use the matching GitHub Release asset. Each package version matches its GitHub release tag.

### Build from source

Clone the repository, then run:

```bash
git clone https://github.com/sally1913105/AgentNotify.git
cd AgentNotify
bash scripts/install.sh
```

This builds and installs `AgentNotify.app` in `~/Applications` and links the CLI to `~/.local/bin/agent-notify`. Add that directory to `PATH` if needed:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Start AgentNotify automatically at login with:

```bash
bash scripts/install.sh --login
```

Verify the installation:

```bash
agent-notify doctor
```

## Send a notification

```bash
agent-notify send --agent codex --level success \
  --title "Refactor complete" \
  --body "Split the auth module into three files and passed all tests." \
  --project "$PWD"
```

Available levels:

| Level | Use | Dismissal |
| --- | --- | --- |
| `success` | A task completed normally | Auto-dismisses after 15 seconds |
| `info` | A useful progress update | Auto-dismisses after 15 seconds |
| `action` | The agent needs a decision or confirmation | Sticky by default |
| `error` | A failure needs attention | Sticky by default |

Useful options:

| Option | Description |
| --- | --- |
| `-t, --title` | Short conclusion shown as the card title |
| `-b, --body` | Task details; use `-` to read from stdin |
| `--body-file <path>` | Read the body from a file |
| `-a, --agent` | Agent name shown on the card |
| `-p, --project` | Project path or display name |
| `-l, --level` | `info`, `success`, `action`, or `error` |
| `--timeout <seconds>` | Auto-dismiss delay; `0` keeps the card visible |
| `--sticky` | Shorthand for `--timeout 0` |
| `--no-launch` | Do not start the menu bar app automatically |
| `-q, --quiet` | Suppress the queue confirmation |

Long output can be piped through stdin:

```bash
pytest 2>&1 | tail -20 | agent-notify send -a codex -l error \
  --title "Tests failed" --body - --project "$PWD"
```

## Install the Skill and integrations

The app and CLI must be installed before an agent can send notifications. Then install the Skill for supported agents:

```bash
bash scripts/install_integrations.sh
```

For a Skill-only installation with the community `skills` CLI:

```bash
npx --yes skills add sally1913105/AgentNotify \
  --skill agent-notify --agent '*' --global --copy --yes
```

Codex users can install directly from GitHub:

```bash
python3 "${CODEX_HOME:-$HOME/.codex}/skills/.system/skill-installer/scripts/install-skill-from-github.py" \
  --repo sally1913105/AgentNotify --path skills/agent-notify
```

The Skill contains guidance for writing useful notification titles and bodies. It does not install the macOS app; run `scripts/install.sh` for that.

### Automatic hooks

Install Claude Code `Stop` and `Notification` hooks (the script backs up an existing settings file):

```bash
bash scripts/install_integrations.sh --claude-hooks
```

Install a Kiro stop hook into a project:

```bash
bash scripts/install_integrations.sh --kiro-hook /path/to/project
```

The generic hook in `integrations/hooks/notify_hook.sh` accepts JSON on stdin and can be connected to any agent event that runs shell commands. Hooks always exit successfully so they cannot break the host agent. Manual notifications take precedence over generic hook notifications for 45 seconds; change that window with `AGENT_NOTIFY_HOOK_DEDUPE`.

## Interaction

- Press `Esc` to hide visible cards without marking them read.
- Click a card or its close button to dismiss it and mark it read.
- Click the menu bar bell to review history, replay a message, show unread messages, or clear history.

Global `Esc` handling requires Accessibility permission for AgentNotify in System Settings > Privacy & Security > Accessibility. Cards still work without it. Set `stealFocus` to `true` in the config if you want cards to become the active window.

## Configuration

Configuration is stored at `~/Library/Application Support/AgentNotify/config.json`. The app creates a template automatically. Edit it and choose **Reload Configuration** from the menu.

| Key | Default | Description |
| --- | --- | --- |
| `position` | `bottomRight` | `bottomRight`, `topRight`, `bottomLeft`, or `topLeft` |
| `screen` | `mouse` | Display under the mouse, `main`, or a numeric screen index |
| `alwaysOnTop` | `true` | Use the status bar window level above normal windows |
| `autoDismissSeconds` | `15` | Default timeout for non-sticky cards |
| `maxVisible` | `3` | Maximum number of visible cards |
| `stealFocus` | `false` | Activate AgentNotify when showing a card |
| `sound` / `soundName` | `true` / `Ping` | Play a system sound |
| `cardWidth` / `margin` / `gap` | `380` / `16` / `10` | Card width, screen margin, and stack gap |
| `escClosesAll` | `true` | Hide all cards or only the newest card on `Esc` |
| `historyLimit` | `60` | Number of messages retained in history |

## How it works

The CLI writes an atomic JSON file into `~/Library/Application Support/AgentNotify/inbox/`. The menu bar app watches that directory with `kqueue` and a polling fallback, then moves handled messages to the archive. No port, socket, or agent-side client library is required. The same binary serves as the UI and CLI; launching it without arguments starts the menu bar app.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| No card appears | Run `agent-notify doctor`; start the app with `open -g ~/Applications/AgentNotify.app` if needed |
| Card appears on the wrong display | Keep `screen` as `mouse`, or set it to `main` or a screen index |
| Card is behind another window | Confirm `alwaysOnTop` is `true` |
| Global `Esc` does nothing | Grant Accessibility permission or dismiss cards by clicking |
| Hook does not fire | Test it with `echo '{"hook_event_name":"Stop","last_assistant_message":"Test"}' | bash integrations/hooks/notify_hook.sh` |
| Inbox files accumulate | The UI is not running; start it and pending messages will be drained |

## Repository layout

```text
Sources/AgentNotify/             Swift AppKit sources
resources/Info.plist             Menu bar app bundle metadata
scripts/make_app.sh              Compile and assemble AgentNotify.app
scripts/install.sh               Install the app and CLI
scripts/install_integrations.sh  Install Skills and optional hooks
skills/agent-notify/             Standard cross-agent Skill package
integrations/hooks/              Generic shell hook and JSON payload parser
integrations/                    Compatibility Skill and agent-specific templates
```

## License

MIT. See [LICENSE](LICENSE).

## Publishing

Maintainers can publish a new prebuilt version with:

```bash
npm version patch
git push origin main --follow-tags
```

After the GitHub Actions release completes, publish the matching npm package:

```bash
npm publish --access public
```
