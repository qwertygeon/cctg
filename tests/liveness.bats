#!/usr/bin/env bats
# Health-based liveness — `cctg status` distinguishes a truly-running bot from a
# DEAD one (tmux session alive but the `claude` process has exited; the false-UP
# the launch's `exec bash` tail leaves behind). claude_alive() walks the pane's
# process descendant tree for a `claude` process; the ps stub fakes that tree.
#
# Default (no FAKE_PS_TREE): tree has a claude child of FAKE_TMUX_PANE_PID -> RUNNING.
# DEAD is simulated by overriding FAKE_PS_TREE with a claude-less tree.

load test_helper

# A process tree rooted at the fake pane_pid with NO claude (bot crashed; only the
# pane's bash and some unrelated child remain).
dead_tree() {
  printf '%s 1 bash\n%s %s node\n' "$FAKE_TMUX_PANE_PID" "$((FAKE_TMUX_PANE_PID + 5))" "$FAKE_TMUX_PANE_PID"
}

@test "status: a running session with a live claude shows RUNNING" {
  seed_bot mybot
  mark_running mybot
  run cctg status
  [ "$status" -eq 0 ]
  [[ "$output" == *"[RUNNING] mybot"* ]]
  [[ "$output" != *"[DEAD"* ]]
}

@test "status: a running session whose claude has exited shows DEAD (false-UP)" {
  seed_bot mybot
  mark_running mybot
  export FAKE_PS_TREE="$(dead_tree)"
  run cctg status
  [ "$status" -eq 0 ]
  [[ "$output" == *"[DEAD   ] mybot"* ]]
  [[ "$output" != *"[RUNNING] mybot"* ]]
  # restart recovery hint is surfaced
  [[ "$output" == *"restart mybot"* ]]
}

@test "status --json: a DEAD bot has state=dead, running=false, null uptime" {
  seed_bot mybot
  mark_running mybot
  export FAKE_PS_TREE="$(dead_tree)"
  run cctg status --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.[0].state' <<<"$output")" = "dead" ]
  [ "$(jq -r '.[0].running' <<<"$output")" = "false" ]
  [ "$(jq -r '.[0].uptimeSeconds' <<<"$output")" = "null" ]
}

@test "status --json: a live bot stays state=running, running=true" {
  seed_bot mybot
  mark_running mybot
  run cctg status --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.[0].state' <<<"$output")" = "running" ]
  [ "$(jq -r '.[0].running' <<<"$output")" = "true" ]
}

@test "status: DEAD bots sort above stopped (running -> dead -> stopped)" {
  seed_bot alive
  seed_bot crashed
  seed_bot idle
  mark_running alive
  mark_running crashed
  # crashed's pane has no claude; alive's does. Single shared fake pane_pid means
  # the per-bot tree is the same fixture, so isolate: only crashed is running+dead
  # by running this assertion on ordering of dead(crashed) vs stopped(idle).
  export FAKE_PS_TREE="$(dead_tree)"
  run cctg status
  [ "$status" -eq 0 ]
  # With the dead tree, both running sessions read DEAD; idle is stopped.
  # DEAD must appear before stopped in the rendered order.
  local dead_line stopped_line
  dead_line="$(printf '%s\n' "$output" | grep -n '\[DEAD' | head -1 | cut -d: -f1)"
  stopped_line="$(printf '%s\n' "$output" | grep -n '\[stopped\] idle' | cut -d: -f1)"
  [ -n "$dead_line" ] && [ -n "$stopped_line" ]
  [ "$dead_line" -lt "$stopped_line" ]
}
