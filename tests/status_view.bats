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
