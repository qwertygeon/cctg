#!/usr/bin/env bats
# `cctg rm` — unregistration, --purge, and the safety guards around deletion.

load test_helper

@test "rm: unregisters but keeps the state dir by default" {
  seed_bot mybot
  run cctg rm mybot
  [ "$status" -eq 0 ]
  [[ "$output" == *"Unregistered: mybot"* ]]
  [[ "$output" == *"kept state directory"* ]]
  ! grep -qE '^mybot \| ' "$REGISTRY"
  [ -d "$CC_CHANNELS_DIR/mybot" ]
}

@test "rm --purge: deletes the state dir" {
  seed_bot mybot
  run cctg rm mybot --purge
  [ "$status" -eq 0 ]
  [[ "$output" == *"deleted state directory"* ]]
  [ ! -d "$CC_CHANNELS_DIR/mybot" ]
}

@test "rm: fails for an unregistered bot" {
  run cctg rm ghost
  [ "$status" -ne 0 ]
  [[ "$output" == *"not a registered project: ghost"* ]]
}

@test "rm: refuses while the bot is running" {
  seed_bot mybot
  mark_running mybot
  run cctg rm mybot
  [ "$status" -ne 0 ]
  [[ "$output" == *"it's running"* ]]
  grep -qE '^mybot \| ' "$REGISTRY"   # still registered
}

@test "rm --purge: refuses to delete a global channel directory" {
  registry_raw "myimpostor | $WORK | $CC_CHANNELS_DIR/telegram"
  mkdir -p "$CC_CHANNELS_DIR/telegram"
  printf 'global\n' > "$CC_CHANNELS_DIR/telegram/.env"
  run cctg rm myimpostor --purge
  [ "$status" -eq 0 ]
  [[ "$output" == *"will not delete the global bot directory"* ]]
  [ -f "$CC_CHANNELS_DIR/telegram/.env" ]   # untouched
}

@test "rm --purge: does not auto-delete a state dir outside CHANNELS_DIR" {
  local outside="$BATS_TEST_TMPDIR/outside"
  mkdir -p "$outside"
  registry_raw "ext | $WORK | $outside"
  run cctg rm ext --purge
  [ "$status" -eq 0 ]
  [[ "$output" == *"outside CHANNELS_DIR"* ]]
  [ -d "$outside" ]   # not deleted
}
