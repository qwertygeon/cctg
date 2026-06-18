# Security Policy

## Reporting a vulnerability

If you find a security issue in CCTG, **please do not open a public issue.**
Instead, report it privately via [GitHub Security Advisories](https://github.com/qwertygeon/cctg/security/advisories/new).

Please include: affected version (`cctg version`), reproduction steps, and the impact you observed. We aim to acknowledge reports within a reasonable time and will coordinate a fix and disclosure with you.

## Scope and threat model

CCTG launches Claude Code bots that act on a project working directory in response to Telegram messages. Keep the following in mind:

- **Tokens**: Bot tokens are stored per-bot in `~/.claude/channels/<name>/.env` with `600` permissions. Anyone with read access to that file controls the bot. Never commit `.env` or paste tokens into issues/PRs.
- **Access control**: A bot acts on behalf of whoever is in its `access.json` allowlist. Keep the allowlist limited to yourself or trusted users. Telegram bot tokens grant control to anyone who holds them.
- **Permission model**: Bots run with `defaultMode: bypassPermissions` by default, relying on **deny rules and PreToolUse hooks** (merged with your global `~/.claude/settings.json`) to block dangerous actions. Review `cctg common` / `cctg config` before attaching a bot to a sensitive repository.
- **Data flow**: Messages, code, and file contents are relayed to the Anthropic API and pass through Telegram's infrastructure. See the privacy notice in the [README](README.md).

Reports about weaknesses in these areas (e.g. token exposure, allowlist bypass, deny-rule escape) are in scope.

## Your responsibilities as a bot operator

Running a CCTG bot makes **you** the operator of a Telegram/Discord bot and a user of the Anthropic API. Some obligations come from those upstream services rather than from CCTG — surfaced here so you can comply. This is not legal advice; consult each service's current official terms before relying on it.

- **Anthropic terms govern your use.** Content you exchange with a bot is sent to the Anthropic API. Your use is governed by the terms of your own Anthropic plan — the [Commercial Terms](https://www.anthropic.com/legal/commercial-terms) (paid API) or the Consumer Terms (Claude subscriptions) — and the [Usage Policy](https://www.anthropic.com/legal/aup). CCTG invokes the official `claude` CLI; it does not extract, store, or reuse your Anthropic credentials.
- **Disclose that it's an AI.** Anthropic's Usage Policy requires consumer-facing chatbots to tell people they are interacting with AI. If anyone other than you can reach your bot, make that disclosure.
- **Provide a privacy policy.** Discord's developer terms **require** every bot/app to publish and follow a privacy policy, and prohibit selling or commercializing platform "API data". Telegram likewise expects bot operators to handle user data lawfully. If others use your bot, publish a privacy policy and handle their data accordingly.
- **Keep the allowlist tight.** The simplest way to limit all of the above is to keep `access.json` restricted to yourself or people you trust (see the threat model above).

> CCTG is an unofficial, third-party tool not affiliated with or endorsed by Anthropic; "Claude" and "Claude Code" are trademarks of Anthropic.
