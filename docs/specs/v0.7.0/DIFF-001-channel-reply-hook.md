# DIFF — v0.7.0/001-channel-reply-hook

> git diff 가 SoT. 본 문서는 그 요약(코드 핵심)이다. 작성: 2026-06-22

## diffstat

```
 CHANGELOG.md             |  3 +++
 README.ko.md             |  2 ++
 README.md                |  2 ++
 docs/configuration.ko.md | 20 ++++++++++++++++++--
 docs/configuration.md    | 20 ++++++++++++++++++--
 lib/commands.sh          | 11 +++++++++++
 lib/env.sh               |  4 ++++
 lib/session.sh           | 14 ++++++++++----
 lib/util.sh              | 15 +++++++++++++++
 messages/en.sh           |  4 ++++
 messages/ko.sh           |  4 ++++
 11 files changed, 91 insertions(+), 8 deletions(-)

신규: tests/reply_reminder.bats, docs/specs/v0.7.0/*
```

## 코드 변경 (lib/)

```diff
diff --git a/lib/commands.sh b/lib/commands.sh
index aeba64f..b864ae8 100644
--- a/lib/commands.sh
+++ b/lib/commands.sh
@@ -157,6 +157,7 @@ EOF
     # 등록 전 비정상 종료(쓰기 실패 등) 시 우리가 새로 만든 SD 만 정리한다(DEC-004, EXIT trap).
     # 사전에 존재하던 디렉터리는 절대 건드리지 않는다(P-002). 등록(point of no return) 후 trap 해제.
     ensure_shared_settings
+    ensure_reply_reminder
     CCTG_ADD_CLEANUP_DIR=""
     trap '[ -n "${CCTG_ADD_CLEANUP_DIR:-}" ] && rm -rf "$CCTG_ADD_CLEANUP_DIR"' EXIT
     [ -e "$SD" ] || CCTG_ADD_CLEANUP_DIR="$SD"
@@ -213,6 +214,10 @@ ENV
     local pmshow="${PMODE:-$(t FOLLOW_SHARED)}"
     t ADD_DONE_MODE "$pmshow" "$PROG" "$PROG" "$NAME"
     t ADD_DONE_NEXT "$PROG" "$NAME"
+    # 봇이 채널 메시지에 reply 도구로 답하도록 강제하는 리마인더가 기본 ON 임을 알린다(인지·편집·opt-out 경로).
+    if [ -s "$REPLY_REMINDER_FILE" ]; then
+      t ADD_DONE_REPLY_REMINDER "$(tilde "$REPLY_REMINDER_FILE")"
+    fi
 }
 
 cmd_rm() {
@@ -908,6 +913,12 @@ cmd_doctor() {
     else
       t DOCTOR_SHARED_NONE
     fi
+    # 채널 reply 리마인더 상태(봇에 --append-system-prompt 로 주입). 비어 있거나 부재면 OFF(opt-out).
+    if [ -s "$REPLY_REMINDER_FILE" ]; then
+      t DOCTOR_REPLY_REMINDER_ON "$(tilde "$REPLY_REMINDER_FILE")"
+    else
+      t DOCTOR_REPLY_REMINDER_OFF "$(tilde "$REPLY_REMINDER_FILE")"
+    fi
     t DOCTOR_PLUGIN_HINT "$IMPLEMENTED_CHANNELS"
 
     # --- install integrity (흔한 운영 실패 사전 진단) ---
diff --git a/lib/env.sh b/lib/env.sh
index 5a25ee3..e8d5016 100644
--- a/lib/env.sh
+++ b/lib/env.sh
@@ -7,6 +7,10 @@ REGISTRY="${CC_TG_REGISTRY:-$CHANNELS_DIR/projects.conf}"
 # 전역 ~/.claude/settings.json 과 merge 되며(deny 는 union, deny 가 allow 보다 우선),
 # 여기 defaultMode 가 봇의 기본 권한 모드가 된다. 봇별 launch.env 의 CCTG_PERMISSION_MODE 가 우선한다.
 SHARED_SETTINGS="${CC_TG_SHARED_SETTINGS:-$CHANNELS_DIR/cctg-shared.settings.json}"
+# 모든 CCTG 봇에 --append-system-prompt 로 주입되는 채널 reply 리마인더 텍스트.
+# cctg 가 부재 시 기본 문구로 시드(기본 ON). 비우면 주입 안 함(opt-out), 편집하면 그 내용으로 주입.
+# 봇 세션에만 적용되며 사용자의 일반 claude 사용에는 영향 없다.
+REPLY_REMINDER_FILE="${CC_TG_REPLY_REMINDER_FILE:-$CHANNELS_DIR/cctg-reply-reminder.txt}"
 SESS_PREFIX="cctg-"
 # detached 세션 폭(칼럼)의 최종 폴백 기본값. tmux detached 기본은 80 이라 logs/snapshot 캡처가
 # 80 폭으로 잘린다 — client 미부착 상태에서도 더 넓은 출력을 보존하려고 new-session -x 로 고정한다.
diff --git a/lib/session.sh b/lib/session.sh
index 850a47d..bf2e329 100644
--- a/lib/session.sh
+++ b/lib/session.sh
@@ -160,8 +160,10 @@ up_one() {
 
   # 공통 설정(권한 정책)을 --settings 로 주입. 없으면 시드.
   ensure_shared_settings
-  local shared_arg=""
+  ensure_reply_reminder
+  local shared_arg="" reminder_q
   [ -f "$SHARED_SETTINGS" ] && shared_arg="--settings $(printf '%q' "$SHARED_SETTINGS")"
+  reminder_q="$(printf '%q' "$REPLY_REMINDER_FILE")"
 
   # 상태 디렉터리/토큰을 분리 주입하고 caffeinate로 sleep 방지하며 채널 세션 기동.
   # 봇별 launch.env(있으면)에서 CCTG_PERMISSION_MODE / CLAUDE_EXTRA_ARGS 를 읽어 claude 인자로 전달한다.
@@ -180,7 +182,8 @@ up_one() {
 && set +a \
 && MODE_ARG=\"\" \
 && { [ -n \"\${CCTG_PERMISSION_MODE:-}\" ] && MODE_ARG=\"--permission-mode \${CCTG_PERMISSION_MODE}\" || true; } \
-&& caffeinate -is claude --channels $plugin $shared_arg \${MODE_ARG} \${CLAUDE_EXTRA_ARGS:-}; exec bash"
+&& { [ -s $reminder_q ] && set -- --append-system-prompt \"\$(cat $reminder_q)\" || set --; } \
+&& caffeinate -is claude --channels $plugin $shared_arg \${MODE_ARG} \"\$@\" \${CLAUDE_EXTRA_ARGS:-}; exec bash"
 
   # new-session 실패(서버 기동 불가·리소스 부족·직전 race 등)를 확인 — 미확인 시 거짓 UP 보고.
   if ! start_session "$(sess_of "$name")" "$launch" "$(effective_sess_width "$sd")"; then
@@ -252,8 +255,10 @@ up_reserved() {
   need_claude || return 1
 
   ensure_shared_settings
-  local shared_arg=""
+  ensure_reply_reminder
+  local shared_arg="" reminder_q
   [ -f "$SHARED_SETTINGS" ] && shared_arg="--settings $(printf '%q' "$SHARED_SETTINGS")"
+  reminder_q="$(printf '%q' "$REPLY_REMINDER_FILE")"
 
   local sd_env plugin
   sd_env="$(channel_spec "$ch" statedir_env)"
@@ -266,7 +271,8 @@ up_reserved() {
 && set +a \
 && MODE_ARG=\"\" \
 && { [ -n \"\${CCTG_PERMISSION_MODE:-}\" ] && MODE_ARG=\"--permission-mode \${CCTG_PERMISSION_MODE}\" || true; } \
-&& caffeinate -is claude --channels $plugin $shared_arg \${MODE_ARG} \${CLAUDE_EXTRA_ARGS:-}; exec bash"
+&& { [ -s $reminder_q ] && set -- --append-system-prompt \"\$(cat $reminder_q)\" || set --; } \
+&& caffeinate -is claude --channels $plugin $shared_arg \${MODE_ARG} \"\$@\" \${CLAUDE_EXTRA_ARGS:-}; exec bash"
 
   if ! start_session "$(sess_of "$ch")" "$launch" "$(effective_sess_width "$sd")"; then
     te ERR_UP_FAILED "$ch"; return 1
diff --git a/lib/util.sh b/lib/util.sh
index b993d55..fb3adf1 100644
--- a/lib/util.sh
+++ b/lib/util.sh
@@ -36,6 +36,21 @@ ensure_shared_settings() {
 JSON
   te SHARED_CREATED "$SHARED_SETTINGS"
 }
+
+# 채널 reply 리마인더 텍스트를 부재 시 기본 문구로 시드(기본 ON). 봇 기동 시 이 파일의 내용이
+# claude --append-system-prompt 로 주입되어, 봇이 채널 메시지에 reply 도구로(quote-reply 포함)
+# 답하도록 강제한다. opt-out 은 파일을 비우는 것(`: > 파일`) — 존재하면 재시드하지 않으므로
+# 빈 파일이 유지되고 주입도 건너뛴다. 편집(수정)은 존재 파일을 덮어쓰지 않아 보존된다.
+# (삭제하면 다음 기동에 재시드된다 — 끄려면 삭제가 아니라 비운다.)
+ensure_reply_reminder() {
+  [ -e "$REPLY_REMINDER_FILE" ] && return 0
+  mkdir -p "$(dirname "$REPLY_REMINDER_FILE")" 2>/dev/null || true
+  cat > "$REPLY_REMINDER_FILE" <<'TXT'
+You are running as a CCTG chat-channel bot (Telegram/Discord). Every user message reaches you through the channel, and your terminal/transcript output is NOT delivered to the user. Therefore you MUST reply by calling the channel's reply tool — a turn that ends without a reply tool call leaves the user with no response. When you reply, use the reply tool's quote-reply field (reply_to) to reference the message you are answering, especially when answering an earlier message or when several messages have stacked up.
+TXT
+  te REPLY_REMINDER_SEEDED "$(tilde "$REPLY_REMINDER_FILE")"
+}
+
 # 모드 유효성 검사
 valid_mode() { case " $VALID_MODES " in *" $1 "*) return 0;; *) return 1;; esac; }
 # detached 세션 폭 유효성 검사: 양의 정수이고 하한(20) 이상.
```
