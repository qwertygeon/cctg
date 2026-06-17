---
작성: Docs Agent
버전: v1.0
최종 수정: 2026-06-17
상태: 확정
---

# Diff: 001-cli-convenience-patches

## 커밋 메시지용 한 줄 요약

- **KO**: [feat] config cwd/token 사후 변경·자동완성 보강·예약어 런타임(telegram/discord) 지원 (v0.5.0)
- **EN**: [feat] add config cwd/token post-registration edits, completion improvements, and reserved-name runtime (v0.5.0)

## 변경 요약

- **그룹 A (사후 변경)**: `cctg config <name> cwd <path>` — 레지스트리 cwd 원자적 갱신 (`set_registry_cwd()` 신규, awk+mktemp+mv). `cctg config <name> token` — .env 재작성 (채널 descriptor token_key 기반, 권한 600, 토큰 입력 방식 동일).
- **그룹 B (자동완성 보강)**: zsh(`_cctg`) + bash(`cctg.bash`) 양쪽에 `config mode` 값 6종 완성, config 액션 목록에 `cwd`·`token` 추가, 모든 서브커맨드에 `--help` 플래그 추가. `sub_usage()` 함수 신규(`lib/util.sh`) + cc-tg.sh 선검사 블록.
- **그룹 C (예약어 런타임)**: `cmd_up/down/restart/status/logs` 에 `is_reserved_name` 분기 추가. `up_reserved()`·`down_reserved()`·`reserved_runner_alive()` 신규(`lib/session.sh`). 단독소유자 가드(cctg-\<ch\> tmux 세션 OR bot.pid 생존). cwd = $PWD(DEC-001). `status` 출력에 전역 봇 섹션 추가. `down_reserved()` 는 tmux 세션만 종료(bot.pid 러너 비종료 — NFR-003).
- **i18n**: `messages/en.sh`·`messages/ko.sh` 에 33개 신규 키 추가(en/ko 패리티 유지, 총 154키).

## 변경 파일 및 라인 수

| 파일 | 추가 | 삭제 |
|---|---|---|
| cc-tg.sh | +10 | 0 |
| completions/_cctg | +20 | -7 |
| completions/cctg.bash | +16 | -5 |
| lib/commands.sh | +75 | 0 |
| lib/registry.sh | +21 | 0 |
| lib/session.sh | +55 | 0 |
| lib/util.sh | +24 | 0 |
| messages/en.sh | +33 | 0 |
| messages/ko.sh | +33 | 0 |
| **합계** | **+287** | **-12** |

## Diff

```diff
diff --git a/cc-tg.sh b/cc-tg.sh
index 4c3e13f..4130b15 100755
--- a/cc-tg.sh
+++ b/cc-tg.sh
@@ -80,6 +80,16 @@ mkdir -p "$CHANNELS_DIR"
 
 CMD="${1:-}"
 shift || true
+
+# 서브커맨드 --help/-h 선검사: 인자 중 --help/-h 가 있으면 해당 sub_usage 출력 후 exit 0 (ADR-005).
+# top-level `cctg --help` (CMD=""/"help") 는 아래 case 의 help 분기가 처리하므로 충돌 없음.
+case "$CMD" in
+  add|rm|rename|config|common|up|down|restart|status|logs|attach|lang|doctor|update|version|help)
+    for _a in "$@"; do
+      case "$_a" in --help|-h) sub_usage "$CMD"; exit 0 ;; esac
+    done ;;
+esac
+
 case "$CMD" in
   add)                  cmd_add "$@" ;;
   rm)                   cmd_rm "$@" ;;
diff --git a/completions/_cctg b/completions/_cctg
index 176afa9..2d3c1a0 100644
--- a/completions/_cctg
+++ b/completions/_cctg
@@ -40,29 +40,36 @@ _cctg() {
   case "${words[2]}" in
     rm)
       (( CURRENT == 3 )) && _cctg_names
-      (( CURRENT >= 4 )) && compadd -- --purge ;;
+      (( CURRENT >= 4 )) && compadd -- --purge --help ;;
     logs|attach)
-      (( CURRENT == 3 )) && _cctg_names ;;
+      (( CURRENT == 3 )) && _cctg_names
+      (( CURRENT == 3 )) || compadd -- --help ;;
     rename)
       # 3번째 인자(old)만 보완. 4번째(new name)는 자유 입력. 5번째 이후 --keep-dir.
       (( CURRENT == 3 )) && _cctg_names
-      (( CURRENT >= 5 )) && compadd -- --keep-dir ;;
+      (( CURRENT >= 5 )) && compadd -- --keep-dir --help ;;
     up|down|restart)
       if (( CURRENT == 3 )); then
-        compadd -- all
+        compadd -- all --help
         _cctg_names
       fi ;;
     config)
-      # config <name> <action> — 3번째=봇명, 4번째=동작
+      # config <name> <action> — 3번째=봇명, 4번째=동작, 5번째=값(mode のみ)
       if (( CURRENT == 3 )); then
         _cctg_names
       elif (( CURRENT == 4 )); then
-        compadd -- show edit mode args snapshot
+        compadd -- show edit mode args snapshot cwd token --help
+      elif (( CURRENT == 5 )); then
+        case "${words[4]}" in
+          mode) compadd -- acceptEdits auto bypassPermissions default dontAsk plan clear ;;
+          cwd)  _files -/ ;;
+          token) compadd -- --token-env --token-stdin --help ;;
+        esac
       fi ;;
     common)
       # common <action> [...]
       if (( CURRENT == 3 )); then
-        compadd -- show edit mode deny allow
+        compadd -- show edit mode deny allow --help
       elif (( CURRENT == 4 )); then
         case "${words[3]}" in
           deny|allow) compadd -- add rm ;;
@@ -80,13 +87,13 @@ _cctg() {
           --channel)   compadd -- ${=CCTG_COMPLETION_CHANNELS} ;;
           --id)        ;; # 자유 입력(숫자)
           --group)     ;; # 자유 입력(컴파운드 토큰 <id>[:nomention][:allow=...])
-          *)           compadd -- --id --token-env --token-stdin --mode --channel --group ;;
+          *)           compadd -- --id --token-env --token-stdin --mode --channel --group --help ;;
         esac
       fi ;;
     status)
-      (( CURRENT == 3 )) && compadd -- --json ;;
+      (( CURRENT == 3 )) && compadd -- --json --help ;;
     lang)
-      (( CURRENT == 3 )) && compadd -- show en ko clear ;;
+      (( CURRENT == 3 )) && compadd -- show en ko clear --help ;;
   esac
 }
 
diff --git a/completions/cctg.bash b/completions/cctg.bash
index 1349375..4bfe305 100644
--- a/completions/cctg.bash
+++ b/completions/cctg.bash
@@ -27,17 +27,24 @@ _cctg() {
         case "$cmd" in up|down|restart) extra="all" ;; *) extra="" ;; esac
         COMPREPLY=( $(compgen -W "$names $extra" -- "$cur") )
       elif [ "$cmd" = config ] && [ "$COMP_CWORD" -eq 3 ]; then
-        COMPREPLY=( $(compgen -W "show edit mode args snapshot" -- "$cur") )
+        COMPREPLY=( $(compgen -W "show edit mode args snapshot cwd token --help" -- "$cur") )
+      elif [ "$cmd" = config ] && [ "$COMP_CWORD" -eq 4 ]; then
+        case "${COMP_WORDS[3]}" in
+          mode)  COMPREPLY=( $(compgen -W "acceptEdits auto bypassPermissions default dontAsk plan clear" -- "$cur") ) ;;
+          token) COMPREPLY=( $(compgen -W "--token-env --token-stdin --help" -- "$cur") ) ;;
+        esac
       elif [ "$cmd" = rm ] && [ "$COMP_CWORD" -ge 3 ]; then
-        COMPREPLY=( $(compgen -W "--purge" -- "$cur") )
+        COMPREPLY=( $(compgen -W "--purge --help" -- "$cur") )
       elif [ "$cmd" = rename ] && [ "$COMP_CWORD" -ge 4 ]; then
-        COMPREPLY=( $(compgen -W "--keep-dir" -- "$cur") )
+        COMPREPLY=( $(compgen -W "--keep-dir --help" -- "$cur") )
+      elif [ "$cmd" = up ] || [ "$cmd" = down ] || [ "$cmd" = restart ] || [ "$cmd" = logs ] || [ "$cmd" = attach ]; then
+        [ "$COMP_CWORD" -ge 3 ] && COMPREPLY=( $(compgen -W "--help" -- "$cur") )
       fi
       ;;
     common)
       # common <action> [...]
       if [ "$COMP_CWORD" -eq 2 ]; then
-        COMPREPLY=( $(compgen -W "show edit mode deny allow" -- "$cur") )
+        COMPREPLY=( $(compgen -W "show edit mode deny allow --help" -- "$cur") )
       elif [ "$COMP_CWORD" -eq 3 ]; then
         case "${COMP_WORDS[2]}" in
           deny|allow) COMPREPLY=( $(compgen -W "add rm" -- "$cur") ) ;;
@@ -56,20 +63,20 @@ _cctg() {
           --channel)   COMPREPLY=( $(compgen -W "$channels" -- "$cur") ) ;;
           --id)        ;; # 자유 입력(숫자)
           --group)     ;; # 자유 입력(컴파운드 토큰 <id>[:nomention][:allow=...])
-          *)           COMPREPLY=( $(compgen -W "--id --token-env --token-stdin --mode --channel --group" -- "$cur") ) ;;
+          *)           COMPREPLY=( $(compgen -W "--id --token-env --token-stdin --mode --channel --group --help" -- "$cur") ) ;;
         esac
       fi
       ;;
     status)
       # status [--json]
       if [ "$COMP_CWORD" -eq 2 ]; then
-        COMPREPLY=( $(compgen -W "--json" -- "$cur") )
+        COMPREPLY=( $(compgen -W "--json --help" -- "$cur") )
       fi
       ;;
     lang)
       # lang [show|en|ko|clear]
       if [ "$COMP_CWORD" -eq 2 ]; then
-        COMPREPLY=( $(compgen -W "show en ko clear" -- "$cur") )
+        COMPREPLY=( $(compgen -W "show en ko clear --help" -- "$cur") )
       fi
       ;;
   esac
diff --git a/lib/commands.sh b/lib/commands.sh
index f5c1cd8..160db3e 100644
--- a/lib/commands.sh
+++ b/lib/commands.sh
@@ -291,6 +291,35 @@ ENV
           t CFG_SNAPSHOT_SET "$NAME" "$S"
         fi
         if is_running "$NAME"; then t APPLY_RESTART "$PROG" "$NAME"; fi ;;
+      cwd)
+        NEWCWD="${3-}"
+        [ -z "$NEWCWD" ] && die ERR_CONFIG_CWD_USAGE "$PROG" "$NAME"
+        NEWCWD="$(expand "$NEWCWD")"
+        [ -d "$NEWCWD" ] || die ERR_NO_SUCH_DIR "$NEWCWD"
+        set_registry_cwd "$NAME" "$NEWCWD" || die ERR_REGISTRY_UPDATE "$NAME"
+        t CFG_CWD_SET "$NAME" "$NEWCWD"
+        if is_running "$NAME"; then t APPLY_RESTART "$PROG" "$NAME"; fi ;;
+      token)
+        # $3 이후를 플래그로 파싱: --token-env <VAR> | --token-stdin (argv 토큰 직접 전달 금지 — P-003)
+        shift 2
+        local t_env="" t_stdin=0 NEWTOK
+        while [ $# -gt 0 ]; do
+          case "$1" in
+            --token-env)   [ $# -ge 2 ] || die ERR_ADD_FLAG_VALUE "--token-env"; t_env="$2"; shift 2 ;;
+            --token-stdin) t_stdin=1; shift ;;
+            *)             die ERR_CONFIG_TOKEN_USAGE "$PROG" "$NAME" ;;
+          esac
+        done
+        if [ "$t_stdin" = 1 ]; then IFS= read -r NEWTOK || true
+        elif [ -n "$t_env" ]; then
+          printf '%s' "$t_env" | grep -qE '^[A-Za-z_][A-Za-z0-9_]*$' || die ERR_ADD_BAD_ENVNAME "$t_env"
+          NEWTOK="${!t_env-}"
+        else t ADD_PROMPT_TOKEN; read -rs NEWTOK; echo; fi
+        [ -z "$NEWTOK" ] && die ERR_EMPTY_TOKEN
+        local tk; tk="$(channel_spec "$(channel_of "$NAME")" token_key)"
+        printf '%s=%s\n' "$tk" "$NEWTOK" > "$sd/.env" && chmod 600 "$sd/.env"
+        t CFG_TOKEN_SET "$NAME"
+        if is_running "$NAME"; then t APPLY_RESTART "$PROG" "$NAME"; fi ;;
       *)
         te ERR_CONFIG_UNKNOWN "$ACTION"
         t CFG_USAGE "$PROG" >&2
@@ -336,6 +365,8 @@ cmd_common() {
 
 cmd_up() {
     TARGET="${1:?name|all 필요}"
+    # 예약어(telegram/discord)는 레지스트리 없는 전용 경로로 라우팅(ADR-006)
+    if is_reserved_name "$TARGET"; then up_reserved "$TARGET"; return; fi
     if [ "$TARGET" = "all" ]; then
       while IFS= read -r n; do [ -n "$n" ] && up_one "$n"; done < <(all_names)
     else
@@ -345,6 +376,7 @@ cmd_up() {
 
 cmd_down() {
     TARGET="${1:?name|all 필요}"
+    if is_reserved_name "$TARGET"; then down_reserved "$TARGET"; return; fi
     if [ "$TARGET" = "all" ]; then
       while IFS= read -r n; do [ -n "$n" ] && down_one "$n"; done < <(all_names)
     else
@@ -354,6 +386,7 @@ cmd_down() {
 
 cmd_restart() {
     TARGET="${1:?name|all 필요}"
+    if is_reserved_name "$TARGET"; then down_reserved "$TARGET"; up_reserved "$TARGET"; return; fi
     if [ "$TARGET" = "all" ]; then
       while IFS= read -r n; do [ -n "$n" ] && { down_one "$n"; up_one "$n"; }; done < <(all_names)
     else
@@ -410,6 +443,34 @@ cmd_status() {
       fi
     done < <(all_names)
     if [ "$found" = 0 ]; then t STATUS_NONE; fi
+
+    # 예약어 전역 봇 섹션: channel_spec 정의 + $CHANNELS_DIR/<ch> 존재 항목만 표시(ADR-010)
+    local ch_found=0
+    for ch in $RESERVED_NAMES; do
+      channel_spec "$ch" plugin >/dev/null 2>&1 || continue
+      sd="$CHANNELS_DIR/$ch"; [ -d "$sd" ] || continue
+      if [ "$ch_found" = 0 ]; then t STATUS_RESERVED_HEADER; ch_found=1; fi
+      cwd="$PWD"   # DEC-001: 상태 표시용 — 전역 봇은 레지스트리에 cwd 없음
+      issues=""
+      [ -f "$sd/.env" ] || issues="$(t ISSUE_NO_TOKEN)"
+      if is_running "$ch"; then
+        created="$(tmux display-message -p -t "$(sess_of "$ch")" '#{session_created}' 2>/dev/null)"
+        up=""
+        if printf '%s' "$created" | grep -qE '^[0-9]+$'; then
+          up="$(t STATUS_UPTIME "$(fmt_dur $(( $(date +%s) - created )))")"
+        fi
+        t STATUS_RUNNING "$ch" "$up" "$(sess_of "$ch")"
+      elif [ -n "$issues" ]; then
+        t STATUS_BROKEN "$ch" "$issues"
+        [ -f "$sd/.env" ] || t STATUS_HINT_NO_TOKEN "$sd" "$PROG" "$ch" "$(channel_spec "$ch" token_key)"
+      else
+        t STATUS_STOPPED "$ch"
+      fi
+      pm="$(mode_of "$sd")"; [ -z "$pm" ] && pm="$(t SHARED_WORD)"
+      t STATUS_PATHS "$cwd" "$sd"
+      t STATUS_MODE "$pm"
+      t STATUS_CHANNEL "$(channel_spec "$ch" display)"
+    done
 }
 
 # status --json: 기계 판독용 봇 상태 배열. 출력은 순수 JSON(사람용 헤더 없음)이며 로케일 무관 토큰 사용.
@@ -450,6 +511,20 @@ status_json() {
 
 cmd_logs() {
     NAME="${1:?name 필요}"; N="${2:-50}"
+    # 예약어: 전역 봇 디렉터리에서 조회 (레지스트리 lookup 불필요)
+    if is_reserved_name "$NAME"; then
+      if is_running "$NAME"; then
+        tmux capture-pane -p -S -2000 -t "$(sess_of "$NAME")" | tail -n "$N"
+        return
+      fi
+      local snap="$CHANNELS_DIR/$NAME/last-session.log"
+      if [ -f "$snap" ]; then
+        t LOGS_SNAPSHOT "$NAME"
+        tail -n "$N" "$snap"
+        return
+      fi
+      die LOGS_STOPPED "$NAME" "$PROG" "$NAME"
+    fi
     if is_running "$NAME"; then
       tmux capture-pane -p -S -2000 -t "$(sess_of "$NAME")" | tail -n "$N"
       return
diff --git a/lib/registry.sh b/lib/registry.sh
index 534fa22..c5e3e82 100644
--- a/lib/registry.sh
+++ b/lib/registry.sh
@@ -43,6 +43,27 @@ rename_registry_line() {
   ' "$REGISTRY" > "$tmp" && mv "$tmp" "$REGISTRY"
 }
 
+# 레지스트리에서 name 줄의 2번 컬럼(cwd)을 갱신.
+# 이름(1번)·상태디렉터리(3번)·채널(4번)은 보존. 주석·빈 줄도 보존.
+set_registry_cwd() {
+  local name="$1" newcwd="$2" tmp
+  tmp="$(mktemp)" || return 1
+  awk -F'|' -v n="$name" -v nc="$newcwd" -v dc="$DEFAULT_CHANNEL" '
+    /^[[:space:]]*#/ {print; next}
+    /^[[:space:]]*$/ {print; next}
+    {
+      c1=$1; gsub(/^[ \t]+|[ \t]+$/,"",c1)
+      if (c1==n) {
+        c3=$3; gsub(/^[ \t]+|[ \t]+$/,"",c3)
+        c4=$4; gsub(/^[ \t]+|[ \t]+$/,"",c4); if (c4=="") c4=dc
+        printf "%s | %s | %s | %s\n", c1, nc, c3, c4
+        next
+      }
+      print
+    }
+  ' "$REGISTRY" > "$tmp" && mv "$tmp" "$REGISTRY"
+}
+
 # 선행 ~ 확장
 expand() { case "$1" in "~"*) printf '%s' "${HOME}${1#\~}";; *) printf '%s' "$1";; esac; }
 
diff --git a/lib/session.sh b/lib/session.sh
index 18b939b..e9e37d0 100644
--- a/lib/session.sh
+++ b/lib/session.sh
@@ -119,3 +119,58 @@ down_one() {
     t DOWN_STOPPED "$name"
   fi
 }
+
+# bot.pid 가 존재하고 PID 가 살아 있으면 true. stale(파일 있어도 PID 없음) 이면 false.
+reserved_runner_alive() {
+  local pidf="$1/bot.pid" pid
+  [ -f "$pidf" ] || return 1
+  pid="$(head -n1 "$pidf" 2>/dev/null)"
+  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
+}
+
+# 예약어 채널 전역 봇 기동. lookup 없이 고정 좌표($PWD / $CHANNELS_DIR/<ch>) 사용.
+up_reserved() {
+  local ch="$1" sd cwd
+  # imessage/fakechat 등 channel_spec 미정의 채널은 미지원(ADR-010).
+  channel_spec "$ch" plugin >/dev/null 2>&1 || { te ERR_RESERVED_UNSUPPORTED "$ch"; return 1; }
+  sd="$CHANNELS_DIR/$ch"
+  cwd="$PWD"                                                            # DEC-001: cctg 호출 시점 현재 작업 디렉터리
+  [ -d "$cwd" ] || { te ERR_NO_CWD "$cwd"; return 1; }                 # up_one 과 동형 가드
+  [ -f "$sd/.env" ] || { te ERR_NO_TOKEN "$sd/.env"; return 1; }       # SC-017
+  # 단독소유자 가드: cctg-<ch> tmux 세션 OR bot.pid 생존 (ADR-007)
+  if is_running "$ch"; then te ERR_RESERVED_UP_OCCUPIED "$ch"; return 1; fi
+  if reserved_runner_alive "$sd"; then te ERR_RESERVED_UP_RUNNER "$ch"; return 1; fi
+
+  ensure_shared_settings
+  local shared_arg=""
+  [ -f "$SHARED_SETTINGS" ] && shared_arg="--settings $(printf '%q' "$SHARED_SETTINGS")"
+
+  local sd_env plugin
+  sd_env="$(channel_spec "$ch" statedir_env)"
+  plugin="$(channel_spec "$ch" plugin)"
+  local launch
+  launch="cd $(printf '%q' "$cwd") \
+&& export ${sd_env}=$(printf '%q' "$sd") \
+&& set -a && source $(printf '%q' "$sd/.env") \
+&& { [ -f $(printf '%q' "$sd/launch.env") ] && source $(printf '%q' "$sd/launch.env") || true; } \
+&& set +a \
+&& MODE_ARG=\"\" \
+&& { [ -n \"\${CCTG_PERMISSION_MODE:-}\" ] && MODE_ARG=\"--permission-mode \${CCTG_PERMISSION_MODE}\" || true; } \
+&& caffeinate -is claude --channels $plugin $shared_arg \${MODE_ARG} \${CLAUDE_EXTRA_ARGS:-}; exec bash"
+
+  tmux new-session -d -s "$(sess_of "$ch")" bash -lc "$launch"
+  t RESERVED_UP "$ch" "$(sess_of "$ch")"
+}
+
+# 예약어 채널 전역 봇 정지. cctg 가 기동한 tmux 세션만 kill (ADR-008).
+# bot.pid 러너는 종료하지 않음(NFR-003 — cctg 관리 범위 외).
+# stop_snapshotter/take_snapshot 미호출(전역 봇에는 cctg launch.env·watcher 없음, P-002).
+down_reserved() {
+  local ch="$1"
+  if is_running "$ch"; then
+    tmux kill-session -t "$(sess_of "$ch")"
+    t DOWN_OK "$ch"
+  else
+    t RESERVED_DOWN_NONE "$ch"
+  fi
+}
diff --git a/lib/util.sh b/lib/util.sh
index e742a6b..73e72e5 100644
--- a/lib/util.sh
+++ b/lib/util.sh
@@ -53,5 +53,29 @@ jq_inplace() {
 }
 
 usage() { t USAGE "$PROG"; }
+
+# 서브커맨드별 1행 사용법 출력(FR-005 / ADR-005). cc-tg.sh 에서 --help/-h 선검사 시 호출.
+sub_usage() {
+  case "$1" in
+    add)     t USAGE_ADD     "$PROG" ;;
+    rm)      t USAGE_RM      "$PROG" ;;
+    rename)  t USAGE_RENAME  "$PROG" ;;
+    config)  t USAGE_CONFIG  "$PROG" ;;
+    common)  t USAGE_COMMON  "$PROG" ;;
+    up)      t USAGE_UP      "$PROG" ;;
+    down)    t USAGE_DOWN    "$PROG" ;;
+    restart) t USAGE_RESTART "$PROG" ;;
+    status)  t USAGE_STATUS  "$PROG" ;;
+    logs)    t USAGE_LOGS    "$PROG" ;;
+    attach)  t USAGE_ATTACH  "$PROG" ;;
+    lang)    t USAGE_LANG    "$PROG" ;;
+    doctor)  t USAGE_DOCTOR  "$PROG" ;;
+    update)  t USAGE_UPDATE  "$PROG" ;;
+    version) t USAGE_VERSION "$PROG" ;;
+    help)    t USAGE_HELP    "$PROG" ;;
+    *)       usage ;;
+  esac
+}
+
 # 봇 이름 검증 — tmux 세션명·레지스트리(|) 충돌 방지를 위해 영숫자/_/- 만 허용
 valid_name() { printf '%s' "$1" | grep -qE '^[A-Za-z0-9_-]+$'; }
diff --git a/messages/en.sh b/messages/en.sh
index 9a745eb..ea072b5 100644
--- a/messages/en.sh
+++ b/messages/en.sh
@@ -151,6 +151,39 @@ CCTG_MSG_DOCTOR_NOJQ="  (no jq — check with 'cctg common show')\n"
 CCTG_MSG_DOCTOR_SHARED_NONE="  (none yet — created on first add/up)\n"
 CCTG_MSG_DOCTOR_PLUGIN_HINT="  (the channel plugins must be installed globally, e.g. /plugin install <channel>@claude-plugins-official for: %s)\n"
 
+# config cwd / token (신규 — FR-001/002)
+CCTG_MSG_ERR_CONFIG_CWD_USAGE="Usage: %s config %s cwd <path>\n"
+CCTG_MSG_ERR_NO_SUCH_DIR="ERROR: no such directory: %s\n"
+CCTG_MSG_CFG_CWD_SET="%s cwd: %s\n"
+CCTG_MSG_ERR_CONFIG_TOKEN_USAGE="Usage: %s config %s token [--token-env VAR|--token-stdin]\n"
+CCTG_MSG_CFG_TOKEN_SET="%s token updated.\n"
+
+# reserved runtime (신규 — FR-006/007/009)
+CCTG_MSG_RESERVED_UP="UP %s (global bot, tmux=%s)\n"
+CCTG_MSG_ERR_RESERVED_UP_OCCUPIED="ERROR: already running: %s\n"
+CCTG_MSG_ERR_RESERVED_UP_RUNNER="ERROR: global bot plugin runner active (bot.pid): %s\n"
+CCTG_MSG_ERR_RESERVED_UNSUPPORTED="ERROR: reserved runtime not supported for channel: %s\n"
+CCTG_MSG_RESERVED_DOWN_NONE="No session: %s. Only tmux sessions started by cctg can be stopped — plugin runner (bot.pid) is not managed by cctg (NFR-003 limit).\n"
+CCTG_MSG_STATUS_RESERVED_HEADER="--- global channel bots ---\n"
+
+# sub-command usage (신규 — FR-005, 16개 서브커맨드)
+CCTG_MSG_USAGE_ADD="Usage: %s add <name> <cwd> [--id <num>] [--token-env <VAR>|--token-stdin] [--mode <m>] [--channel <ch>] [--group <id>[:nomention][:allow=ids]]\n"
+CCTG_MSG_USAGE_RM="Usage: %s rm <name> [--purge]\n"
+CCTG_MSG_USAGE_RENAME="Usage: %s rename <old> <new> [--keep-dir]\n"
+CCTG_MSG_USAGE_CONFIG="Usage: %s config <name> [show | edit | mode <mode|clear> | args <string> | snapshot <seconds|off> | cwd <path> | token [--token-env VAR|--token-stdin]]\n"
+CCTG_MSG_USAGE_COMMON="Usage: %s common [show | edit | mode <mode> | deny add|rm <rule> | allow add|rm <rule>]\n"
+CCTG_MSG_USAGE_UP="Usage: %s up <name|all>\n"
+CCTG_MSG_USAGE_DOWN="Usage: %s down <name|all>\n"
+CCTG_MSG_USAGE_RESTART="Usage: %s restart <name|all>\n"
+CCTG_MSG_USAGE_STATUS="Usage: %s status [--json]\n"
+CCTG_MSG_USAGE_LOGS="Usage: %s logs <name> [N]\n"
+CCTG_MSG_USAGE_ATTACH="Usage: %s attach <name>\n"
+CCTG_MSG_USAGE_LANG="Usage: %s lang [show | en | ko | clear]\n"
+CCTG_MSG_USAGE_DOCTOR="Usage: %s doctor\n"
+CCTG_MSG_USAGE_UPDATE="Usage: %s update\n"
+CCTG_MSG_USAGE_VERSION="Usage: %s version\n"
+CCTG_MSG_USAGE_HELP="Usage: %s help\n"
+
 # version / dispatcher
 CCTG_MSG_VERSION_LINE="%s %s\n"
 CCTG_MSG_ERR_UNKNOWN_CMD="ERROR: unknown command: %s\n"
diff --git a/messages/ko.sh b/messages/ko.sh
index 904d933..1135ddc 100644
--- a/messages/ko.sh
+++ b/messages/ko.sh
@@ -150,6 +150,39 @@ CCTG_MSG_DOCTOR_NOJQ="  (jq 없음 — 'cctg common show' 로 확인)\n"
 CCTG_MSG_DOCTOR_SHARED_NONE="  (아직 없음 — 첫 add/up 시 생성)\n"
 CCTG_MSG_DOCTOR_PLUGIN_HINT="  (채널 플러그인은 전역 설치 필요, 예: /plugin install <channel>@claude-plugins-official — 대상: %s)\n"
 
+# config cwd / token (신규 — FR-001/002)
+CCTG_MSG_ERR_CONFIG_CWD_USAGE="사용법: %s config %s cwd <경로>\n"
+CCTG_MSG_ERR_NO_SUCH_DIR="ERROR: 디렉터리 없음: %s\n"
+CCTG_MSG_CFG_CWD_SET="%s cwd: %s\n"
+CCTG_MSG_ERR_CONFIG_TOKEN_USAGE="사용법: %s config %s token [--token-env VAR|--token-stdin]\n"
+CCTG_MSG_CFG_TOKEN_SET="%s 토큰 갱신됨.\n"
+
+# reserved runtime (신규 — FR-006/007/009)
+CCTG_MSG_RESERVED_UP="UP %s (전역 봇, tmux=%s)\n"
+CCTG_MSG_ERR_RESERVED_UP_OCCUPIED="ERROR: 이미 실행 중: %s\n"
+CCTG_MSG_ERR_RESERVED_UP_RUNNER="ERROR: 전역 봇 플러그인 러너 실행 중 (bot.pid): %s\n"
+CCTG_MSG_ERR_RESERVED_UNSUPPORTED="ERROR: 예약어 런타임 미지원 채널: %s\n"
+CCTG_MSG_RESERVED_DOWN_NONE="%s 세션 없음. cctg 가 시작한 tmux 세션만 중지 가능 — 플러그인 러너(bot.pid)는 cctg 가 관리하지 않습니다 (NFR-003 한계).\n"
+CCTG_MSG_STATUS_RESERVED_HEADER="--- 전역 채널 봇 ---\n"
+
+# sub-command usage (신규 — FR-005, 16개 서브커맨드)
+CCTG_MSG_USAGE_ADD="사용법: %s add <이름> <cwd> [--id <번호>] [--token-env <VAR>|--token-stdin] [--mode <m>] [--channel <ch>] [--group <id>[:nomention][:allow=ids]]\n"
+CCTG_MSG_USAGE_RM="사용법: %s rm <이름> [--purge]\n"
+CCTG_MSG_USAGE_RENAME="사용법: %s rename <이전> <새이름> [--keep-dir]\n"
+CCTG_MSG_USAGE_CONFIG="사용법: %s config <이름> [show | edit | mode <모드|clear> | args <문자열> | snapshot <초|off> | cwd <경로> | token [--token-env VAR|--token-stdin]]\n"
+CCTG_MSG_USAGE_COMMON="사용법: %s common [show | edit | mode <모드> | deny add|rm <규칙> | allow add|rm <규칙>]\n"
+CCTG_MSG_USAGE_UP="사용법: %s up <이름|all>\n"
+CCTG_MSG_USAGE_DOWN="사용법: %s down <이름|all>\n"
+CCTG_MSG_USAGE_RESTART="사용법: %s restart <이름|all>\n"
+CCTG_MSG_USAGE_STATUS="사용법: %s status [--json]\n"
+CCTG_MSG_USAGE_LOGS="사용법: %s logs <이름> [N]\n"
+CCTG_MSG_USAGE_ATTACH="사용법: %s attach <이름>\n"
+CCTG_MSG_USAGE_LANG="사용법: %s lang [show | en | ko | clear]\n"
+CCTG_MSG_USAGE_DOCTOR="사용법: %s doctor\n"
+CCTG_MSG_USAGE_UPDATE="사용법: %s update\n"
+CCTG_MSG_USAGE_VERSION="사용법: %s version\n"
+CCTG_MSG_USAGE_HELP="사용법: %s help\n"
+
 # version / 디스패처
 CCTG_MSG_VERSION_LINE="%s %s\n"
 CCTG_MSG_ERR_UNKNOWN_CMD="ERROR: 알 수 없는 명령: %s\n"
```
