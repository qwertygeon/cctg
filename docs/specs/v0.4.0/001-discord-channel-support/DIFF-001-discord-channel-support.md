---
작성: Docs Agent
버전: v1.0
최종 수정: 2026-06-17 18:05
상태: 확정
---

# Diff: 001-discord-channel-support

## 커밋 메시지용 한 줄 요약

- **KO**: Discord 채널 활성화 — descriptor 8필드화·`add --channel discord`·`--group` 서버채널 시드·status 채널 토폴로지 표시·telegram 하드코딩 제거
- **EN**: Activate Discord channel — 8-field descriptor, `add --channel discord`, `--group` server-channel seeding, status channel topology, and removal of telegram hardcoding

## 변경 요약

- **descriptor (lib/channels.sh)**: `IMPLEMENTED_CHANNELS="telegram discord"`, discord descriptor 8필드 활성화(display=Discord, id_label=Discord user snowflake, id_required=no, seed_policy=pairing), telegram 신규 4필드(display/id_label/id_required/seed_policy) 추가. (FR-001, FR-002)
- **add 로직 (lib/commands.sh, cmd_add)**: 채널 `id_required` 분기(discord 는 `--id` 없이 진행), `seed_policy` 기반 `access.json` 시드(pairing/allowlist), `"pending"` 필드 전 채널 제거, `--group <id>[:nomention][:allow=m1,m2]` 컴파운드 토큰(DEC-001) 파싱·검증·시드. (FR-003, FR-004, FR-008)
- **status 로직 (lib/commands.sh, cmd_status)**: 봇별 채널 표시명(display) + jq 토폴로지(`dmPolicy`, groups 수) 출력, jq 부재 시 graceful degradation. (FR-007, NFR-005)
- **메시지 (messages/en.sh, messages/ko.sh)**: ADD_PROMPT_TGID/STATUS_GLOBAL/STATUS_HINT_NO_TOKEN/DOCTOR_PLUGIN_HINT 의 telegram 하드코딩 제거(descriptor 경유 동적화), 신규 키(ADD_DONE_PAIRING, ERR_ADD_BAD_GROUP_ID, ERR_ADD_BAD_GROUP_MEMBER, STATUS_CHANNEL, STATUS_CHANNEL_TOPO) 추가. (FR-005)
- **자동완성 (completions/_cctg, completions/cctg.bash)**: `--channel` 후보를 `IMPLEMENTED_CHANNELS` 미러 변수 기반으로 동적화, add 플래그에 `--group` 추가. (FR-006, FR-008)
- **테스트 (tests/add.bats, tests/channel.bats, tests/static.bats 신규, tests/status_view.bats 신규)**: SC-001~032 매핑 테스트 + 회귀. bats 119/119 PASS. (5a/5b)

## 변경 파일 및 라인 수

> baseCommit 3480eb1 대비. `tests/static.bats`·`tests/status_view.bats` 는 신규(untracked) 파일이라 `git diff` 미포함 — 전문 추가로 표기.

| 파일 | 추가 | 삭제 |
|---|---|---|
| lib/channels.sh | +15 | -7 |
| lib/commands.sh | +88 | -13 |
| messages/en.sh | +10 | -5 |
| messages/ko.sh | +10 | -5 |
| completions/_cctg | +6 | -3 |
| completions/cctg.bash | +7 | -4 |
| tests/add.bats | +101 | -0 |
| tests/channel.bats | +50 | -2 |
| tests/static.bats (신규) | +102 | -0 |
| tests/status_view.bats (신규) | +50 | -0 |

## Diff

### Tracked 변경 (git diff 3480eb1)

```diff
diff --git a/completions/_cctg b/completions/_cctg
index ce99a57..176afa9 100644
--- a/completions/_cctg
+++ b/completions/_cctg
@@ -4,6 +4,8 @@
 
 _cctg() {
   local -a cmds
+  # lib/channels.sh IMPLEMENTED_CHANNELS 미러 — 채널 추가 시 함께 갱신(완성 파일은 lib 를 source 안 함).
+  local CCTG_COMPLETION_CHANNELS="telegram discord"
   cmds=(
     'add:프로젝트 봇 등록'
     'rm:등록 해제'
@@ -68,16 +70,17 @@ _cctg() {
         esac
       fi ;;
     add)
-      # add <name> <cwd> [--id <num>] [--token-env <VAR>|--token-stdin] [--mode <m>] [--channel <name>]
+      # add <name> <cwd> [--id <num>] [--token-env <VAR>|--token-stdin] [--mode <m>] [--channel <name>] [--group <id>[:nomention][:allow=m1,m2]]
       if (( CURRENT == 4 )); then
         _files -/
       elif (( CURRENT >= 5 )); then
         case "${words[CURRENT-1]}" in
           --mode)      compadd -- acceptEdits auto bypassPermissions default dontAsk plan ;;
           --token-env) compadd -- ${(k)parameters} ;;
-          --channel)   compadd -- telegram ;;
+          --channel)   compadd -- ${=CCTG_COMPLETION_CHANNELS} ;;
           --id)        ;; # 자유 입력(숫자)
-          *)           compadd -- --id --token-env --token-stdin --mode --channel ;;
+          --group)     ;; # 자유 입력(컴파운드 토큰 <id>[:nomention][:allow=...])
+          *)           compadd -- --id --token-env --token-stdin --mode --channel --group ;;
         esac
       fi ;;
     status)
diff --git a/completions/cctg.bash b/completions/cctg.bash
index 51bd1e4..1349375 100644
--- a/completions/cctg.bash
+++ b/completions/cctg.bash
@@ -3,11 +3,13 @@
 # macOS 기본 bash 3.2 호환을 위해 _init_completion 에 의존하지 않는다.
 
 _cctg() {
-  local cur prev cmd cmds names extra reg
+  local cur prev cmd cmds names extra reg channels
   cur="${COMP_WORDS[COMP_CWORD]}"
   prev="${COMP_WORDS[COMP_CWORD-1]}"
   cmds="add rm rename config common up down restart status logs attach lang doctor update version help"
   reg="${CC_TG_REGISTRY:-${CC_CHANNELS_DIR:-$HOME/.claude/channels}/projects.conf}"
+  # lib/channels.sh IMPLEMENTED_CHANNELS 미러 — 채널 추가 시 함께 갱신(완성 파일은 lib 를 source 안 함).
+  channels="telegram discord"
 
   # 첫 인자: 서브커맨드
   if [ "$COMP_CWORD" -eq 1 ]; then
@@ -44,16 +46,17 @@ _cctg() {
       fi
       ;;
     add)
-      # add <name> <cwd> [--id <num>] [--token-env <VAR>|--token-stdin] [--mode <m>] [--channel <name>]
+      # add <name> <cwd> [--id <num>] [--token-env <VAR>|--token-stdin] [--mode <m>] [--channel <name>] [--group <id>[:nomention][:allow=m1,m2]]
       if [ "$COMP_CWORD" -eq 3 ]; then
         COMPREPLY=( $(compgen -d -- "$cur") )
       elif [ "$COMP_CWORD" -ge 4 ]; then
         case "$prev" in
           --mode)      COMPREPLY=( $(compgen -W "acceptEdits auto bypassPermissions default dontAsk plan" -- "$cur") ) ;;
           --token-env) COMPREPLY=( $(compgen -A variable -- "$cur") ) ;;
-          --channel)   COMPREPLY=( $(compgen -W "telegram" -- "$cur") ) ;;
+          --channel)   COMPREPLY=( $(compgen -W "$channels" -- "$cur") ) ;;
           --id)        ;; # 자유 입력(숫자)
-          *)           COMPREPLY=( $(compgen -W "--id --token-env --token-stdin --mode --channel" -- "$cur") ) ;;
+          --group)     ;; # 자유 입력(컴파운드 토큰 <id>[:nomention][:allow=...])
+          *)           COMPREPLY=( $(compgen -W "--id --token-env --token-stdin --mode --channel --group" -- "$cur") ) ;;
         esac
       fi
       ;;
diff --git a/lib/channels.sh b/lib/channels.sh
index 9604fde..70055aa 100644
--- a/lib/channels.sh
+++ b/lib/channels.sh
@@ -7,22 +7,30 @@
 # 레지스트리 channel 컬럼이 비었을 때(레거시 3컬럼)의 기본 채널.
 DEFAULT_CHANNEL="telegram"
 # 실제 구현·검증되어 add 가 허용하는 채널 집합(공백 구분).
-# discord/imessage 는 plugin ID·토큰/접근 규약 검증 후 descriptor 추가 + 여기 등재.
-IMPLEMENTED_CHANNELS="telegram"
+# imessage 는 plugin ID·토큰/접근 규약 검증 후 descriptor 추가 + 여기 등재.
+IMPLEMENTED_CHANNELS="telegram discord"
 
 # channel_spec <channel> <field> → 값 출력(미정의 시 비-0 반환).
 #   field: plugin | statedir_env | token_key | token_required
+#          | display | id_label | id_required | seed_policy
 channel_spec() {
   case "$1:$2" in
     telegram:plugin)         printf 'plugin:telegram@claude-plugins-official' ;;
     telegram:statedir_env)   printf 'TELEGRAM_STATE_DIR' ;;
     telegram:token_key)      printf 'TELEGRAM_BOT_TOKEN' ;;
     telegram:token_required) printf 'yes' ;;
-    # 채널 추가 예시(미구현 — 식별자·규약 검증 후 활성화):
-    #   discord:plugin)        printf 'plugin:discord@claude-plugins-official' ;;
-    #   discord:statedir_env)  printf 'DISCORD_STATE_DIR' ;;
-    #   discord:token_key)     printf 'DISCORD_BOT_TOKEN' ;;
-    #   discord:token_required) printf 'yes' ;;
+    telegram:display)        printf 'Telegram' ;;
+    telegram:id_label)       printf 'Telegram numeric ID' ;;
+    telegram:id_required)    printf 'yes' ;;
+    telegram:seed_policy)    printf 'allowlist' ;;
+    discord:plugin)          printf 'plugin:discord@claude-plugins-official' ;;
+    discord:statedir_env)    printf 'DISCORD_STATE_DIR' ;;
+    discord:token_key)       printf 'DISCORD_BOT_TOKEN' ;;
+    discord:token_required)  printf 'yes' ;;
+    discord:display)         printf 'Discord' ;;
+    discord:id_label)        printf 'Discord user snowflake' ;;
+    discord:id_required)     printf 'no' ;;
+    discord:seed_policy)     printf 'pairing' ;;
     *) return 1 ;;
   esac
 }
diff --git a/lib/commands.sh b/lib/commands.sh
index 549f863..f5c1cd8 100644
--- a/lib/commands.sh
+++ b/lib/commands.sh
@@ -8,7 +8,10 @@ cmd_add() {
     # 비대화형 플래그 파싱. 토큰 플래그(--token-env/--token-stdin)가 있으면 비대화형 모드로 전환:
     # 그 경우 --id 가 필수이고, --mode 생략 시 공통 설정을 따른다(프롬프트 없음).
     # 토큰은 프로세스 목록 노출을 피하기 위해 argv 로 직접 받지 않는다(env 또는 stdin 경유).
-    local opt_id="" opt_token_env="" opt_token_stdin=0 opt_mode="" opt_channel="" noninteractive=0
+    # --group 컴파운드 토큰을 단일 스칼라에 누적한다(연관배열 미사용 — Bash 3.2). 토큰은 `:` 로
+    # 내부 분해하므로 토큰 간 구분자는 탭(토큰 자체엔 공백/탭 없음)을 쓴다.
+    local GROUP_SEP; GROUP_SEP="$(printf '\t')"
+    local opt_id="" opt_token_env="" opt_token_stdin=0 opt_mode="" opt_channel="" opt_groups="" noninteractive=0
     while [ $# -gt 0 ]; do
       case "$1" in
         --id)          [ $# -ge 2 ] || die ERR_ADD_FLAG_VALUE "--id";          opt_id="$2"; shift 2 ;;
@@ -16,6 +19,7 @@ cmd_add() {
         --token-stdin) opt_token_stdin=1; noninteractive=1; shift ;;
         --mode)        [ $# -ge 2 ] || die ERR_ADD_FLAG_VALUE "--mode";        opt_mode="$2"; shift 2 ;;
         --channel)     [ $# -ge 2 ] || die ERR_ADD_FLAG_VALUE "--channel";     opt_channel="$2"; shift 2 ;;
+        --group)       [ $# -ge 2 ] || die ERR_ADD_FLAG_VALUE "--group";       opt_groups="$opt_groups${opt_groups:+$GROUP_SEP}$2"; shift 2 ;;
         *)             die ERR_ADD_UNKNOWN_FLAG "$1" ;;
       esac
     done
@@ -46,26 +50,83 @@ cmd_add() {
     fi
     [ -z "$TOKEN" ] && die ERR_EMPTY_TOKEN
 
-    # 2) 본인 텔레그램 숫자 ID (allowlist 시드용) — 비대화형이면 --id 필수
+    # 2) 본인 채널 ID (allowlist 시드용). 채널 descriptor 의 id_required 로 분기한다.
+    #    id_required=yes(telegram): 비대화형이면 --id 필수, allowlist 시드.
+    #    id_required=no(discord): --id 생략 가능 — 비면 빈 ID 로 진행해 페어링 정책 시드.
     if [ -n "$opt_id" ]; then
       TGID="$opt_id"
-    elif [ "$noninteractive" = 1 ]; then
+    elif [ "$(channel_spec "$CH" id_required)" = yes ] && [ "$noninteractive" = 1 ]; then
       die ERR_ADD_NEED_ID
+    elif [ "$noninteractive" = 1 ]; then
+      TGID=""
     else
-      t ADD_PROMPT_TGID
+      t ADD_PROMPT_TGID "$(channel_spec "$CH" id_label)"
       read -r TGID
     fi
-    printf '%s' "$TGID" | grep -qE '^[0-9]+$' || die ERR_NOT_NUMERIC_ID "$TGID"
+    [ -n "$TGID" ] && { printf '%s' "$TGID" | grep -qE '^[0-9]+$' || die ERR_NOT_NUMERIC_ID "$TGID"; }
 
     # 3) 토큰 → .env (600). 키 이름은 채널 descriptor 에서(telegram=TELEGRAM_BOT_TOKEN).
     printf '%s=%s\n' "$(channel_spec "$CH" token_key)" "$TOKEN" > "$SD/.env"
     chmod 600 "$SD/.env"
 
-    # 4) access.json → allowlist 자동 생성 (페어링 불필요)
-    #    TGID는 위에서 숫자만 통과시켰으므로 JSON 주입 위험 없음
-    cat > "$SD/access.json" <<JSON
-{ "dmPolicy": "allowlist", "allowFrom": ["$TGID"], "groups": {}, "pending": {} }
+    # 4) access.json → 채널 시드 정책에 따라 생성.
+    #    dmPolicy/allowFrom 를 단일 가드로 동시 결정한다(동일 가드 중복 평가 제거):
+    #      ID 제공 → allowlist + [<id>] / 미제공 → 채널 seed_policy(예: discord=pairing) + []
+    #    TGID·group id·member id 는 모두 ^[0-9]+$ 통과분만 JSON 에 주입한다(P-003 주입 방어).
+    local sp policy af
+    sp="$(channel_spec "$CH" seed_policy)"
+    if [ -n "$TGID" ]; then policy=allowlist; af='["'"$TGID"'"]'; else policy="$sp"; af='[]'; fi
+
+    if [ -z "$opt_groups" ]; then
+      # groups 미지정: heredoc 으로 작성(jq 불요 — jq 없는 환경의 일반 add 동작 보존).
+      cat > "$SD/access.json" <<JSON
+{ "dmPolicy": "$policy", "allowFrom": $af, "groups": {} }
 JSON
+    else
+      # groups 지정: 가변 키 JSON 객체 구성을 위해 jq 사용. 검증·jq 가드는 레지스트리 등록 전(ADR-006)
+      # 에서 수행하므로 실패 시 봇은 미등록 상태로 남는다.
+      need_jq || exit 1
+      local groups_json gtok gid grest gmod rm_flag allow_csv allow_json gm first
+      groups_json='{}'
+      # 토큰을 줄 단위로 변환해(구분자=탭→개행) read 로 순회 — 루프 본문에서 IFS 를 자유롭게 바꾼다.
+      while IFS= read -r gtok; do
+        [ -z "$gtok" ] && continue
+        gid="${gtok%%:*}"; grest="${gtok#"$gid"}"
+        printf '%s' "$gid" | grep -qE '^[0-9]+$' || die ERR_ADD_BAD_GROUP_ID "$gid"
+        rm_flag=true; allow_csv=""
+        # 수식어(`:` 구분): nomention / allow=csv
+        local saved_ifs="$IFS"; IFS=':'
+        for gmod in $grest; do
+          case "$gmod" in
+            "")        : ;;
+            nomention) rm_flag=false ;;
+            allow=*)   allow_csv="${gmod#allow=}" ;;
+          esac
+        done
+        IFS="$saved_ifs"
+        allow_json='[]'
+        if [ -n "$allow_csv" ]; then
+          allow_json='['; first=1
+          saved_ifs="$IFS"; IFS=','
+          for gm in $allow_csv; do
+            IFS="$saved_ifs"
+            printf '%s' "$gm" | grep -qE '^[0-9]+$' || die ERR_ADD_BAD_GROUP_MEMBER "$gm"
+            [ "$first" = 1 ] && first=0 || allow_json="$allow_json,"
+            allow_json="$allow_json\"$gm\""
+            saved_ifs="$IFS"; IFS=','
+          done
+          IFS="$saved_ifs"
+          allow_json="$allow_json]"
+        fi
+        groups_json="$(printf '%s' "$groups_json" | jq -c \
+          --arg id "$gid" --argjson rm "$rm_flag" --argjson af "$allow_json" \
+          '. + {($id): {requireMention:$rm, allowFrom:$af}}')" || die ERR_ADD_BAD_GROUP_ID "$gid"
+      done <<EOF
+$(printf '%s' "$opt_groups" | tr "$GROUP_SEP" '\n')
+EOF
+      jq -n --arg dm "$policy" --argjson af "$af" --argjson gr "$groups_json" \
+        '{dmPolicy:$dm, allowFrom:$af, groups:$gr}' > "$SD/access.json"
+    fi
 
     # 4.5) 권한 모드 — 플래그(검증 완료) 우선, 비대화형이면 공통 따름(프롬프트 없음), 아니면 대화형
     if [ -n "$opt_mode" ]; then
@@ -105,7 +166,8 @@ ENV
     printf '%s | %s | %s | %s\n' "$NAME" "$CWD" "$SD" "$CH" >> "$REGISTRY"
 
     t ADD_DONE "$NAME" "$CWD" "$SD"
-    t ADD_DONE_ALLOWLIST "$TGID"
+    # allowlist(ID 시드) → 페어링 불필요 안내 / pairing(ID 미제공) → 페어링 절차 안내(ADR-004)
+    if [ "$policy" = allowlist ]; then t ADD_DONE_ALLOWLIST "$TGID"; else t ADD_DONE_PAIRING; fi
     local pmshow="${PMODE:-$(t FOLLOW_SHARED)}"
     t ADD_DONE_MODE "$pmshow" "$PROG" "$PROG" "$NAME"
     t ADD_DONE_NEXT "$PROG" "$NAME"
@@ -324,15 +386,28 @@ cmd_status() {
         t STATUS_RUNNING "$n" "$up" "$(sess_of "$n")"
       elif [ -n "$issues" ]; then
         t STATUS_BROKEN "$n" "$issues"
-        # BROKEN 사유별 복구 힌트
+        # BROKEN 사유별 복구 힌트. 토큰 키는 채널 descriptor 에서(telegram=TELEGRAM_BOT_TOKEN 등).
         [ -d "$cwd" ]     || t STATUS_HINT_NO_CWD "$cwd" "$PROG" "$n"
-        [ -f "$sd/.env" ] || t STATUS_HINT_NO_TOKEN "$sd" "$PROG" "$n"
+        [ -f "$sd/.env" ] || t STATUS_HINT_NO_TOKEN "$sd" "$PROG" "$n" "$(channel_spec "$(channel_of "$n")" token_key)"
       else
         t STATUS_STOPPED "$n"
       fi
       pm="$(mode_of "$sd")"; [ -z "$pm" ] && pm="$(t SHARED_WORD)"
       t STATUS_PATHS "$cwd" "$sd"
       t STATUS_MODE "$pm"
+      # 채널 표시명. jq 있고 access.json 있으면 dmPolicy·groups 수 토폴로지까지(없으면 표시명만 — NFR-005).
+      ch_disp="$(channel_spec "$(channel_of "$n")" display)"
+      if command -v jq >/dev/null 2>&1 && [ -f "$sd/access.json" ]; then
+        dm="$(jq -r '.dmPolicy // "?"' "$sd/access.json" 2>/dev/null)"
+        gc="$(jq -r '(.groups // {}) | length' "$sd/access.json" 2>/dev/null)"
+        if [ -n "$dm" ] && [ -n "$gc" ]; then
+          t STATUS_CHANNEL_TOPO "$ch_disp" "$dm" "$gc"
+        else
+          t STATUS_CHANNEL "$ch_disp"
+        fi
+      else
+        t STATUS_CHANNEL "$ch_disp"
+      fi
     done < <(all_names)
     if [ "$found" = 0 ]; then t STATUS_NONE; fi
 }
@@ -506,7 +581,7 @@ cmd_doctor() {
     else
       t DOCTOR_SHARED_NONE
     fi
-    t DOCTOR_PLUGIN_HINT
+    t DOCTOR_PLUGIN_HINT "$IMPLEMENTED_CHANNELS"
 }
 
 cmd_version() {
diff --git a/messages/en.sh b/messages/en.sh
index 0a159a2..036bbef 100644
--- a/messages/en.sh
+++ b/messages/en.sh
@@ -40,17 +40,20 @@ CCTG_MSG_DOWN_STOPPED="Stopped: %s\n"
 # add
 CCTG_MSG_ADD_PROMPT_TOKEN="Bot token (issued by @BotFather, must be a NEW bot): "
 CCTG_MSG_ERR_EMPTY_TOKEN="ERROR: token is empty\n"
-CCTG_MSG_ADD_PROMPT_TGID="Your numeric Telegram ID (DM @userinfobot if unknown): "
+CCTG_MSG_ADD_PROMPT_TGID="Your %s: "
 CCTG_MSG_ERR_NOT_NUMERIC_ID="ERROR: not a numeric ID: '%s'\n"
 CCTG_MSG_ADD_PROMPT_MODE="Permission mode [Enter=follow shared | %s]: "
 CCTG_MSG_ERR_BAD_MODE_ADD="ERROR: invalid permission mode: '%s' (valid: %s)\n"
-CCTG_MSG_ERR_ADD_UNKNOWN_FLAG="ERROR: unknown add flag: '%s' (valid: --id <num>, --token-env <VAR>, --token-stdin, --mode <m>, --channel <name>)\n"
+CCTG_MSG_ERR_ADD_UNKNOWN_FLAG="ERROR: unknown add flag: '%s' (valid: --id <num>, --token-env <VAR>, --token-stdin, --mode <m>, --channel <name>, --group <id>[:nomention][:allow=m1,m2])\n"
 CCTG_MSG_ERR_ADD_FLAG_VALUE="ERROR: %s requires a value\n"
 CCTG_MSG_ERR_ADD_BAD_ENVNAME="ERROR: '%s' is not a valid environment variable name\n"
 CCTG_MSG_ERR_ADD_NEED_ID="ERROR: non-interactive add (--token-env/--token-stdin) requires --id <num>\n"
+CCTG_MSG_ERR_ADD_BAD_GROUP_ID="ERROR: --group channel id must be numeric: '%s'\n"
+CCTG_MSG_ERR_ADD_BAD_GROUP_MEMBER="ERROR: --group allow member must be numeric: '%s'\n"
 CCTG_MSG_ERR_CHANNEL_UNSUPPORTED="ERROR: channel '%s' is not supported yet (implemented: %s)\n"
 CCTG_MSG_ADD_DONE="Registered: %s → cwd=%s, state=%s\n"
 CCTG_MSG_ADD_DONE_ALLOWLIST="  seeded %s into the allowlist (no pairing needed)\n"
+CCTG_MSG_ADD_DONE_PAIRING="  DM the bot to get a pairing code, then approve it from the bot's /access skill.\n"
 CCTG_MSG_ADD_DONE_MODE="  permission mode: %s  (shared: %s common / per-bot: %s config %s)\n"
 CCTG_MSG_ADD_DONE_NEXT="Next: %s up %s  → DM the bot and it responds right away.\n"
 
@@ -99,12 +102,14 @@ CCTG_MSG_ERR_COMMON_UNKNOWN="ERROR: unknown common action: %s\n"
 CCTG_MSG_COMMON_USAGE="Usage: %s common [show | edit | mode <mode> | deny add|rm <rule> | allow add|rm <rule>]\n"
 
 # status
-CCTG_MSG_STATUS_GLOBAL="Global bot: %s/telegram (not managed by this script)\n"
+CCTG_MSG_STATUS_GLOBAL="Global bots: %s (not managed by this script)\n"
 CCTG_MSG_STATUS_PROJECT_HEADER="--- project bots ---\n"
 CCTG_MSG_STATUS_RUNNING="  [RUNNING] %s%s  (tmux=%s)\n"
 CCTG_MSG_STATUS_BROKEN="  [BROKEN ] %s  (%s)\n"
+CCTG_MSG_STATUS_CHANNEL="            channel=%s\n"
+CCTG_MSG_STATUS_CHANNEL_TOPO="            channel=%s (%s, %s groups)\n"
 CCTG_MSG_STATUS_HINT_NO_CWD="            ↳ working dir missing: %s — create it, or '%s rm %s' and re-add with the right path\n"
-CCTG_MSG_STATUS_HINT_NO_TOKEN="            ↳ token missing: %s/.env — '%s rm %s' then re-add, or put TELEGRAM_BOT_TOKEN= in that file\n"
+CCTG_MSG_STATUS_HINT_NO_TOKEN="            ↳ token missing: %s/.env — '%s rm %s' then re-add, or put %s= in that file\n"
 CCTG_MSG_STATUS_STOPPED="  [stopped] %s\n"
 CCTG_MSG_ERR_STATUS_UNKNOWN_FLAG="ERROR: unknown status flag: '%s' (valid: --json)\n"
 CCTG_MSG_STATUS_PATHS="            cwd=%s  state=%s\n"
@@ -144,7 +149,7 @@ CCTG_MSG_DOCTOR_DEFAULTMODE="  defaultMode: %s\n"
 CCTG_MSG_DOCTOR_DENYALLOW="  deny: %s / allow: %s\n"
 CCTG_MSG_DOCTOR_NOJQ="  (no jq — check with 'cctg common show')\n"
 CCTG_MSG_DOCTOR_SHARED_NONE="  (none yet — created on first add/up)\n"
-CCTG_MSG_DOCTOR_PLUGIN_HINT="  (the telegram plugin must be installed globally: /plugin install telegram@claude-plugins-official)\n"
+CCTG_MSG_DOCTOR_PLUGIN_HINT="  (the channel plugins must be installed globally, e.g. /plugin install <channel>@claude-plugins-official for: %s)\n"
 
 # version / dispatcher
 CCTG_MSG_VERSION_LINE="%s %s\n"
diff --git a/messages/ko.sh b/messages/ko.sh
index a59b59c..d25adbc 100644
--- a/messages/ko.sh
+++ b/messages/ko.sh
@@ -39,17 +39,20 @@ CCTG_MSG_DOWN_STOPPED="정지 상태: %s\n"
 # add
 CCTG_MSG_ADD_PROMPT_TOKEN="봇 토큰 입력 (@BotFather 발급, 새 봇이어야 함): "
 CCTG_MSG_ERR_EMPTY_TOKEN="ERROR: 토큰이 비었습니다\n"
-CCTG_MSG_ADD_PROMPT_TGID="본인 텔레그램 숫자 ID (모르면 @userinfobot 에 DM): "
+CCTG_MSG_ADD_PROMPT_TGID="본인 %s: "
 CCTG_MSG_ERR_NOT_NUMERIC_ID="ERROR: 숫자 ID가 아닙니다: '%s'\n"
 CCTG_MSG_ADD_PROMPT_MODE="권한 모드 [엔터=공통 따름 | %s]: "
 CCTG_MSG_ERR_BAD_MODE_ADD="ERROR: 잘못된 권한 모드: '%s' (유효: %s)\n"
-CCTG_MSG_ERR_ADD_UNKNOWN_FLAG="ERROR: 알 수 없는 add 플래그: '%s' (유효: --id <num>, --token-env <VAR>, --token-stdin, --mode <m>, --channel <name>)\n"
+CCTG_MSG_ERR_ADD_UNKNOWN_FLAG="ERROR: 알 수 없는 add 플래그: '%s' (유효: --id <num>, --token-env <VAR>, --token-stdin, --mode <m>, --channel <name>, --group <id>[:nomention][:allow=m1,m2])\n"
 CCTG_MSG_ERR_ADD_FLAG_VALUE="ERROR: %s 에는 값이 필요합니다\n"
 CCTG_MSG_ERR_ADD_BAD_ENVNAME="ERROR: '%s' 은(는) 유효한 환경변수 이름이 아닙니다\n"
 CCTG_MSG_ERR_ADD_NEED_ID="ERROR: 비대화형 add(--token-env/--token-stdin)에는 --id <num> 가 필수입니다\n"
+CCTG_MSG_ERR_ADD_BAD_GROUP_ID="ERROR: --group 채널 id 는 숫자여야 합니다: '%s'\n"
+CCTG_MSG_ERR_ADD_BAD_GROUP_MEMBER="ERROR: --group allow 멤버는 숫자여야 합니다: '%s'\n"
 CCTG_MSG_ERR_CHANNEL_UNSUPPORTED="ERROR: 채널 '%s' 은(는) 아직 지원하지 않습니다 (구현됨: %s)\n"
 CCTG_MSG_ADD_DONE="등록 완료: %s → cwd=%s, state=%s\n"
 CCTG_MSG_ADD_DONE_ALLOWLIST="  allowlist에 %s 시드함 (페어링 불필요)\n"
+CCTG_MSG_ADD_DONE_PAIRING="  봇에 DM해서 페어링 코드를 받은 뒤, 봇의 /access 스킬에서 승인하세요.\n"
 CCTG_MSG_ADD_DONE_MODE="  권한 모드: %s  (공통: %s common / 봇별: %s config %s)\n"
 CCTG_MSG_ADD_DONE_NEXT="다음: %s up %s  → 봇에 DM하면 바로 응답합니다.\n"
 
@@ -98,12 +101,14 @@ CCTG_MSG_ERR_COMMON_UNKNOWN="ERROR: 알 수 없는 common 동작: %s\n"
 CCTG_MSG_COMMON_USAGE="사용법: %s common [show | edit | mode <mode> | deny add|rm <rule> | allow add|rm <rule>]\n"
 
 # status
-CCTG_MSG_STATUS_GLOBAL="전역 봇: %s/telegram (이 스크립트는 관리하지 않음)\n"
+CCTG_MSG_STATUS_GLOBAL="전역 봇: %s (이 스크립트는 관리하지 않음)\n"
 CCTG_MSG_STATUS_PROJECT_HEADER="--- 프로젝트 봇 ---\n"
 CCTG_MSG_STATUS_RUNNING="  [RUNNING] %s%s  (tmux=%s)\n"
 CCTG_MSG_STATUS_BROKEN="  [BROKEN ] %s  (%s)\n"
+CCTG_MSG_STATUS_CHANNEL="            채널=%s\n"
+CCTG_MSG_STATUS_CHANNEL_TOPO="            채널=%s (%s, 그룹 %s개)\n"
 CCTG_MSG_STATUS_HINT_NO_CWD="            ↳ 작업 디렉터리 없음: %s — 디렉터리를 만들거나 '%s rm %s' 후 올바른 경로로 다시 add\n"
-CCTG_MSG_STATUS_HINT_NO_TOKEN="            ↳ 토큰 없음: %s/.env — '%s rm %s' 후 다시 add 하거나 해당 파일에 TELEGRAM_BOT_TOKEN= 추가\n"
+CCTG_MSG_STATUS_HINT_NO_TOKEN="            ↳ 토큰 없음: %s/.env — '%s rm %s' 후 다시 add 하거나 해당 파일에 %s= 추가\n"
 CCTG_MSG_STATUS_STOPPED="  [stopped] %s\n"
 CCTG_MSG_ERR_STATUS_UNKNOWN_FLAG="ERROR: 알 수 없는 status 플래그: '%s' (유효: --json)\n"
 CCTG_MSG_STATUS_PATHS="            cwd=%s  state=%s\n"
@@ -143,7 +148,7 @@ CCTG_MSG_DOCTOR_DEFAULTMODE="  defaultMode: %s\n"
 CCTG_MSG_DOCTOR_DENYALLOW="  deny: %s 개 / allow: %s 개\n"
 CCTG_MSG_DOCTOR_NOJQ="  (jq 없음 — 'cctg common show' 로 확인)\n"
 CCTG_MSG_DOCTOR_SHARED_NONE="  (아직 없음 — 첫 add/up 시 생성)\n"
-CCTG_MSG_DOCTOR_PLUGIN_HINT="  (telegram 플러그인은 전역 설치 필요: /plugin install telegram@claude-plugins-official)\n"
+CCTG_MSG_DOCTOR_PLUGIN_HINT="  (채널 플러그인은 전역 설치 필요, 예: /plugin install <channel>@claude-plugins-official — 대상: %s)\n"
 
 # version / 디스패처
 CCTG_MSG_VERSION_LINE="%s %s\n"
diff --git a/tests/add.bats b/tests/add.bats
index 285395d..70a1aa8 100644
--- a/tests/add.bats
+++ b/tests/add.bats
@@ -93,3 +93,104 @@ load test_helper
   [ "$status" -ne 0 ]
   [[ "$output" == *"another channel bot's state"* ]]
 }
+
+# --- channel-branched add (FR-003/004/008): id_required, seed policy, --group ---
+# discord has id_required=no, so it must register without --id; telegram keeps the
+# required-id behaviour. seed_bot can't be reused for the no-id case (it injects
+# --id 555), so these drive add directly with --token-env/--token-stdin.
+
+@test "add: discord without --id proceeds (no ERR_ADD_NEED_ID) (SC-007)" {
+  BOT_TOKEN="tok" run cctg add mybot "$WORK" --channel discord --token-env BOT_TOKEN
+  [ "$status" -eq 0 ]
+  [[ "$output" != *"requires --id"* ]]
+  [ -f "$CC_CHANNELS_DIR/mybot/access.json" ]
+}
+
+@test "add: telegram without --id is still refused (SC-008)" {
+  BOT_TOKEN="tok" run cctg add mybot "$WORK" --channel telegram --token-env BOT_TOKEN
+  [ "$status" -ne 0 ]
+  [[ "$output" == *"requires --id"* ]]
+}
+
+@test "add: discord --id absent seeds pairing/[]/{}, no pending (SC-009)" {
+  BOT_TOKEN="tok" run cctg add mybot "$WORK" --channel discord --token-env BOT_TOKEN
+  [ "$status" -eq 0 ]
+  local aj="$CC_CHANNELS_DIR/mybot/access.json"
+  jq -e '.dmPolicy == "pairing"' "$aj"
+  jq -e '.allowFrom == []' "$aj"
+  jq -e '.groups == {}' "$aj"
+  jq -e 'has("pending") == false' "$aj"
+}
+
+@test "add: discord --id present seeds allowlist with id, no pending (SC-010)" {
+  BOT_TOKEN="tok" run cctg add mybot "$WORK" --channel discord --token-env BOT_TOKEN --id 12345
+  [ "$status" -eq 0 ]
+  local aj="$CC_CHANNELS_DIR/mybot/access.json"
+  jq -e '.dmPolicy == "allowlist"' "$aj"
+  jq -e '.allowFrom | index("12345") != null' "$aj"
+  jq -e 'has("pending") == false' "$aj"
+}
+
+@test "add: telegram seed has no pending field (SC-011)" {
+  BOT_TOKEN="tok" run cctg add mybot "$WORK" --channel telegram --token-env BOT_TOKEN --id 12345
+  [ "$status" -eq 0 ]
+  local aj="$CC_CHANNELS_DIR/mybot/access.json"
+  jq -e '.dmPolicy == "allowlist"' "$aj"
+  jq -e '.allowFrom | index("12345") != null' "$aj"
+  jq -e 'has("pending") == false' "$aj"
+}
+
+@test "add: discord writes DISCORD_BOT_TOKEN into .env (SC-022)" {
+  printf 'dc-secret-token\n' | cctg add mybot "$WORK" --channel discord --token-stdin >/dev/null
+  grep -q '^DISCORD_BOT_TOKEN=dc-secret-token$' "$CC_CHANNELS_DIR/mybot/.env"
+}
+
+@test "add: --group <id> once seeds that key (SC-025)" {
+  BOT_TOKEN="tok" run cctg add mybot "$WORK" --channel discord --token-env BOT_TOKEN \
+    --group 846209781206941736
+  [ "$status" -eq 0 ]
+  local aj="$CC_CHANNELS_DIR/mybot/access.json"
+  jq -e '.groups["846209781206941736"].requireMention == true' "$aj"
+  jq -e '.groups["846209781206941736"].allowFrom == []' "$aj"
+}
+
+@test "add: --group twice seeds both keys (SC-026)" {
+  BOT_TOKEN="tok" run cctg add mybot "$WORK" --channel discord --token-env BOT_TOKEN \
+    --group 111000111000111000 --group 222000222000222000
+  [ "$status" -eq 0 ]
+  local aj="$CC_CHANNELS_DIR/mybot/access.json"
+  jq -e '.groups | has("111000111000111000")' "$aj"
+  jq -e '.groups | has("222000222000222000")' "$aj"
+}
+
+@test "add: non-numeric --group id errors and registers nothing (SC-027)" {
+  BOT_TOKEN="tok" run cctg add mybot "$WORK" --channel discord --token-env BOT_TOKEN \
+    --group abc
+  [ "$status" -ne 0 ]
+  # not registered: no mybot row in the registry (file may be absent entirely)
+  ! { [ -f "$REGISTRY" ] && grep -qE "^mybot \|" "$REGISTRY"; }
+}
+
+@test "add: --group :nomention sets requireMention false (SC-030)" {
+  BOT_TOKEN="tok" run cctg add mybot "$WORK" --channel discord --token-env BOT_TOKEN \
+    --group 846209781206941736:nomention
+  [ "$status" -eq 0 ]
+  jq -e '.groups["846209781206941736"].requireMention == false' \
+    "$CC_CHANNELS_DIR/mybot/access.json"
+}
+
+@test "add: --group :allow= seeds the listed members (SC-031)" {
+  BOT_TOKEN="tok" run cctg add mybot "$WORK" --channel discord --token-env BOT_TOKEN \
+    --group 846209781206941736:allow=184695080709324800,221773638772129792
+  [ "$status" -eq 0 ]
+  local aj="$CC_CHANNELS_DIR/mybot/access.json"
+  jq -e '.groups["846209781206941736"].allowFrom | index("184695080709324800") != null' "$aj"
+  jq -e '.groups["846209781206941736"].allowFrom | index("221773638772129792") != null' "$aj"
+}
+
+@test "add: --group :allow= with non-numeric member errors, registers nothing (SC-032)" {
+  BOT_TOKEN="tok" run cctg add mybot "$WORK" --channel discord --token-env BOT_TOKEN \
+    --group 846209781206941736:allow=abc
+  [ "$status" -ne 0 ]
+  ! { [ -f "$REGISTRY" ] && grep -qE "^mybot \|" "$REGISTRY"; }
+}
diff --git a/tests/channel.bats b/tests/channel.bats
index 65f6cd2..99108c5 100644
--- a/tests/channel.bats
+++ b/tests/channel.bats
@@ -15,14 +15,62 @@ load test_helper
   grep -qE "^mybot \| .* \| .* \| telegram$" "$REGISTRY"
 }
 
-@test "add --channel <unsupported>: refused before anything is created" {
-  BOT_TOKEN=tok run cctg add mybot "$WORK" --token-env BOT_TOKEN --id 5 --channel discord
+# SC-003: discord is now an implemented channel, so --channel discord must NOT
+# be rejected as unsupported. (The old assertion expected ERR_CHANNEL_UNSUPPORTED;
+# that is obsolete intended behaviour — discord is supported as of this spec.)
+@test "add --channel discord: not refused as unsupported (SC-003)" {
+  run cctg add mybot "$WORK" --token-stdin --channel discord < /dev/null
+  # Empty stdin → ERR_EMPTY_TOKEN is allowed; the point is the channel passes the
+  # implemented-channel gate (no "not supported" message).
+  [[ "$output" != *"not supported"* ]]
+}
+
+# SC-003 (negative side): a genuinely unimplemented channel is still refused before
+# anything is scaffolded — proves the UNSUPPORTED gate is intact, not removed.
+@test "add --channel <unimplemented>: refused before anything is created" {
+  BOT_TOKEN=tok run cctg add mybot "$WORK" --token-env BOT_TOKEN --id 5 --channel fakechat
   [ "$status" -ne 0 ]
   [[ "$output" == *"not supported"* ]]
   ! grep -qE "^mybot \|" "$REGISTRY"          # nothing registered
   [ ! -d "$CC_CHANNELS_DIR/mybot" ]           # no state dir scaffolded
 }
 
+# --- descriptor: IMPLEMENTED_CHANNELS + channel_spec fields (SC-001/004/005/006) ---
+# These source lib/channels.sh directly to assert the descriptor contract.
+
+@test "channel_spec: telegram exposes all 8 fields (SC-004)" {
+  source "$REPO_ROOT/lib/channels.sh"
+  local f
+  for f in plugin statedir_env token_key token_required display id_label id_required seed_policy; do
+    run channel_spec telegram "$f"
+    [ "$status" -eq 0 ]
+    [ -n "$output" ]
+  done
+}
+
+@test "channel_spec: discord exposes all 8 fields (SC-005)" {
+  source "$REPO_ROOT/lib/channels.sh"
+  local f
+  for f in plugin statedir_env token_key token_required display id_label id_required seed_policy; do
+    run channel_spec discord "$f"
+    [ "$status" -eq 0 ]
+    [ -n "$output" ]
+  done
+}
+
+@test "channel_spec: discord display/id_required/seed_policy values (SC-006)" {
+  source "$REPO_ROOT/lib/channels.sh"
+  run channel_spec discord display;      [ "$output" = "Discord" ]
+  run channel_spec discord id_required;  [ "$output" = "no" ]
+  run channel_spec discord seed_policy;  [ "$output" = "pairing" ]
+}
+
+@test "channel_spec: an unimplemented channel field returns non-zero" {
+  source "$REPO_ROOT/lib/channels.sh"
+  run channel_spec fakechat plugin
+  [ "$status" -ne 0 ]
+}
+
 @test "add writes the channel-specific token key (telegram → TELEGRAM_BOT_TOKEN)" {
   seed_bot mybot
   grep -q '^TELEGRAM_BOT_TOKEN=' "$CC_CHANNELS_DIR/mybot/.env"
```

### 신규 파일: tests/static.bats

```bash
#!/usr/bin/env bats
# Static / source-level assertions — no runtime behaviour. Covers descriptor
# registration, telegram-hardcoding removal, completion dynamism, and shell
# syntax checks. Each test greps a checked-in source file under $REPO_ROOT.

load test_helper

# --- descriptor source presence (SC-001/002) ---

@test "channels.sh: IMPLEMENTED_CHANNELS includes discord (SC-001)" {
  grep -qE '^IMPLEMENTED_CHANNELS=.*discord' "$REPO_ROOT/lib/channels.sh"
}

@test "channels.sh: discord descriptor arms are active, not commented (SC-002)" {
  local f="$REPO_ROOT/lib/channels.sh"
  # Active case arms (line must not start with '#').
  grep -qE '^[[:space:]]*discord:plugin\)' "$f"
  grep -qE '^[[:space:]]*discord:statedir_env\)' "$f"
  grep -qE '^[[:space:]]*discord:token_key\)' "$f"
  grep -qE '^[[:space:]]*discord:token_required\)' "$f"
}

# --- telegram-hardcoding removal in message catalogs (SC-012/013/014/015) ---
# Helper: extract the value of CCTG_MSG_<key> from a catalog file.
msg_val() { grep -E "^CCTG_MSG_$2=" "$1" | head -n1; }

@test "messages: ADD_PROMPT_TGID has no telegram-specific string (SC-012)" {
  local k v
  for k in en ko; do
    v="$(msg_val "$REPO_ROOT/messages/$k.sh" ADD_PROMPT_TGID)"
    [ -n "$v" ]
    [[ "$v" != *"Telegram"* ]]
    [[ "$v" != *"@userinfobot"* ]]
  done
}

@test "messages: STATUS_GLOBAL has no /telegram hardcoding (SC-013)" {
  local k v
  for k in en ko; do
    v="$(msg_val "$REPO_ROOT/messages/$k.sh" STATUS_GLOBAL)"
    [ -n "$v" ]
    [[ "$v" != *"/telegram"* ]]
  done
}

@test "messages: STATUS_HINT_NO_TOKEN has no TELEGRAM_BOT_TOKEN hardcoding (SC-014)" {
  local k v
  for k in en ko; do
    v="$(msg_val "$REPO_ROOT/messages/$k.sh" STATUS_HINT_NO_TOKEN)"
    [ -n "$v" ]
    [[ "$v" != *"TELEGRAM_BOT_TOKEN"* ]]
  done
}

@test "messages: DOCTOR_PLUGIN_HINT has no telegram-specific install path (SC-015)" {
  local k v
  for k in en ko; do
    v="$(msg_val "$REPO_ROOT/messages/$k.sh" DOCTOR_PLUGIN_HINT)"
    [ -n "$v" ]
    [[ "$v" != *"telegram@claude-plugins-official"* ]]
    [[ "$v" != *"telegram 플러그인"* ]]
  done
}

# --- completions: dynamic --channel + --group candidate (SC-016/017/029) ---

@test "completions/_cctg: --channel is not a bare telegram literal (SC-016)" {
  local f="$REPO_ROOT/completions/_cctg"
  # The --channel arm must reference a channel list variable, not 'compadd -- telegram' alone.
  ! grep -qE '^[[:space:]]*--channel\)[[:space:]]*compadd[[:space:]]+--[[:space:]]+telegram[[:space:]]*;;' "$f"
  grep -qE '^[[:space:]]*--channel\)' "$f"
}

@test "completions/cctg.bash: --channel is not a bare telegram literal (SC-017)" {
  local f="$REPO_ROOT/completions/cctg.bash"
  ! grep -qE -- '--channel\).*compgen -W "telegram"' "$f"
  grep -qE -- '--channel\)' "$f"
}

@test "completions: add flag candidates include --group (SC-029)" {
  grep -q -- '--group' "$REPO_ROOT/completions/_cctg"
  grep -q -- '--group' "$REPO_ROOT/completions/cctg.bash"
}

# --- shell syntax checks (SC-021) ---
# lib/commands.sh uses process substitution (`done < <(...)`), present since the
# baseline and unrelated to this change, which `bash --posix -n` cannot parse.
# Per GAP-002 it is checked with plain `bash -n`; the --posix check targets the
# other modified files.

@test "syntax: posix -n passes for channels.sh/en.sh/ko.sh/cctg.bash (SC-021)" {
  local f
  for f in lib/channels.sh messages/en.sh messages/ko.sh completions/cctg.bash; do
    run bash --norc --noprofile --posix -n "$REPO_ROOT/$f"
    [ "$status" -eq 0 ]
  done
}

@test "syntax: bash -n passes for commands.sh (SC-021, GAP-002 non-posix)" {
  run bash -n "$REPO_ROOT/lib/commands.sh"
  [ "$status" -eq 0 ]
}
```

### 신규 파일: tests/status_view.bats

```bash
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
```
