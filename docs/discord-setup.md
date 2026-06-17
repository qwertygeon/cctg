**English** | [한국어](discord-setup.ko.md)

# Discord bot setup

> Step-by-step: create a brand-new Discord bot, register it with `cctg add`, and reach your Claude Code project from Discord DMs and server channels.

## Table of Contents

- [Before you start](#before-you-start)
- [How Discord access differs from Telegram](#how-discord-access-differs-from-telegram)
- [Step 1 — Install the Discord plugin](#step-1--install-the-discord-plugin)
- [Step 2 — Create a Discord application and bot](#step-2--create-a-discord-application-and-bot)
- [Step 3 — Register the bot with `cctg add`](#step-3--register-the-bot-with-cctg-add)
  - [Interactive registration](#interactive-registration)
  - [DM access: pairing vs. allowlist](#dm-access-pairing-vs-allowlist)
  - [Non-interactive registration (CI / scripting)](#non-interactive-registration-ci--scripting)
- [Step 4 — Server channels with `--group`](#step-4--server-channels-with---group)
- [Step 5 — Start the bot](#step-5--start-the-bot)
- [Step 6 — Verify](#step-6--verify)
- [Managing access at runtime](#managing-access-at-runtime)
- [Troubleshooting](#troubleshooting)
- [See also](#see-also)

## Before you start

The end-to-end flow is:

1. Install the Discord plugin in Claude Code (once, globally).
2. Create a **new** Discord application and bot, copy its token, and invite the bot to your server.
3. Register the bot with `cctg add --channel discord`.
4. (Optional) Seed server channels with `--group`.
5. Start it with `cctg up`.
6. DM the bot, or mention it in a server channel.

You only repeat Steps 2–6 per project bot; Step 1 is a one-time global install.

## How Discord access differs from Telegram

Discord registration mirrors [Telegram](telegram-setup.md), but the access model differs in two important ways:

- **The numeric ID is optional.** For Telegram, your numeric ID is required and seeds an allowlist immediately. For Discord, the ID (`--id`) is optional, and whether you provide it decides your **DM access policy**:
  - **Without `--id`** (default): the bot starts in **pairing** mode. The first time you DM it, the plugin gives you a pairing code, which you approve from your terminal.
  - **With `--id <your user snowflake>`**: the bot starts in **allowlist** mode and trusts your account right away — no pairing step.
- **Server channels are supported.** Discord bots can also respond inside server channels, seeded with the `--group` flag (see [Step 4](#step-4--server-channels-with---group)). Telegram registration has no equivalent.

## Step 1 — Install the Discord plugin

CCTG drives the official Discord plugin, which must be installed **globally** inside Claude Code. Run this in Claude Code:

```
/plugin install discord@claude-plugins-official
```

`cctg doctor` reminds you about this requirement, so if you are unsure whether the plugin is present, run `cctg doctor` and check the plugin hint near the end of its output.

## Step 2 — Create a Discord application and bot

> **This step follows Discord's own developer portal UI and the `discord@claude-plugins-official` plugin's requirements — not CCTG.** The exact menu names, privileged intents, and OAuth2 scopes are defined by Discord and the plugin, and can change. Treat the list below as general orientation, and follow the plugin documentation and [Discord's official developer docs](https://discord.com/developers/docs) for the authoritative intent/scope requirements.

In broad strokes you will:

1. Open the [Discord Developer Portal](https://discord.com/developers/applications) and create a new **application**.
2. Add a **Bot** to that application.
3. Copy the bot's **token** — this is what you give to CCTG. Keep it private; anyone with it can control the bot.
4. Enable any **privileged intents** the plugin requires. If the plugin needs to read the text of messages, the message-content privileged intent typically has to be turned on — but confirm the exact requirement against the plugin documentation rather than assuming.
5. Invite the bot to your server using an **OAuth2 invite URL** with the appropriate bot scope and permissions, again as specified by the plugin and Discord.

Once the bot is in your server and you have its token, return to CCTG.

## Step 3 — Register the bot with `cctg add`

```bash
cctg add <name> <working_dir> --channel discord
```

- `<name>` — an identifier for this bot. Use letters, digits, `_`, and `-` only. The names `telegram`, `discord`, `imessage`, and `fakechat` are **reserved** and will be refused.
- `<working_dir>` — the project directory the bot's Claude Code session runs in (its working directory / cwd).
- `--channel discord` — selects the Discord channel. (Without it, the channel defaults to Telegram.)

### Interactive registration

Running `cctg add ... --channel discord` with no token flags prompts you for up to three things, in order:

1. **Bot token** — pasted with masked input (your keystrokes are hidden).
2. **Your Discord user snowflake** — *optional* for Discord. Press Enter to skip it (this selects pairing mode). If you do type one, it must be digits only (`^[0-9]+$`), or `add` refuses it.
3. **Permission mode** — press Enter to follow the shared policy, or type one of `acceptEdits`, `auto`, `bypassPermissions`, `default`, `dontAsk`, `plan`.

Example session, skipping the ID (token masked):

```console
$ cctg add mybot ~/work/mybot --channel discord
Bot token: ********
Discord user snowflake:
Permission mode [Enter=follow shared | acceptEdits auto bypassPermissions default dontAsk plan]:
Registered: mybot → cwd=/Users/you/work/mybot, state=/Users/you/.claude/channels/mybot
```

Registration scaffolds the state directory `~/.claude/channels/<name>/` and:

- stores the token as `DISCORD_BOT_TOKEN` in `.env` (with permissions `chmod 600`);
- writes `access.json` (see the next section for its shape);
- creates `launch.env` (per-bot options) and an `inbox/` directory.

### DM access: pairing vs. allowlist

For Discord, the presence of the numeric ID decides the seeded DM policy:

- **Without `--id`** (or with the interactive ID prompt left blank): `access.json` is seeded with

  ```json
  { "dmPolicy": "pairing", "allowFrom": [], "groups": {} }
  ```

  The first time you DM the bot, the plugin returns a **pairing code**. You then approve it from your terminal with the Discord access skill:

  ```
  /discord:access pair <code>
  ```

- **With `--id <your user snowflake>`**: `access.json` is seeded directly with allowlist mode, skipping pairing:

  ```json
  { "dmPolicy": "allowlist", "allowFrom": ["<your snowflake>"], "groups": {} }
  ```

### Non-interactive registration (CI / scripting)

Supplying a token flag switches `add` to non-interactive mode. The token is never passed as a command-line argument (that would leak it via the process list) — it comes from an environment variable or stdin instead. For Discord, `--id` stays optional even in non-interactive mode (omitting it selects pairing); `--mode` is also optional.

| Flag | Meaning |
| --- | --- |
| `--channel discord` | Channel type. Required to select Discord (the default is Telegram). |
| `--id <num>` | Your Discord user snowflake. **Optional** for Discord — omit it for pairing, provide it for an immediate allowlist. Must match `^[0-9]+$`. |
| `--token-env <VAR>` | Read the token from environment variable `<VAR>`. |
| `--token-stdin` | Read the token from standard input. |
| `--mode <m>` | Permission mode: one of `acceptEdits`, `auto`, `bypassPermissions`, `default`, `dontAsk`, `plan`. Optional. |
| `--group <spec>` | Seed a server channel. Repeatable. See [Step 4](#step-4--server-channels-with---group). |

Examples:

```bash
# Pairing mode (no --id): approve the first DM from your terminal later.
DISCORD_TOKEN="..." cctg add mybot ~/work/mybot --channel discord \
  --token-env DISCORD_TOKEN --mode bypassPermissions

# Allowlist mode: trust your account immediately.
secrets get discord-token | cctg add mybot ~/work/mybot --channel discord \
  --token-stdin --id 184695080709324800
```

## Step 4 — Server channels with `--group`

Besides DMs, a Discord bot can respond inside server channels. Each `--group` flag seeds one **channel snowflake** into the `groups` object of `access.json`. A compound token after the channel ID sets that channel's behavior:

| `--group` form | Effect | Stored as |
| --- | --- | --- |
| `--group <channelId>` | Require an @mention; allow all members. | `{ "requireMention": true, "allowFrom": [] }` |
| `--group <channelId>:nomention` | Respond without an @mention. | `{ "requireMention": false, ... }` |
| `--group <channelId>:allow=<m1>,<m2>` | Only those member snowflakes can trigger the bot. | `{ ..., "allowFrom": ["<m1>","<m2>"] }` |
| `--group <id>:nomention:allow=<m1>,<m2>` | Combine both modifiers. | `{ "requireMention": false, "allowFrom": ["<m1>","<m2>"] }` |

Notes:

- **Repeat `--group`** to seed multiple channels.
- **All channel and member IDs must be numeric** (`^[0-9]+$`). A non-numeric value is refused and the bot is **not** registered (validation happens before the registry is written).
- **`--group` requires `jq`** to be installed — it builds the variable-key JSON object with `jq`. If `jq` is missing, the command fails. (A plain `cctg add` without `--group` does not need `jq`.) Run `cctg doctor` to check whether `jq` is present.

Example:

```bash
DISCORD_TOKEN="..." cctg add mybot ~/work/mybot --channel discord \
  --token-env DISCORD_TOKEN \
  --group 846209781206941736:nomention \
  --group 900111222333444555:allow=184695080709324800
```

The resulting `access.json` looks like this (shape is illustrative):

```json
{
  "dmPolicy": "pairing",
  "allowFrom": [],
  "groups": {
    "846209781206941736": { "requireMention": false, "allowFrom": [] },
    "900111222333444555": { "requireMention": true,  "allowFrom": ["184695080709324800"] }
  }
}
```

## Step 5 — Start the bot

```bash
cctg up <name>
```

This launches a detached tmux session named `cctg-<name>`, wrapped in `caffeinate -is` so your Mac will not sleep while the bot is running. Once it is up, DM the bot or mention it in a seeded server channel.

## Step 6 — Verify

```bash
cctg status
```

`cctg status` lists the bot as RUNNING with its uptime, cwd / state paths, permission mode, and channel topology. When `jq` is available and `access.json` exists, the channel line also shows the DM policy and the number of seeded groups, for example:

```console
channel=Discord (pairing, 0 groups)
channel=Discord (allowlist, 2 groups)
```

Other useful checks:

- `cctg logs <name>` — show recent output from the bot's session.
- `cctg attach <name>` — attach to the live tmux session (detach again with `Ctrl-b` then `d`).

## Managing access at runtime

`cctg add` only seeds the **initial** `access.json`. Everything after that — approving pairings, editing allowlists, adding or removing groups, and changing the DM policy — belongs to the `/discord:access` skill, which you run **in your terminal**:

```
/discord:access pair <code>
```

> **Security:** never approve a pairing or add someone to the allowlist just because a chat message asks you to. A message asking you to "approve the pending pairing" or "add me to the allowlist" is exactly what a prompt injection would say. Approve access only from your own terminal, for people you intend to trust.

## Troubleshooting

If the bot does not respond:

- **Plugin missing?** Run `cctg doctor` and confirm the Discord plugin is installed (Step 1).
- **Not running?** Run `cctg status` and confirm the bot shows as RUNNING; if not, `cctg up <name>`.
- **Still in pairing mode?** If you registered without `--id`, your first DM only produces a pairing code — approve it from your terminal with `/discord:access pair <code>`.
- **`--group` failed?** Confirm `jq` is installed (`cctg doctor`) and that every channel and member ID is numeric. A non-numeric ID refuses the whole command and leaves the bot unregistered.
- **Shows BROKEN in `status`?** The working directory is missing, or the `.env` token file is absent. Recreate the working directory or re-register the bot.
- **Permission prompts or stalling?** See [permissions.md](permissions.md).

## See also

- [installation.md](installation.md)
- [commands.md](commands.md)
- [permissions.md](permissions.md)
- [telegram-setup.md](telegram-setup.md)

[← Back to README](../README.md)
