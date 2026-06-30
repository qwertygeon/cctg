#!/usr/bin/env bats
# Multi-target up/restart launch serialization (v0.8.2/001-serialize-up-launch).
#
# Each `claude --channels` launch is fire-and-forget, so launching several bots at
# once boots them near-simultaneously and they race on shared global ~/.claude state
# (only one channel survives). _lifecycle_run now waits for the previous bot to
# settle (await_up_settled) before launching the next.
#
# Observability: the `sleep` stub appends one line per call to $FAKE_SLEEP_LOG and
# returns instantly. With a healthy fake tree claude_alive is true immediately, so
# await_up_settled's poll loop never sleeps and CC_TG_UP_SETTLE=1 makes each await
# log exactly one settle sleep — so the sleep-log line count == number of awaits.

load test_helper

# Count lines (= sleep calls) recorded by the sleep stub. wc -l yields 0 on an empty
# file with exit 0 (grep -c '' would exit 1 and double up with a `|| echo 0` fallback).
sleep_calls() { wc -l < "$FAKE_SLEEP_LOG" | tr -d ' '; }

setup_serialize() {
  export FAKE_SLEEP_LOG="$BATS_TEST_TMPDIR/sleeps"; : > "$FAKE_SLEEP_LOG"
  export CC_TG_UP_SETTLE=1            # one settle sleep per await (override helper default 0)
}

@test "up: single target does not stagger (no await) (SC-001)" {
  setup_serialize
  seed_bot a
  run cctg up a
  [ "$status" -eq 0 ]
  [ "$(sleep_calls)" -eq 0 ]
}

@test "up: two targets stagger once between them (SC-002)" {
  setup_serialize
  seed_bot a; seed_bot b
  run cctg up a b
  [ "$status" -eq 0 ]
  grep -qxF "cctg-a" "$FAKE_TMUX_STATE"
  grep -qxF "cctg-b" "$FAKE_TMUX_STATE"
  [ "$(sleep_calls)" -eq 1 ]         # await before b only
}

@test "up: three targets stagger twice (SC-002 extended)" {
  setup_serialize
  seed_bot a; seed_bot b; seed_bot c
  run cctg up a b c
  [ "$status" -eq 0 ]
  [ "$(sleep_calls)" -eq 2 ]         # await before b and before c
}

@test "up: a failing target does not trigger a wait before the next (SC-003)" {
  setup_serialize
  seed_bot a
  run cctg up ghost a                # ghost is unregistered -> fails first
  [ "$status" -ne 0 ]
  grep -qxF "cctg-a" "$FAKE_TMUX_STATE"   # a still starts
  [ "$(sleep_calls)" -eq 0 ]         # no launch happened before a -> no wait
}

@test "down: multiple targets never stagger (SC-004)" {
  setup_serialize
  seed_bot a; seed_bot b
  cctg up a b >/dev/null
  : > "$FAKE_SLEEP_LOG"              # ignore sleeps from the setup `up`
  run cctg down a b
  [ "$status" -eq 0 ]
  [ "$(sleep_calls)" -eq 0 ]
}

@test "restart: staggers between targets (SC-005)" {
  setup_serialize
  seed_bot a; seed_bot b
  run cctg restart a b
  [ "$status" -eq 0 ]
  grep -qxF "cctg-a" "$FAKE_TMUX_STATE"
  grep -qxF "cctg-b" "$FAKE_TMUX_STATE"
  [ "$(sleep_calls)" -eq 1 ]         # await before b's restart
}

@test "await: polls claude_alive only up to READY_TIMEOUT when the bot never comes up (SC-006)" {
  setup_serialize
  export CC_TG_UP_SETTLE=0           # isolate the poll-loop sleeps from the settle
  export CC_TG_UP_READY_TIMEOUT=2
  export FAKE_PS_TREE="700001 1 bash"   # no `claude` child -> claude_alive stays false
  seed_bot a; seed_bot b
  run cctg up a b
  [ "$status" -eq 0 ]
  [ "$(sleep_calls)" -eq 2 ]         # poll sleeps capped at READY_TIMEOUT, then gives up
}

@test "up: CC_TG_UP_SETTLE=0 performs no settle sleep (SC-007)" {
  setup_serialize
  export CC_TG_UP_SETTLE=0
  seed_bot a; seed_bot b
  run cctg up a b
  [ "$status" -eq 0 ]
  [ "$(sleep_calls)" -eq 0 ]         # claude_alive true immediately + no settle
}
