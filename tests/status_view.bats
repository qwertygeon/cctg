#!/usr/bin/env bats
# Human-readable `cctg status` (non-JSON) — per-bot channel display name and
# connection topology, plus jq-less graceful degradation (FR-007, NFR-005).

load test_helper

# Register a discord bot non-interactively (id_required=no, so no --id needed).
# Uses --token-env to avoid leaking the token through argv.
seed_discord() {
  local name="$1"; shift || true
  BOT_TOKEN="dtok-$name" bash "$CCTG" add "$name" "$WORK" \
    --channel discord --token-env BOT_TOKEN "$@" >/dev/null
}

# Build a PATH that resolves every tool the script needs EXCEPT jq, so we can
# exercise the jq-less degradation path (SC-020) without uninstalling jq.
make_jqless_path() {
  local bin="$BATS_TEST_TMPDIR/nojq-bin" t src
  mkdir -p "$bin"
  for t in awk sed grep cut tr stat date mkdir chmod cat head tail cp rm env bash sh ln; do
    src="$(command -v "$t" 2>/dev/null)" || continue
    ln -sf "$src" "$bin/$t"
  done
  # stubs dir keeps the fake tmux; deliberately omit /usr/bin (where jq lives).
  printf '%s' "$REPO_ROOT/tests/stubs:$bin"
}

@test "status: shows Telegram and Discord display names per bot (SC-018)" {
  seed_bot tgbot                      # telegram (helper adds --id 555)
  seed_discord dcbot
  run cctg status -a                  # bots are stopped → need -a to render them
  [ "$status" -eq 0 ]
  [[ "$output" == *"Telegram"* ]]
  [[ "$output" == *"Discord"* ]]
}

@test "status: shows a last-activity line for a running bot" {
  seed_bot mybot
  mark_running mybot
  run cctg status -a                  # activity row only shown with -a
  [ "$status" -eq 0 ]
  [[ "$output" == *" ago"* ]]         # last-activity line ("last  <dur> ago")
}

@test "status: a DEAD bot still shows a last-activity line; a broken bot does not" {
  seed_bot deadbot
  mark_running deadbot
  export FAKE_PS_TREE="$FAKE_TMUX_PANE_PID 1 bash"   # claude-less tree → DEAD
  run cctg status -a                                 # DEAD activity row only with -a
  [ "$status" -eq 0 ]
  [[ "$output" == *"[DEAD"* ]]
  [[ "$output" == *" ago"* ]]
  unset FAKE_PS_TREE
  # broken bot (missing token) has no live session → no last-activity line
  registry_raw "brokebot | $WORK | $CC_CHANNELS_DIR/brokebot"
  mkdir -p "$CC_CHANNELS_DIR/brokebot"               # dir exists, no .env → broken
  run cctg status
  [ "$status" -eq 0 ]
  [[ "$output" == *"[BROKEN"* ]]
}

@test "status: with jq shows dmPolicy and group count for a discord bot (SC-019)" {
  seed_discord dcbot                  # --id absent → pairing, groups {}
  run cctg status -a                  # bot is stopped → need -a to render it
  [ "$status" -eq 0 ]
  [[ "$output" == *"pairing"* ]]
  [[ "$output" == *"0 groups"* ]]
}

@test "status: without jq degrades to display name only, no error (SC-020)" {
  seed_discord dcbot                  # seeded while jq is available (heredoc path)
  PATH="$(make_jqless_path)" run cctg status -a   # bot is stopped → need -a
  [ "$status" -eq 0 ]
  [[ "$output" == *"Discord"* ]]
}

# --- v0.5.1/004: cwd/state readability (B aligned split + C ~ shortening) ---

@test "status: cwd and state render on separate lines (B)" {
  seed_bot mybot
  run cctg status -a                  # stopped bot → need -a to render its paths
  [ "$status" -eq 0 ]
  [[ "$output" == *"cwd"* ]]
  [[ "$output" == *"state"* ]]
  # they used to share one line; now no single line carries both
  ! grep -qE 'cwd.*state' <<<"$output"
}

@test "status: home paths are shortened to ~ (C)" {
  mkdir -p "$HOME/proj"
  seed_bot hbot "$HOME/proj"
  run cctg status -a                     # stopped bot → need -a to render its paths
  [ "$status" -eq 0 ]
  [[ "$output" == *"~/proj"* ]]          # cwd shown tilde-shortened
  [[ "$output" != *"$HOME/proj"* ]]      # not the full absolute home path
}

# --- v0.5.1/005: state sort (running → broken → stopped) ---

@test "status: sorts RUNNING above BROKEN above stopped (registry order alpha,bravo,charlie)" {
  seed_bot alpha       # stopped (token + cwd present, not running)
  seed_bot bravo       # will be marked running
  seed_bot charlie     # broken: remove its token
  mark_running bravo
  rm -f "$CC_CHANNELS_DIR/charlie/.env"
  run cctg status -a                  # ordering test includes stopped → need -a
  [ "$status" -eq 0 ]
  local r b s
  r=$(grep -n '\[RUNNING\] bravo'  <<<"$output" | head -1 | cut -d: -f1)
  b=$(grep -n '\[BROKEN \] charlie' <<<"$output" | head -1 | cut -d: -f1)
  s=$(grep -n '\[stopped\] alpha'   <<<"$output" | head -1 | cut -d: -f1)
  [ -n "$r" ] && [ -n "$b" ] && [ -n "$s" ]
  [ "$r" -lt "$b" ]   # running sorts above broken
  [ "$b" -lt "$s" ]   # broken sorts above stopped
}

@test "status: within the same state, registry order is preserved (stable)" {
  seed_bot one
  seed_bot two
  mark_running one
  mark_running two
  run cctg status
  [ "$status" -eq 0 ]
  local p1 p2
  p1=$(grep -n '\[RUNNING\] one' <<<"$output" | head -1 | cut -d: -f1)
  p2=$(grep -n '\[RUNNING\] two' <<<"$output" | head -1 | cut -d: -f1)
  [ "$p1" -lt "$p2" ]   # one registered before two → stays first
}

# --- v0.6.0/002: within-bucket recency sort (RUNNING·DEAD by session_created desc) ---

# Map a bot's session to a session_created epoch for the fake tmux, so the
# recency sort sees distinct per-session start times (real tmux returns each
# session's own #{session_created}).
set_created() {
  export FAKE_TMUX_CREATED_FILE="$BATS_TEST_TMPDIR/.tmux-created"
  printf 'cctg-%s\t%s\n' "$1" "$2" >> "$FAKE_TMUX_CREATED_FILE"
}

@test "status: RUNNING bucket lists most-recently-started bot first (SC-001)" {
  seed_bot older       # registered first
  seed_bot newer       # registered second, but started later
  mark_running older
  mark_running newer
  set_created older 1700000000
  set_created newer 1700009999
  run cctg status
  [ "$status" -eq 0 ]
  local pn po
  pn=$(grep -n '\[RUNNING\] newer' <<<"$output" | head -1 | cut -d: -f1)
  po=$(grep -n '\[RUNNING\] older' <<<"$output" | head -1 | cut -d: -f1)
  [ -n "$pn" ] && [ -n "$po" ]
  [ "$pn" -lt "$po" ]   # newer session_created sorts above older despite registry order
}

@test "status: DEAD bucket lists most-recently-started bot first (SC-002)" {
  seed_bot d_old
  seed_bot d_new
  mark_running d_old
  mark_running d_new
  # claude-less process tree → both sessions classify as DEAD, not RUNNING.
  export FAKE_PS_TREE="$FAKE_TMUX_PANE_PID 1 bash"
  set_created d_old 1700000000
  set_created d_new 1700009999
  run cctg status
  [ "$status" -eq 0 ]
  local pn po
  pn=$(grep -n 'd_new' <<<"$output" | grep DEAD | head -1 | cut -d: -f1)
  po=$(grep -n 'd_old' <<<"$output" | grep DEAD | head -1 | cut -d: -f1)
  [ -n "$pn" ] && [ -n "$po" ]
  [ "$pn" -lt "$po" ]   # newer dead session sorts above older dead session
}

@test "status: reserved global bots also sort RUNNING by recency (SC-005)" {
  # telegram precedes discord in RESERVED_NAMES iteration order; make discord the
  # more-recently-started one so recency sort floats it above telegram.
  mkdir -p "$CC_CHANNELS_DIR/telegram" "$CC_CHANNELS_DIR/discord"
  printf 'TELEGRAM_BOT_TOKEN=x\n' > "$CC_CHANNELS_DIR/telegram/.env"
  printf 'DISCORD_BOT_TOKEN=x\n'  > "$CC_CHANNELS_DIR/discord/.env"
  mark_running telegram
  mark_running discord
  set_created telegram 1700000000
  set_created discord  1700009999
  run cctg status
  [ "$status" -eq 0 ]
  local pd pt
  pd=$(grep -n '\[RUNNING\] discord'  <<<"$output" | head -1 | cut -d: -f1)
  pt=$(grep -n '\[RUNNING\] telegram' <<<"$output" | head -1 | cut -d: -f1)
  [ -n "$pd" ] && [ -n "$pt" ]
  [ "$pd" -lt "$pt" ]   # discord (later session_created) sorts above telegram
}

# --- v0.8.1/001: default running-filter + total summary + -a/--all ---

@test "status: default hides stopped bots; -a reveals them (DEC-001)" {
  seed_bot stoppedbot                 # registered, not running → stopped
  run cctg status
  [ "$status" -eq 0 ]
  [[ "$output" != *"stoppedbot"* ]]   # hidden by default
  run cctg status -a
  [ "$status" -eq 0 ]
  [[ "$output" == *"stoppedbot"* ]]   # shown with -a
  [[ "$output" == *"[stopped]"* ]]
}

@test "status: --all is an alias of -a (stopped shown)" {
  seed_bot stoppedbot
  run cctg status --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"stoppedbot"* ]]
}

@test "status: default hides the last-activity row; -a shows it (DEC-001)" {
  seed_bot mybot
  mark_running mybot
  run cctg status
  [ "$status" -eq 0 ]
  [[ "$output" != *" ago"* ]]         # activity hidden by default
  run cctg status -a
  [ "$status" -eq 0 ]
  [[ "$output" == *" ago"* ]]         # activity shown with -a
}

@test "status: first line summarizes total target count (DEC-002)" {
  seed_bot a
  seed_bot b
  run cctg status
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == *"2"* ]]        # "Targets: 2 total" / "타겟 총 2개"
  [[ "$output" == *"-a"* ]]           # default carries the -a hint
  run cctg status -a
  [ "$status" -eq 0 ]
  [[ "$output" != *"use -a"* ]]       # no "use -a" hint when already showing all
}

@test "status: DEAD and BROKEN stay visible by default (scope A)" {
  seed_bot deadbot
  mark_running deadbot
  export FAKE_PS_TREE="$FAKE_TMUX_PANE_PID 1 bash"   # claude-less tree → DEAD
  run cctg status
  unset FAKE_PS_TREE
  [ "$status" -eq 0 ]
  [[ "$output" == *"[DEAD"* ]]        # DEAD shown without -a
  seed_bot brokebot
  rm -f "$CC_CHANNELS_DIR/brokebot/.env"
  run cctg status
  [ "$status" -eq 0 ]
  [[ "$output" == *"[BROKEN"* ]]      # BROKEN shown without -a
}

@test "status --json is unaffected by the filter (always full)" {
  seed_bot stoppedbot
  run cctg status --json
  [ "$status" -eq 0 ]
  [[ "$output" == *"stoppedbot"* ]]   # json always includes stopped bots
}
