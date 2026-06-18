**English** | [한국어](telegram-setup.ko.md)

# Telegram bot setup

> Step-by-step: create a brand-new Telegram bot, register it with `cctg add`, and start chatting with your Claude Code project from your phone.

## Table of Contents

- [Before you start](#before-you-start)
- [Step 1 — Install the Telegram plugin](#step-1--install-the-telegram-plugin)
- [Step 2 — Create a NEW bot with BotFather](#step-2--create-a-new-bot-with-botfather)
- [Step 3 — Find your numeric Telegram ID](#step-3--find-your-numeric-telegram-id)
- [Step 4 — Register the bot with `cctg add`](#step-4--register-the-bot-with-cctg-add)
  - [Interactive registration](#interactive-registration)
  - [Non-interactive registration (CI / scripting)](#non-interactive-registration-ci--scripting)
- [Step 5 — Start the bot](#step-5--start-the-bot)
- [Step 6 — Verify](#step-6--verify)
- [Troubleshooting](#troubleshooting)
- [See also](#see-also)

## Before you start

The end-to-end flow is:

1. Install the Telegram plugin in Claude Code (once, globally).
2. Create a **new** Telegram bot via BotFather and copy its token.
3. Look up your **numeric** Telegram ID.
4. Register the bot with `cctg add`.
5. Start it with `cctg up`.
6. DM the bot from Telegram.

You only repeat Steps 2–6 per project bot; Step 1 is a one-time global install.

## Step 1 — Install the Telegram plugin

CCTG drives the official Telegram plugin, which must be installed **globally** inside Claude Code. Run this in Claude Code:

```
/plugin install telegram@claude-plugins-official
```

`cctg doctor` reminds you about this requirement, so if you are unsure whether the plugin is present, run `cctg doctor` and check the plugin hint near the end of its output.

## Step 2 — Create a NEW bot with BotFather

1. Open [@BotFather](https://t.me/BotFather) in Telegram.
2. Send the command `/newbot`.
3. Choose a **display name** (shown in chats).
4. Choose a **username** — it must end in `bot` (for example `myproject_helper_bot`).
5. BotFather replies with a **bot token** that looks like:

   ```
   123456789:ABCdefGhIJKlmNoPQRstuVWXyz1234567890
   ```

Keep this token private — anyone with it can control the bot.

> **It must be a brand-new bot.** Each project bot polls Telegram with its own token. If you reuse one token across two running processes, the two pollers conflict and messages are dropped. Create a separate bot for every CCTG bot you register.

## Step 3 — Find your numeric Telegram ID

CCTG locks your bot down so only you can reach it. To do that it needs your **numeric** Telegram user ID (digits only — not your `@username`).

1. DM [@userinfobot](https://t.me/userinfobot) in Telegram.
2. It replies with your numeric user ID, for example `123456789`.

CCTG seeds this ID into the bot's `access.json` allowlist during registration, so **no separate pairing step is needed for Telegram** — once registered, you can message the bot right away.

## Step 4 — Register the bot with `cctg add`

```bash
cctg add <name> <working_dir>
```

- `<name>` — an identifier for this bot. Use letters, digits, `_`, and `-` only. The names `telegram`, `discord`, `imessage`, and `fakechat` are **reserved** and will be refused.
- `<working_dir>` — the project directory the bot's Claude Code session runs in (its working directory / cwd).

### Interactive registration

Running `cctg add` with no token flags prompts you for three things, in order:

1. **Bot token** — pasted with masked input (your keystrokes are hidden).
2. **Your Telegram numeric ID** — must be digits only (`^[0-9]+$`), or `add` refuses it.
3. **Permission mode** — pick a number from the menu (`1` = `bypassPermissions`, `2` = `acceptEdits`, …), or press Enter (or `7`) to follow the shared policy. A typed mode name also works; an invalid entry simply re-prompts.

Nothing is written to disk until all three inputs validate, so a mistyped entry never leaves a half-created bot behind.

Example session (token masked):

```console
$ cctg add myproject ~/work/myproject
Bot token (issued by @BotFather, must be a NEW bot): ********
Your Telegram numeric ID: 123456789
Permission mode — pick a number:
  1) bypassPermissions   2) acceptEdits   3) auto
  4) default             5) dontAsk       6) plan
  7) (follow shared)
Number [1-7, Enter=follow shared]: 1
Registered: myproject → cwd=/Users/you/work/myproject, state=/Users/you/.claude/channels/myproject
  seeded 123456789 into the allowlist (no pairing needed)
```

Registration scaffolds the state directory `~/.claude/channels/<name>/` and:

- stores the token as `TELEGRAM_BOT_TOKEN` in `.env` (with permissions `chmod 600`);
- writes `access.json` with `dmPolicy: "allowlist"`, `allowFrom: ["<your id>"]`, and `groups: {}`;
- creates `launch.env` (per-bot options) and an `inbox/` directory.

### Non-interactive registration (CI / scripting)

Supplying a token flag switches `add` to non-interactive mode. In that mode, Telegram **requires** `--id <num>`; `--mode` is optional. The token is never passed as a command-line argument (that would leak it via the process list) — it comes from an environment variable or stdin instead.

| Flag | Meaning |
| --- | --- |
| `--channel telegram` | Channel type (Telegram is the default, so this is optional). |
| `--id <num>` | Your numeric Telegram ID. Required in non-interactive mode for Telegram; must match `^[0-9]+$`. |
| `--token-env <VAR>` | Read the token from environment variable `<VAR>`. |
| `--token-stdin` | Read the token from standard input. |
| `--mode <m>` | Permission mode: one of `acceptEdits`, `auto`, `bypassPermissions`, `default`, `dontAsk`, `plan`. Optional. |

Examples:

```bash
BOT_TOKEN="123:ABC..." cctg add myproject ~/work/myproject \
  --token-env BOT_TOKEN --id 123456789 --mode bypassPermissions

secrets get tg-token | cctg add myproject ~/work/myproject --token-stdin --id 123456789
```

## Step 5 — Start the bot

```bash
cctg up <name>
```

This launches a detached tmux session named `cctg-<name>`, wrapped in `caffeinate -is` so your Mac will not sleep while the bot is running. Once it is up, DM your bot in Telegram and it responds.

## Step 6 — Verify

```bash
cctg status
```

`cctg status` lists the bot as RUNNING with its uptime, cwd / state paths, permission mode, and channel topology.

Other useful checks:

- `cctg logs <name>` — show recent output from the bot's session.
- `cctg attach <name>` — attach to the live tmux session (detach again with `Ctrl-b` then `d`).

## Troubleshooting

If the bot does not respond:

- **Plugin missing?** Run `cctg doctor` and confirm the Telegram plugin is installed (Step 1).
- **Not running?** Run `cctg status` and confirm the bot shows as RUNNING; if not, `cctg up <name>`.
- **Not in the allowlist?** Make sure you are DMing from the same Telegram account whose numeric ID you registered.
- **Shows BROKEN in `status`?** The working directory is missing, or the `.env` token file is absent. Recreate the working directory or re-register the bot.
- **Permission prompts or stalling?** See [permissions.md](permissions.md).

## Operator responsibilities

Running this bot makes you a Telegram bot operator and a user of the Anthropic API. A few obligations come from those services: disclose that the bot is an AI if anyone but you can reach it, publish a privacy policy if others use it, and note that your use is subject to your own Anthropic plan terms and Usage Policy. See **[SECURITY.md → Your responsibilities as a bot operator](../SECURITY.md#your-responsibilities-as-a-bot-operator)**.

## See also

- [installation.md](installation.md)
- [commands.md](commands.md)
- [permissions.md](permissions.md)
- [discord-setup.md](discord-setup.md)

[← Back to README](../README.md)
