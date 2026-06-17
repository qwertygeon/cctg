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

# ---------------------------------------------------------------------------
# SC-001~006: config cwd / token (v0.5.0/001-cli-convenience-patches)
# ---------------------------------------------------------------------------

@test "config cwd: updates registry column 2 (SC-001)" {
  seed_bot mybot
  local newdir="$BATS_TEST_TMPDIR/newpath"
  mkdir -p "$newdir"
  run cctg config mybot cwd "$newdir"
  [ "$status" -eq 0 ]
  # Registry 2nd column (cwd) must now be the new path.
  grep -qE "^mybot[[:space:]]*\|[[:space:]]*$newdir" "$REGISTRY"
  # Success message must be present.
  [[ "$output" == *"mybot"* ]]
}

@test "config cwd: rejects non-existent dir (SC-002)" {
  seed_bot mybot
  # Record original registry row before the attempted change.
  local orig
  orig="$(grep '^mybot' "$REGISTRY")"
  run cctg config mybot cwd /nope/does/not/exist
  [ "$status" -ne 0 ]
  # Error output must reference the rejected path (ERR_NO_SUCH_DIR: "no such directory: %s").
  [[ "$output" == *"nope"* ]] || [[ "$output" == *"no such"* ]] || [[ "$output" == *"not found"* ]]
  # Registry row must remain unchanged.
  [ "$(grep '^mybot' "$REGISTRY")" = "$orig" ]
}

@test "config cwd: hints restart when running (SC-003)" {
  seed_bot mybot
  local newdir="$BATS_TEST_TMPDIR/newpath3"
  mkdir -p "$newdir"
  mark_running mybot
  run cctg config mybot cwd "$newdir"
  [ "$status" -eq 0 ]
  # Registry updated.
  grep -qE "^mybot[[:space:]]*\|[[:space:]]*$newdir" "$REGISTRY"
  # Restart hint must appear.
  [[ "$output" == *"to apply"* ]]
}

@test "config token: rewrites .env with telegram key, mode 600 (SC-004)" {
  seed_bot mybot
  local sd="$CC_CHANNELS_DIR/mybot"
  # Pipe stdin via a temp file so cctg's `read -r` on --token-stdin gets it.
  local tmpf="$BATS_TEST_TMPDIR/tok4"
  printf 'newtok' > "$tmpf"
  run cctg config mybot token --token-stdin < "$tmpf"
  [ "$status" -eq 0 ]
  grep -q 'TELEGRAM_BOT_TOKEN=newtok' "$sd/.env"
  [ "$(file_mode "$sd/.env")" = "600" ]
}

@test "config token: rejects empty token (SC-005)" {
  seed_bot mybot
  local sd="$CC_CHANNELS_DIR/mybot"
  # Preserve the original .env content.
  local orig
  orig="$(cat "$sd/.env")"
  # Feed an empty file as stdin — cctg's `read -r` will read empty string.
  local tmpf="$BATS_TEST_TMPDIR/tok5"
  : > "$tmpf"
  run cctg config mybot token --token-stdin < "$tmpf"
  [ "$status" -ne 0 ]
  [[ "$output" == *"empty"* ]]
  # .env must remain unchanged.
  [ "$(cat "$sd/.env")" = "$orig" ]
}

@test "config token: uses DISCORD_BOT_TOKEN for discord (SC-006)" {
  local sd="$CC_CHANNELS_DIR/dbot"
  BOT_TOKEN="dtok" bash "$CCTG" add dbot "$WORK" \
    --channel discord --token-env BOT_TOKEN >/dev/null
  local tmpf="$BATS_TEST_TMPDIR/tok6"
  printf 'newtok' > "$tmpf"
  run cctg config dbot token --token-stdin < "$tmpf"
  [ "$status" -eq 0 ]
  grep -q 'DISCORD_BOT_TOKEN=newtok' "$sd/.env"
  [ "$(file_mode "$sd/.env")" = "600" ]
}
