#!/usr/bin/env bats
# `cctg config <name>` — per-bot launch.env management.

load test_helper

@test "config mode: sets CCTG_PERMISSION_MODE" {
  seed_bot mybot
  run cctg config mybot mode acceptEdits
  [ "$status" -eq 0 ]
  [[ "$output" == *"permission mode: acceptEdits"* ]]
  grep -q 'CCTG_PERMISSION_MODE="acceptEdits"' "$CC_CHANNELS_DIR/mybot/launch.env"
}

@test "config mode clear: empties CCTG_PERMISSION_MODE" {
  seed_bot mybot "$WORK" --mode plan
  run cctg config mybot mode clear
  [ "$status" -eq 0 ]
  [[ "$output" == *"(follow shared)"* ]]
  grep -q 'CCTG_PERMISSION_MODE=""' "$CC_CHANNELS_DIR/mybot/launch.env"
}

@test "config mode: refuses an invalid mode" {
  seed_bot mybot
  run cctg config mybot mode bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid mode"* ]]
}

@test "config args: sets CLAUDE_EXTRA_ARGS" {
  seed_bot mybot
  run cctg config mybot args "--model opus"
  [ "$status" -eq 0 ]
  grep -q 'CLAUDE_EXTRA_ARGS="--model opus"' "$CC_CHANNELS_DIR/mybot/launch.env"
}

@test "config show: prints the header and launch.env body" {
  seed_bot mybot
  run cctg config mybot show
  [ "$status" -eq 0 ]
  [[ "$output" == *"mybot bot options"* ]]
  [[ "$output" == *"CCTG_PERMISSION_MODE"* ]]
}

@test "config: fails for an unregistered bot" {
  run cctg config ghost show
  [ "$status" -ne 0 ]
  [[ "$output" == *"not a registered project: ghost"* ]]
}

@test "config mode: hints to restart when the bot is running" {
  seed_bot mybot
  mark_running mybot
  run cctg config mybot mode plan
  [ "$status" -eq 0 ]
  [[ "$output" == *"to apply"* ]]
}
