**English** | [한국어](permissions.ko.md)

# Permissions & policy

> How CCTG auto-approves harmless actions and blocks dangerous ones so a headless bot never stalls on a permission prompt.

## Table of Contents

- [Why this exists](#why-this-exists)
- [Two layers](#two-layers)
  - [How they are injected](#how-they-are-injected)
  - [Precedence](#precedence)
- [Shared settings (all bots)](#shared-settings-all-bots)
  - [Default contents](#default-contents)
  - [Merge with the global settings.json](#merge-with-the-global-settingsjson)
  - [`cctg common` subcommands](#cctg-common-subcommands)
- [Per-bot settings](#per-bot-settings)
  - [`cctg config <name>` permission bits](#cctg-config-name-permission-bits)
- [Permission modes](#permission-modes)
- [Applying changes](#applying-changes)
- [Recommended setup](#recommended-setup)

## Why this exists

A CCTG bot runs as an interactive Claude Code TUI inside tmux, but the operator is not sitting in front of that TUI — they only interact over Telegram or Discord. So when a permission prompt appears, nobody can answer it and the bot stalls.

CCTG's model is "auto-approve what's harmless, block what's dangerous via deny" — eliminating the gray zone where prompts appear.

## Two layers

| Layer | Stored at | Edit command |
|---|---|---|
| Shared (all bots) | `~/.claude/channels/cctg-shared.settings.json` | `cctg common ...` |
| Per-bot (takes precedence) | `~/.claude/channels/<name>/launch.env` | `cctg config <name> ...` |

### How they are injected

On `up`/`restart`, CCTG launches each bot with the shared settings file as `claude --settings <file>`, then layers the per-bot launch.env on top:

```bash
caffeinate -is claude --channels <plugin> \
  --settings ~/.claude/channels/cctg-shared.settings.json \
  ${MODE_ARG} \
  ${CLAUDE_EXTRA_ARGS:-}
```

The per-bot `launch.env` is sourced before launch. If `CCTG_PERMISSION_MODE` is set there, it becomes `--permission-mode <mode>` (`MODE_ARG`); if empty, no `--permission-mode` is passed. `CLAUDE_EXTRA_ARGS` is appended verbatim as additional `claude` arguments.

### Precedence

The per-bot `CCTG_PERMISSION_MODE`, if set, overrides the shared `defaultMode` (via `--permission-mode`). Leave it empty to follow the shared value.

The shared settings file path is the env var `CC_TG_SHARED_SETTINGS` (default `$CC_CHANNELS_DIR/cctg-shared.settings.json`, where `CC_CHANNELS_DIR` defaults to `~/.claude/channels`).

## Shared settings (all bots)

The shared settings file is auto-created on the first `add`/`up` if it does not already exist.

### Default contents

```json
{
  "permissions": {
    "defaultMode": "bypassPermissions",
    "deny": [
      "Bash(sudo *)",
      "Bash(rm -rf /*)",
      "Bash(rm -rf ~*)",
      "Bash(rm -rf .*)",
      "Bash(git push --force*)",
      "Bash(git push -f*)",
      "Bash(git reset --hard*)",
      "Bash(git clean -fd*)",
      "Bash(git clean -fdx*)",
      "Read(~/.ssh/**)",
      "Read(~/.aws/**)"
    ],
    "allow": []
  }
}
```

### Merge with the global settings.json

This file merges with the deny rules and PreToolUse hooks of the global `~/.claude/settings.json`: deny is a union, and deny wins over allow. The deny rules and PreToolUse hooks (for example `git-guard`) still apply even under `bypassPermissions`, so dangerous actions are blocked there.

### `cctg common` subcommands

```bash
cctg common                          # print current shared settings (= common show)
cctg common edit                     # edit directly with $EDITOR
cctg common mode acceptEdits         # change the shared defaultMode
cctg common deny add 'Bash(sudo *)'  # add a deny rule
cctg common deny rm  'Bash(sudo *)'  # remove a deny rule
cctg common allow add 'Read(/data/**)'   # add an allow rule
cctg common allow rm  'Read(/data/**)'   # remove an allow rule
```

Structured edits (`mode` / `deny` / `allow`) require `jq`; without `jq`, use `common edit`. `show` and `edit` work without `jq`. The `deny`/`allow add` operations use a unique-set union; `rm` removes the exact rule.

## Per-bot settings

Per-bot options live in `~/.claude/channels/<name>/launch.env`. The relevant keys are `CCTG_PERMISSION_MODE` (this bot's permission mode; empty follows the shared value) and `CLAUDE_EXTRA_ARGS` (extra `claude` arguments for this bot).

### `cctg config <name>` permission bits

```bash
cctg config myproject                          # show (channel, mode, snapshot, launch.env)
cctg config myproject mode bypassPermissions   # set this bot's permission mode
cctg config myproject mode clear               # clear → follow the shared value
cctg config myproject args "--model opus"      # extra claude args for this bot
cctg config myproject edit                     # edit launch.env directly
```

## Permission modes

Valid values: `acceptEdits | auto | bypassPermissions | default | dontAsk | plan`.

| Mode | Behavior in the headless bot context |
|---|---|
| `bypassPermissions` | Auto-approve everything. Deny rules and PreToolUse hooks (git-guard, etc.) still apply → dangerous actions are blocked here. (CCTG default) |
| `acceptEdits` | Only edits and safe fs commands are automatic; other Bash/network actions prompt — can stall when headless |
| `dontAsk` | Auto-rejects the gray zone instead of prompting (safe, but silently fails if the action isn't in `allow`) |
| `default` / `auto` / `plan` | Standard Claude Code modes; `default`/`acceptEdits`/`plan` can prompt and thus stall a headless bot |

## Applying changes

Changes take effect on `up`/`restart` (if the bot is already running, run `cctg restart <name>`). Check the applied mode with `cctg status` / `cctg doctor`.

## Recommended setup

The default — shared `bypassPermissions` plus the deny safety net, with the per-bot mode left empty — is the intended baseline for headless bots. Tighten the policy by adding deny rules rather than switching to prompting modes (`default`/`acceptEdits`/`plan`), which can stall a bot that nobody is watching.

---

[← Back to README](../README.md)

See also: [commands.md](commands.md), [configuration.md](configuration.md)
