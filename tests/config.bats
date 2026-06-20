#!/usr/bin/env bats
# `cctg config <name>` — per-bot launch.env management.

load test_helper

@test "config mode: sets CCTG_PERMISSION_MODE" {
  seed_bot mybot
  run cctg config mybot mode acceptEdits
  [ "$status" -eq 0 ]
  [[ "$output" == *"permission mode: acceptEdits"* ]]
  grep -q "CCTG_PERMISSION_MODE='acceptEdits'" "$CC_CHANNELS_DIR/mybot/launch.env"
}

@test "config mode clear: empties CCTG_PERMISSION_MODE" {
  seed_bot mybot "$WORK" --mode plan
  run cctg config mybot mode clear
  [ "$status" -eq 0 ]
  [[ "$output" == *"(follow shared)"* ]]
  grep -q "CCTG_PERMISSION_MODE=''" "$CC_CHANNELS_DIR/mybot/launch.env"
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
  grep -q "CLAUDE_EXTRA_ARGS='--model opus'" "$CC_CHANNELS_DIR/mybot/launch.env"
}

@test "config show: prints the header and launch.env body" {
  seed_bot mybot
  run cctg config mybot show
  [ "$status" -eq 0 ]
  [[ "$output" == *"mybot bot options"* ]]
  [[ "$output" == *"CCTG_PERMISSION_MODE"* ]]
}

# ---------------------------------------------------------------------------
# session width (v0.6.0/001-session-width-config)
# ---------------------------------------------------------------------------

@test "config width: sets CCTG_SESS_WIDTH" {
  seed_bot mybot
  run cctg config mybot width 160
  [ "$status" -eq 0 ]
  [[ "$output" == *"session width: 160"* ]]
  grep -q "CCTG_SESS_WIDTH='160'" "$CC_CHANNELS_DIR/mybot/launch.env"
}

@test "config width clear: empties CCTG_SESS_WIDTH (follow global)" {
  seed_bot mybot
  cctg config mybot width 160 >/dev/null
  run cctg config mybot width clear
  [ "$status" -eq 0 ]
  [[ "$output" == *"(follow global)"* ]]
  grep -q "CCTG_SESS_WIDTH=''" "$CC_CHANNELS_DIR/mybot/launch.env"
}

@test "config width: refuses a non-numeric value" {
  seed_bot mybot
  run cctg config mybot width wide
  [ "$status" -ne 0 ]
  [[ "$output" == *"width must be an integer"* ]]
}

@test "config width: refuses a below-minimum value" {
  seed_bot mybot
  run cctg config mybot width 10
  [ "$status" -ne 0 ]
  [[ "$output" == *"width must be an integer"* ]]
}

@test "config show: reports the session width" {
  seed_bot mybot
  cctg config mybot width 144 >/dev/null
  run cctg config mybot show
  [ "$status" -eq 0 ]
  [[ "$output" == *"session width: 144"* ]]
}

@test "config width: hints to restart when the bot is running" {
  seed_bot mybot
  mark_running mybot
  run cctg config mybot width 160
  [ "$status" -eq 0 ]
  [[ "$output" == *"to apply"* ]]
}

@test "up: a per-bot CCTG_SESS_WIDTH overrides the default" {
  seed_bot mybot
  cctg config mybot width 160 >/dev/null
  export FAKE_TMUX_LASTCMD="$BATS_TEST_TMPDIR/tmux-lastcmd"
  run cctg up mybot
  [ "$status" -eq 0 ]
  grep -qxF -- '160' "$FAKE_TMUX_LASTCMD"   # per-bot width wins
  ! grep -qxF -- '100' "$FAKE_TMUX_LASTCMD"  # default not used
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
  grep -q "TELEGRAM_BOT_TOKEN='newtok'" "$sd/.env"
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
  grep -q "DISCORD_BOT_TOKEN='newtok'" "$sd/.env"
  [ "$(file_mode "$sd/.env")" = "600" ]
}

# ---------------------------------------------------------------------------
# .env / launch.env are `source`d at bot launch — values must be shell-safe so a
# token/arg with metacharacters can neither break parsing nor execute commands.
# ---------------------------------------------------------------------------

@test "config args: metacharacters are stored single-quoted; sourcing does not inject" {
  seed_bot mybot
  local le="$CC_CHANNELS_DIR/mybot/launch.env"
  local canary="$BATS_TEST_TMPDIR/pwned-args"
  run cctg config mybot args "; touch $canary #"
  [ "$status" -eq 0 ]
  # Sourcing launch.env (as the launcher does) must NOT run the injected command…
  ( set -a; . "$le" )
  [ ! -e "$canary" ]
  # …and the value must round-trip literally.
  ( set -a; . "$le"; [ "$CLAUDE_EXTRA_ARGS" = "; touch $canary #" ] )
}

@test "config args: a value with embedded quotes round-trips and does not break source" {
  seed_bot mybot
  local le="$CC_CHANNELS_DIR/mybot/launch.env"
  run cctg config mybot args '--append-system-prompt "be brief"'
  [ "$status" -eq 0 ]
  ( set -a; . "$le"; [ "$CLAUDE_EXTRA_ARGS" = '--append-system-prompt "be brief"' ] )
}

@test "config token: metacharacters in token are stored safely; sourcing does not inject" {
  seed_bot mybot
  local env="$CC_CHANNELS_DIR/mybot/.env"
  local canary="$BATS_TEST_TMPDIR/pwned-tok"
  printf '%s\n' "; touch $canary #" > "$BATS_TEST_TMPDIR/badtok"
  run cctg config mybot token --token-stdin < "$BATS_TEST_TMPDIR/badtok"
  [ "$status" -eq 0 ]
  ( set -a; . "$env" )
  [ ! -e "$canary" ]
  ( set -a; . "$env"; [ "$TELEGRAM_BOT_TOKEN" = "; touch $canary #" ] )
}
