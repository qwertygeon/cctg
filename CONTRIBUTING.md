# Contributing to CCTG

Thanks for your interest in improving CCTG! This is a small Bash project, so contributing is straightforward.

> 한국어 문서: [README.ko.md](README.ko.md) · 영문이 기준입니다.

## Ground rules

- **Platform**: CCTG targets **macOS** (it relies on `caffeinate` and BSD-style tools). Changes should not break macOS; Linux/WSL support is not a current goal.
- **Scope**: Keep changes focused. For larger features or behavior changes, open an issue first to discuss.
- **No churn-only PRs** unless agreed in an issue — prefer changes that carry user-visible value or fix a real problem.

## Development setup

```bash
git clone https://github.com/qwertygeon/cctg.git
cd cctg
./install.sh --dev    # symlink install — repo edits take effect immediately
```

The single entry point is `cc-tg.sh`. Shell completions live in `completions/`, and contributor-facing notes are in `docs/`.

## Before opening a PR

- Run [`shellcheck`](https://www.shellcheck.net/) on changed scripts and address warnings:
  ```bash
  shellcheck cc-tg.sh install.sh uninstall.sh
  ```
- Verify the affected commands manually (`cctg doctor`, `add`, `up`, `status`, etc.).
- If behavior changed, update `README.md` (and `README.ko.md`) and add a `CHANGELOG.md` entry under `[Unreleased]`.
- Never commit secrets (bot tokens, chat IDs) or machine-specific paths.

## Commit messages

Use a `[type] summary` prefix, e.g. `[feat]`, `[fix]`, `[docs]`, `[refactor]`, `[test]`, `[chore]`.

## Reporting bugs / requesting features

Open an issue using the templates under [`.github/ISSUE_TEMPLATE/`](.github/ISSUE_TEMPLATE). For security issues, see [SECURITY.md](SECURITY.md) instead of filing a public issue.
