# cctg tests

[bats](https://github.com/bats-core/bats-core) suite for `cc-tg.sh`.

```bash
brew install bats-core   # macOS  (Linux: apt-get install bats)
bats tests/              # run all
bats tests/add.bats      # run one file
```

## How it's isolated

`tests/test_helper.bash` `setup()` points every state path at a per-test
throwaway dir under `$BATS_TEST_TMPDIR` (`CC_CHANNELS_DIR`, `XDG_CONFIG_HOME`,
`HOME`) and prepends `tests/stubs/` to `PATH` so a fake `tmux` replaces the real
one. Tests never touch your real `~/.claude/channels` or tmux server.

- `tests/stubs/tmux` — deterministic fake; "running" sessions come from
  `$FAKE_TMUX_SESSIONS` (set via the `mark_running` helper).
- `seed_bot` registers a bot non-interactively; `registry_raw` injects raw
  registry lines to craft edge cases (`add` would refuse).

## Coverage

`add` `rm` `rename` `config` `common` `status --json` `lang` `logs` `up` `down`
`restart` `doctor` `version`, the opt-in snapshot watcher lifecycle, the
dispatcher, and the registry / reserved-name / state-dir safety guards.

The fake `tmux` is stateful (`new-session`/`kill-session`/`has-session` track a
session list), so `up`/`down`/`restart` exercise the real lifecycle paths.
