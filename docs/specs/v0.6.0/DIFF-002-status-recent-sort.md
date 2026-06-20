# DIFF — v0.6.0/002-status-recent-sort

작성: 2026-06-20 10:34
SoT: `git diff` (본 파일은 그 요약본). 대상 파일 — lib/commands.sh, tests/status_view.bats, tests/stubs/tmux.

> 주의(혼합 변경 경고): 본 차수 작업과 무관하게 `docs/TODO.md` 가 세션 시작 시점에 이미 수정된
> 상태였다(uncommitted, 선행). 본 DIFF 에는 포함하지 않았다. 커밋 시 차수 분리를 권장한다.

```diff
diff --git a/lib/commands.sh b/lib/commands.sh
index cfcc948..397035b 100644
--- a/lib/commands.sh
+++ b/lib/commands.sh
@@ -597,6 +597,21 @@ _status_render_reserved_bot() {
   t STATUS_CHANNEL "$(channel_spec "$ch" display)"
 }
 
+# status 정렬: running/dead 버킷(개행 구분 봇 이름)을 세션 생성시각(session_created) 내림차순으로
+# 재정렬한다 — 최근 실행한 봇이 위로. 동률·미상(tmux 조회 실패·비숫자)은 입력(등록) 순서를 유지
+# (안정 정렬 -s), 미상(created=0)은 버킷 최하위로. sess_pt 가 프로젝트/예약어 봇 공용이라 두 섹션이
+# 같은 헬퍼를 쓴다. broken/stopped 는 세션이 없어 created 가 없으므로 호출하지 않는다.
+_sort_bucket_by_created() {
+  local bucket="$1" n created tab
+  tab="$(printf '\t')"
+  while IFS= read -r n; do
+    [ -z "$n" ] && continue
+    created="$(tmux display-message -p -t "$(sess_pt "$n")" '#{session_created}' 2>/dev/null)"
+    case "$created" in ''|*[!0-9]*) created=0 ;; esac
+    printf '%s%s%s\n' "$created" "$tab" "$n"
+  done <<< "$bucket" | sort -t"$tab" -k1,1nr -s | cut -f2-
+}
+
 cmd_status() {
     [ "${1:-}" = "--json" ] && { status_json; return; }
     if [ -n "${1:-}" ]; then te ERR_STATUS_UNKNOWN_FLAG "$1"; usage >&2; exit 1; fi
@@ -615,6 +630,10 @@ cmd_status() {
         *)       p_stopped="${p_stopped}${n}"$'\n' ;;
       esac
     done < <(all_names)
+    # RUNNING·DEAD 버킷 내부는 세션 생성시각 내림차순(최근 실행이 위)으로 재정렬. broken/stopped 는
+    # 등록 순서 유지(세션 없음 → created 부재).
+    p_running="$(_sort_bucket_by_created "$p_running")"
+    p_dead="$(_sort_bucket_by_created "$p_dead")"
     # RUNNING(위) → DEAD(크래시) → BROKEN(설정결손) → stopped(아래) 순. 분류 시 판정한 state 를
     # 렌더에 그대로 넘겨 재판정(ps 재스캔)을 피한다.
     local st bucket
@@ -645,6 +664,9 @@ cmd_status() {
         *)       r_stopped="${r_stopped}${ch}"$'\n' ;;
       esac
     done
+    # 전역 봇 RUNNING·DEAD 버킷도 동일하게 최근 실행순 정렬.
+    r_running="$(_sort_bucket_by_created "$r_running")"
+    r_dead="$(_sort_bucket_by_created "$r_dead")"
     local ch_found=0 rst rbucket
     for rst in running dead broken stopped; do
       case "$rst" in
diff --git a/tests/status_view.bats b/tests/status_view.bats
index 1734288..d2d1d59 100644
--- a/tests/status_view.bats
+++ b/tests/status_view.bats
@@ -101,3 +101,66 @@ make_jqless_path() {
   p2=$(grep -n '\[RUNNING\] two' <<<"$output" | head -1 | cut -d: -f1)
   [ "$p1" -lt "$p2" ]   # one registered before two → stays first
 }
+
+# --- v0.6.0/002: within-bucket recency sort (RUNNING·DEAD by session_created desc) ---
+
+# Map a bot's session to a session_created epoch for the fake tmux, so the
+# recency sort sees distinct per-session start times (real tmux returns each
+# session's own #{session_created}).
+set_created() {
+  export FAKE_TMUX_CREATED_FILE="$BATS_TEST_TMPDIR/.tmux-created"
+  printf 'cctg-%s\t%s\n' "$1" "$2" >> "$FAKE_TMUX_CREATED_FILE"
+}
+
+@test "status: RUNNING bucket lists most-recently-started bot first (SC-001)" {
+  seed_bot older       # registered first
+  seed_bot newer       # registered second, but started later
+  mark_running older
+  mark_running newer
+  set_created older 1700000000
+  set_created newer 1700009999
+  run cctg status
+  [ "$status" -eq 0 ]
+  local pn po
+  pn=$(grep -n '\[RUNNING\] newer' <<<"$output" | head -1 | cut -d: -f1)
+  po=$(grep -n '\[RUNNING\] older' <<<"$output" | head -1 | cut -d: -f1)
+  [ -n "$pn" ] && [ -n "$po" ]
+  [ "$pn" -lt "$po" ]   # newer session_created sorts above older despite registry order
+}
+
+@test "status: DEAD bucket lists most-recently-started bot first (SC-002)" {
+  seed_bot d_old
+  seed_bot d_new
+  mark_running d_old
+  mark_running d_new
+  # claude-less process tree → both sessions classify as DEAD, not RUNNING.
+  export FAKE_PS_TREE="$FAKE_TMUX_PANE_PID 1 bash"
+  set_created d_old 1700000000
+  set_created d_new 1700009999
+  run cctg status
+  [ "$status" -eq 0 ]
+  local pn po
+  pn=$(grep -n 'd_new' <<<"$output" | grep DEAD | head -1 | cut -d: -f1)
+  po=$(grep -n 'd_old' <<<"$output" | grep DEAD | head -1 | cut -d: -f1)
+  [ -n "$pn" ] && [ -n "$po" ]
+  [ "$pn" -lt "$po" ]   # newer dead session sorts above older dead session
+}
+
+@test "status: reserved global bots also sort RUNNING by recency (SC-005)" {
+  # telegram precedes discord in RESERVED_NAMES iteration order; make discord the
+  # more-recently-started one so recency sort floats it above telegram.
+  mkdir -p "$CC_CHANNELS_DIR/telegram" "$CC_CHANNELS_DIR/discord"
+  printf 'TELEGRAM_BOT_TOKEN=x\n' > "$CC_CHANNELS_DIR/telegram/.env"
+  printf 'DISCORD_BOT_TOKEN=x\n'  > "$CC_CHANNELS_DIR/discord/.env"
+  mark_running telegram
+  mark_running discord
+  set_created telegram 1700000000
+  set_created discord  1700009999
+  run cctg status
+  [ "$status" -eq 0 ]
+  local pd pt
+  pd=$(grep -n '\[RUNNING\] discord'  <<<"$output" | head -1 | cut -d: -f1)
+  pt=$(grep -n '\[RUNNING\] telegram' <<<"$output" | head -1 | cut -d: -f1)
+  [ -n "$pd" ] && [ -n "$pt" ]
+  [ "$pd" -lt "$pt" ]   # discord (later session_created) sorts above telegram
+}
diff --git a/tests/stubs/tmux b/tests/stubs/tmux
index 139c885..038d93e 100755
--- a/tests/stubs/tmux
+++ b/tests/stubs/tmux
@@ -107,13 +107,24 @@ case "$cmd" in
     # target-pane: a bare '=NAME' resolves to nothing -> empty value, rc 0
     # (faithful to real tmux; this is the silent status/uptime bug's signature).
     target="$(flag_val -t "$@")" || true
-    if [ -n "$target" ] && [ -z "$(resolve_pane "$target")" ]; then exit 0; fi
+    resolved="$(resolve_pane "$target")"
+    if [ -n "$target" ] && [ -z "$resolved" ]; then exit 0; fi
     # Format-aware: '#{pane_pid}' (liveness check) returns FAKE_TMUX_PANE_PID so a test
-    # can point claude_alive's process walk at a tree it controls; everything else
-    # (session_created / pane_current_path) returns FAKE_TMUX_CREATED as before.
+    # can point claude_alive's process walk at a tree it controls. '#{session_created}'
+    # is per-session when FAKE_TMUX_CREATED_FILE (lines "<session>\t<epoch>") maps the
+    # resolved session — mirroring real tmux returning each session's own creation time,
+    # so the status recency-sort can be exercised. Everything else (and any unmapped
+    # session, e.g. pane_current_path) falls back to FAKE_TMUX_CREATED as before.
     fmt=""; for fmt in "$@"; do :; done
     case "$fmt" in
       *pane_pid*) printf '%s\n' "${FAKE_TMUX_PANE_PID:-0}" ;;
+      *session_created*)
+        created=""
+        if [ -n "${FAKE_TMUX_CREATED_FILE:-}" ] && [ -f "${FAKE_TMUX_CREATED_FILE}" ] && [ -n "$resolved" ]; then
+          created="$(awk -F'\t' -v s="$resolved" '$1==s{print $2; exit}' "$FAKE_TMUX_CREATED_FILE")"
+        fi
+        [ -n "$created" ] || created="${FAKE_TMUX_CREATED:-1700000000}"
+        printf '%s\n' "$created" ;;
       *)          printf '%s\n' "${FAKE_TMUX_CREATED:-1700000000}" ;;
     esac ;;
   capture-pane)
```
