#!/usr/bin/env bats
# Launch-string wiring: the `tmux new-session` command must inject the shared
# --settings, the channel plugin, and the per-bot launch.env knobs
# (--permission-mode / CLAUDE_EXTRA_ARGS). The fake tmux records the raw
# new-session argv to $FAKE_TMUX_LASTCMD (one arg per line); the launch command
# itself is the single `bash -lc <...>` argument, so the whole `&&` chain lands
# on one line we can grep. This guards against the wiring being dropped from the
# launch template (the stub otherwise only tracks session create/kill, not argv).

load test_helper

@test "up: launch injects the shared --settings file" {
  seed_bot mybot
  export FAKE_TMUX_LASTCMD="$BATS_TEST_TMPDIR/lastcmd"
  run cctg up mybot
  [ "$status" -eq 0 ]
  grep -q -- '--settings' "$FAKE_TMUX_LASTCMD"
  grep -q 'cctg-shared.settings.json' "$FAKE_TMUX_LASTCMD"
}

@test "up: launch wires the channel plugin (telegram)" {
  seed_bot mybot
  export FAKE_TMUX_LASTCMD="$BATS_TEST_TMPDIR/lastcmd"
  run cctg up mybot
  [ "$status" -eq 0 ]
  grep -q -- 'caffeinate -is claude --channels' "$FAKE_TMUX_LASTCMD"
  grep -q 'plugin:telegram@claude-plugins-official' "$FAKE_TMUX_LASTCMD"
}

@test "up: launch wires the discord plugin for a discord bot" {
  BOT_TOKEN="dtok" bash "$CCTG" add dbot "$WORK" --channel discord --token-env BOT_TOKEN >/dev/null
  export FAKE_TMUX_LASTCMD="$BATS_TEST_TMPDIR/lastcmd"
  run cctg up dbot
  [ "$status" -eq 0 ]
  grep -q 'plugin:discord@claude-plugins-official' "$FAKE_TMUX_LASTCMD"
}

@test "up: launch sources the bot .env and launch.env (token + knobs)" {
  seed_bot mybot
  export FAKE_TMUX_LASTCMD="$BATS_TEST_TMPDIR/lastcmd"
  run cctg up mybot
  [ "$status" -eq 0 ]
  # both per-bot files are sourced so the token + knobs reach claude at runtime
  grep -q 'source .*/.env' "$FAKE_TMUX_LASTCMD"
  grep -q 'launch.env' "$FAKE_TMUX_LASTCMD"
}

@test "up: launch wires --permission-mode and CLAUDE_EXTRA_ARGS knobs" {
  seed_bot mybot "$WORK" --mode plan
  cctg config mybot args "--model opus" >/dev/null
  export FAKE_TMUX_LASTCMD="$BATS_TEST_TMPDIR/lastcmd"
  run cctg up mybot
  [ "$status" -eq 0 ]
  # the launch template carries both knobs (resolved at runtime from launch.env)
  grep -q -- '--permission-mode' "$FAKE_TMUX_LASTCMD"
  grep -q 'CLAUDE_EXTRA_ARGS' "$FAKE_TMUX_LASTCMD"
}

@test "up: a per-bot width is pinned with new-session -x" {
  seed_bot mybot
  cctg config mybot width 160 >/dev/null
  export FAKE_TMUX_LASTCMD="$BATS_TEST_TMPDIR/lastcmd"
  run cctg up mybot
  [ "$status" -eq 0 ]
  grep -qxF -- '-x' "$FAKE_TMUX_LASTCMD"
  grep -qxF -- '160' "$FAKE_TMUX_LASTCMD"
}
