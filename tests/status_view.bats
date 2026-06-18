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
  run cctg status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Telegram"* ]]
  [[ "$output" == *"Discord"* ]]
}

@test "status: with jq shows dmPolicy and group count for a discord bot (SC-019)" {
  seed_discord dcbot                  # --id absent → pairing, groups {}
  run cctg status
  [ "$status" -eq 0 ]
  [[ "$output" == *"pairing"* ]]
  [[ "$output" == *"0 groups"* ]]
}

@test "status: without jq degrades to display name only, no error (SC-020)" {
  seed_discord dcbot                  # seeded while jq is available (heredoc path)
  PATH="$(make_jqless_path)" run cctg status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Discord"* ]]
}

# --- v0.5.1/004: cwd/state readability (B aligned split + C ~ shortening) ---

@test "status: cwd and state render on separate lines (B)" {
  seed_bot mybot
  run cctg status
  [ "$status" -eq 0 ]
  [[ "$output" == *"cwd"* ]]
  [[ "$output" == *"state"* ]]
  # they used to share one line; now no single line carries both
  ! grep -qE 'cwd.*state' <<<"$output"
}

@test "status: home paths are shortened to ~ (C)" {
  mkdir -p "$HOME/proj"
  seed_bot hbot "$HOME/proj"
  run cctg status
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
  run cctg status
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
