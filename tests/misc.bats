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
