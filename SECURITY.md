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
