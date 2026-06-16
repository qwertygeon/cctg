#!/usr/bin/env bats
# `cctg rename` — name change, state-dir move semantics, and guards.

load test_helper

@test "rename: moves the default state dir and updates the registry" {
  seed_bot old
  run cctg rename old new
  [ "$status" -eq 0 ]
  [[ "$output" == *"Renamed: old → new"* ]]
  [[ "$output" == *"moved state directory"* ]]
  grep -qE '^new \| ' "$REGISTRY"
  ! grep -qE '^old \| ' "$REGISTRY"
  [ -d "$CC_CHANNELS_DIR/new" ]
  [ ! -d "$CC_CHANNELS_DIR/old" ]
}

@test "rename --keep-dir: renames but leaves the directory path in place" {
  seed_bot old
  run cctg rename old new --keep-dir
  [ "$status" -eq 0 ]
  [[ "$output" == *"kept state directory"* ]]
  grep -qE '^new \| ' "$REGISTRY"
  [ -d "$CC_CHANNELS_DIR/old" ]            # dir unchanged
  grep -qE "\| $CC_CHANNELS_DIR/old \| telegram$" "$REGISTRY"   # state dir kept (field 3); channel column preserved
}

@test "rename: preserves the working_dir column" {
  seed_bot old "$WORK"
  run cctg rename old new
  [ "$status" -eq 0 ]
  grep -qE "^new \| $WORK \|" "$REGISTRY"
}

@test "rename: a custom (non-default) state dir is kept even without --keep-dir" {
  local custom="$BATS_TEST_TMPDIR/custom-sd"
  mkdir -p "$custom"
  registry_raw "old | $WORK | $custom"
  run cctg rename old new
  [ "$status" -eq 0 ]
  [[ "$output" == *"kept state directory"* ]]
  [ -d "$custom" ]
  grep -qE "\| $custom \| telegram$" "$REGISTRY"   # legacy 3-col row upgraded with default channel
}

@test "rename: refuses a reserved new name" {
  seed_bot old
  run cctg rename old telegram
  [ "$status" -ne 0 ]
  [[ "$output" == *"reserved global channel name"* ]]
}

@test "rename: refuses when the new name already exists" {
  seed_bot old
  seed_bot taken
  run cctg rename old taken
  [ "$status" -ne 0 ]
  [[ "$output" == *"already registered: taken"* ]]
}

@test "rename: refuses identical old and new names" {
  seed_bot old
  run cctg rename old old
  [ "$status" -ne 0 ]
  [[ "$output" == *"identical"* ]]
}

@test "rename: fails for an unregistered old name" {
  run cctg rename ghost new
  [ "$status" -ne 0 ]
  [[ "$output" == *"not a registered project: ghost"* ]]
}

@test "rename: refuses while the bot is running" {
  seed_bot old
  mark_running old
  run cctg rename old new
  [ "$status" -ne 0 ]
  [[ "$output" == *"it's running"* ]]
}
