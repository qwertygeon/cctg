#!/usr/bin/env bats
# Dispatcher, version, help, doctor, and down-snapshot logging.

load test_helper

@test "version: prints the VERSION file contents" {
  run cctg version
  [ "$status" -eq 0 ]
  [[ "$output" == *"$(head -n1 "$REPO_ROOT/VERSION")"* ]]
}

@test "help: exits 0 and prints usage" {
  run cctg help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "no command: prints usage and exits 0" {
  run cctg
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "unknown command: errors and exits non-zero" {
  run cctg frobnicate
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown command: frobnicate"* ]]
}

@test "doctor: runs and reports the version and registry count" {
  seed_bot mybot
  run cctg doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"cctg doctor"* ]]
  [[ "$output" == *"registered project bots: 1"* ]]
}

@test "doctor: reports install-integrity section (.env perms + manifest)" {
  seed_bot mybot
  run cctg doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"install integrity"* ]]
  [[ "$output" == *"all 600"* ]]            # seeded .env is 600
  [[ "$output" == *"manifest"* ]]            # manifest status reported (missing in test env)
}

@test "doctor: warns when a bot .env is not 600" {
  seed_bot mybot
  chmod 644 "$CC_CHANNELS_DIR/mybot/.env"
  run cctg doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"mybot"* ]]
  [[ "$output" == *"expected 600"* ]]
}

@test "doctor: manifest valid → OK + bindir writable" {
  seed_bot mybot
  local cf="$XDG_CONFIG_HOME/cctg"; mkdir -p "$cf"
  local repo="$BATS_TEST_TMPDIR/repo" lib="$BATS_TEST_TMPDIR/lib" bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$repo" "$lib" "$bin"
  printf 'mode=copy\nrepo=%s\nbindir=%s\nlibexecdir=%s\n' "$repo" "$bin" "$lib" > "$cf/install.conf"
  run cctg doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"install manifest"* ]]
  [[ "$output" == *"install dir writable"* ]]
  [[ "$output" != *"manifest path missing"* ]]
}

@test "doctor: manifest warns on a missing repo path" {
  seed_bot mybot
  local cf="$XDG_CONFIG_HOME/cctg"; mkdir -p "$cf"
  printf 'mode=link\nrepo=%s\nbindir=%s\n' "$BATS_TEST_TMPDIR/nope-repo" "$BATS_TEST_TMPDIR" > "$cf/install.conf"
  run cctg doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"manifest path missing"* ]]
  [[ "$output" == *"repo"* ]]
}

@test "doctor: warns when bindir is not writable" {
  seed_bot mybot
  local cf="$XDG_CONFIG_HOME/cctg"; mkdir -p "$cf"
  local bin="$BATS_TEST_TMPDIR/ro-bin"; mkdir -p "$bin"; chmod 555 "$bin"
  printf 'mode=copy\nbindir=%s\n' "$bin" > "$cf/install.conf"
  run cctg doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"install dir not writable"* ]]
  chmod 755 "$bin"
}

@test "down: snapshots the pane to last-session.log when stopping a running bot" {
  seed_bot mybot
  mark_running mybot
  run cctg down mybot
  [ "$status" -eq 0 ]
  [[ "$output" == *"DOWN mybot"* ]]
  [ -f "$CC_CHANNELS_DIR/mybot/last-session.log" ]
  [ "$(file_mode "$CC_CHANNELS_DIR/mybot/last-session.log")" = "600" ]
}

@test "logs: streams the live pane for a running bot (capture-pane target-pane)" {
  # Regression: cmd_logs must pass a target-PANE ('=NAME:'), not a bare '=NAME'
  # target-session, to capture-pane — else real tmux errors "can't find pane".
  seed_bot mybot
  mark_running mybot
  run cctg logs mybot
  [ "$status" -eq 0 ]
  [[ "$output" == *"fake pane line 1"* ]]
  [[ "$output" != *"can't find pane"* ]]
}

@test "logs: a running prefix-named bot reads its own pane, not its sibling's" {
  # 'cc-tg' is a prefix of 'cc-tg-discord'; exact-match must still hold for panes.
  seed_bot cc-tg
  seed_bot cc-tg-discord
  mark_running cc-tg-discord
  run cctg logs cc-tg-discord
  [ "$status" -eq 0 ]
  [[ "$output" == *"fake pane line 1"* ]]
}

@test "logs: falls back to the saved snapshot when the bot is stopped" {
  seed_bot mybot
  printf 'saved log content\n' > "$CC_CHANNELS_DIR/mybot/last-session.log"
  run cctg logs mybot
  [ "$status" -eq 0 ]
  [[ "$output" == *"saved log content"* ]]
  [[ "$output" == *"last saved session log"* ]]
}

@test "logs: errors when stopped with no snapshot" {
  seed_bot mybot
  run cctg logs mybot
  [ "$status" -ne 0 ]
  [[ "$output" == *"no logs"* ]]
}

@test "status: warns when tmux is absent instead of silently showing all stopped (defensive)" {
  # Without tmux, is_running() silently fails and every bot reads as stopped/broken.
  # The read path must surface a warning rather than mislead. Run with a PATH that
  # has no tmux (skip if this host happens to ship one under /usr/bin:/bin).
  if PATH="/usr/bin:/bin" command -v tmux >/dev/null 2>&1; then
    skip "tmux present in /usr/bin:/bin on this host"
  fi
  seed_bot mybot
  run env PATH="/usr/bin:/bin" bash "$CCTG" status
  [[ "$output" == *"tmux not found"* ]]
}
