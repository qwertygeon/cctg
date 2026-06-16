#!/usr/bin/env bats
# `cctg up` / `down` / `restart` — session lifecycle against the stateful fake tmux.

load test_helper

@test "up: starts a session and reports UP" {
  seed_bot mybot
  run cctg up mybot
  [ "$status" -eq 0 ]
  [[ "$output" == *"UP   mybot"* ]]
  grep -qxF "cctg-mybot" "$FAKE_TMUX_STATE"
}

@test "up: a second up is a no-op (already running)" {
  seed_bot mybot
  cctg up mybot >/dev/null
  run cctg up mybot
  [ "$status" -eq 0 ]
  [[ "$output" == *"Already running: mybot"* ]]
}

@test "up: fails when the working dir is missing" {
  registry_raw "mybot | $BATS_TEST_TMPDIR/gone | $CC_CHANNELS_DIR/mybot"
  run cctg up mybot
  [ "$status" -ne 0 ]
  [[ "$output" == *"working directory not found"* ]]
}

@test "up: fails when the token file is missing" {
  mkdir -p "$CC_CHANNELS_DIR/mybot"
  registry_raw "mybot | $WORK | $CC_CHANNELS_DIR/mybot"   # dir exists, no .env
  run cctg up mybot
  [ "$status" -ne 0 ]
  [[ "$output" == *"token file not found"* ]]
}

@test "up: fails for an unregistered bot" {
  run cctg up ghost
  [ "$status" -ne 0 ]
  [[ "$output" == *"not a registered project: ghost"* ]]
}

@test "down: stops a running session, snapshots, and clears the session" {
  seed_bot mybot
  cctg up mybot >/dev/null
  run cctg down mybot
  [ "$status" -eq 0 ]
  [[ "$output" == *"DOWN mybot"* ]]
  ! grep -qxF "cctg-mybot" "$FAKE_TMUX_STATE"
  [ -f "$CC_CHANNELS_DIR/mybot/last-session.log" ]
}

@test "down: reports stopped when not running" {
  seed_bot mybot
  run cctg down mybot
  [ "$status" -eq 0 ]
  [[ "$output" == *"Stopped: mybot"* ]]
}

@test "up all / down all: act on every registered bot" {
  seed_bot a; seed_bot b
  run cctg up all
  [ "$status" -eq 0 ]
  grep -qxF "cctg-a" "$FAKE_TMUX_STATE"
  grep -qxF "cctg-b" "$FAKE_TMUX_STATE"
  run cctg down all
  [ "$status" -eq 0 ]
  [ ! -s "$FAKE_TMUX_STATE" ]
}

@test "restart: stops then starts again, leaving the session running" {
  seed_bot mybot
  cctg up mybot >/dev/null
  run cctg restart mybot
  [ "$status" -eq 0 ]
  [[ "$output" == *"DOWN mybot"* ]]
  [[ "$output" == *"UP   mybot"* ]]
  grep -qxF "cctg-mybot" "$FAKE_TMUX_STATE"
}
