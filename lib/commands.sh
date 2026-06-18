# lib/commands.sh — cmd_*(add~help) + status_json
# cc-tg.sh 가 런타임 source 하는 모듈(정의·전역설정 전용). 직접 실행하지 않는다.

cmd_add() {
    NAME="${1:?name 필요}"; CWD="${2:?working_dir 필요}"
    shift 2 || true

    # 비대화형 플래그 파싱. 토큰 플래그(--token-env/--token-stdin)가 있으면 비대화형 모드로 전환:
    # 그 경우 --id 가 필수이고, --mode 생략 시 공통 설정을 따른다(프롬프트 없음).
    # 토큰은 프로세스 목록 노출을 피하기 위해 argv 로 직접 받지 않는다(env 또는 stdin 경유).
    # --group 컴파운드 토큰을 단일 스칼라에 누적한다(연관배열 미사용 — Bash 3.2). 토큰은 `:` 로
    # 내부 분해하므로 토큰 간 구분자는 탭(토큰 자체엔 공백/탭 없음)을 쓴다.
    local GROUP_SEP; GROUP_SEP="$(printf '\t')"
    local opt_id="" opt_token_env="" opt_token_stdin=0 opt_mode="" opt_channel="" opt_groups="" noninteractive=0
    while [ $# -gt 0 ]; do
      case "$1" in
        --id)          [ $# -ge 2 ] || die ERR_ADD_FLAG_VALUE "--id";          opt_id="$2"; shift 2 ;;
        --token-env)   [ $# -ge 2 ] || die ERR_ADD_FLAG_VALUE "--token-env";   opt_token_env="$2"; noninteractive=1; shift 2 ;;
        --token-stdin) opt_token_stdin=1; noninteractive=1; shift ;;
        --mode)        [ $# -ge 2 ] || die ERR_ADD_FLAG_VALUE "--mode";        opt_mode="$2"; shift 2 ;;
        --channel)     [ $# -ge 2 ] || die ERR_ADD_FLAG_VALUE "--channel";     opt_channel="$2"; shift 2 ;;
        --group)       [ $# -ge 2 ] || die ERR_ADD_FLAG_VALUE "--group";       opt_groups="$opt_groups${opt_groups:+$GROUP_SEP}$2"; shift 2 ;;
        *)             die ERR_ADD_UNKNOWN_FLAG "$1" ;;
      esac
    done
    local CH="${opt_channel:-$DEFAULT_CHANNEL}"
    valid_channel "$CH" || die ERR_CHANNEL_UNSUPPORTED "$CH" "$IMPLEMENTED_CHANNELS"

    valid_name "$NAME" || die ERR_BADNAME "$NAME"
    is_reserved_name "$NAME" && die ERR_RESERVED "$NAME" "$RESERVED_NAMES"
    [ -n "$opt_mode" ] && ! valid_mode "$opt_mode" && die ERR_BAD_MODE_ADD "$opt_mode" "$VALID_MODES"
    SD="$CHANNELS_DIR/$NAME"
    if lookup "$NAME" >/dev/null 2>&1; then die ERR_ALREADY_REGISTERED "$NAME"; fi
    # 외부(전역) 채널 디렉터리 보호: 우리가 만든 적 없는(launch.env 부재) 상태 디렉터리에
    # .env/access.json 이 있으면 다른 채널 봇 디렉터리로 보고 덮어쓰지 않는다(예약 목록 밖 신규 채널 대비).
    if [ -d "$SD" ] && [ ! -f "$SD/launch.env" ] && { [ -f "$SD/.env" ] || [ -f "$SD/access.json" ]; }; then
      die ERR_FOREIGN_STATEDIR "$SD"
    fi
    # ── 입력 수집·검증 (파일 생성 전) ──────────────────────────────────────────
    # 모든 입력(토큰·ID·groups·권한모드)을 검증한 뒤에만 디스크에 쓴다(DEC-003). 기존 흐름은
    # mkdir·.env·access.json 을 먼저 쓰고 권한모드를 나중에 검증해, 오입력 시 launch.env·등록이
    # 빠진 반쪽 상태를 남겼다 — 그 반쪽 상태는 위의 foreign-statedir 가드에 걸려 같은 이름 재시도까지
    # 막았다. 검증을 선행시켜 반쪽 상태를 원천 제거한다.

    # 1) 봇 토큰 — stdin/env(비대화형) 또는 가려서 입력(대화형)
    if [ "$opt_token_stdin" = 1 ]; then
      IFS= read -r TOKEN || true
    elif [ -n "$opt_token_env" ]; then
      printf '%s' "$opt_token_env" | grep -qE '^[A-Za-z_][A-Za-z0-9_]*$' || die ERR_ADD_BAD_ENVNAME "$opt_token_env"
      TOKEN="${!opt_token_env-}"
    else
      t ADD_PROMPT_TOKEN
      read -rs TOKEN; echo
    fi
    [ -z "$TOKEN" ] && die ERR_EMPTY_TOKEN

    # 2) 본인 채널 ID (allowlist 시드용). 채널 descriptor 의 id_required 로 분기한다.
    #    id_required=yes(telegram): 비대화형이면 --id 필수, allowlist 시드.
    #    id_required=no(discord): --id 생략 가능 — 비면 빈 ID 로 진행해 페어링 정책 시드.
    if [ -n "$opt_id" ]; then
      TGID="$opt_id"
    elif [ "$(channel_spec "$CH" id_required)" = yes ] && [ "$noninteractive" = 1 ]; then
      die ERR_ADD_NEED_ID
    elif [ "$noninteractive" = 1 ]; then
      TGID=""
    else
      t ADD_PROMPT_TGID "$(channel_spec "$CH" id_label)"
      read -r TGID
    fi
    [ -n "$TGID" ] && { printf '%s' "$TGID" | grep -qE '^[0-9]+$' || die ERR_NOT_NUMERIC_ID "$TGID"; }

    # 3) access.json 정책 + groups JSON 사전 구성(검증만). 실제 파일 쓰기는 커밋 구간으로 미룬다.
    #    dmPolicy/allowFrom: ID 제공 → allowlist + [<id>] / 미제공 → 채널 seed_policy(예: discord=pairing) + []
    #    TGID·group id·member id 는 모두 ^[0-9]+$ 통과분만 JSON 에 주입한다(P-003 주입 방어).
    local sp policy af groups_json
    sp="$(channel_spec "$CH" seed_policy)"
    if [ -n "$TGID" ]; then policy=allowlist; af='["'"$TGID"'"]'; else policy="$sp"; af='[]'; fi
    groups_json=""
    if [ -n "$opt_groups" ]; then
      # groups 지정: 가변 키 JSON 객체 구성을 위해 jq 사용. need_jq·검증을 쓰기 전에 끝내
      # 미설치/오입력 시 봇이 미등록·무흔적으로 남도록 한다(ADR-006).
      need_jq || exit 1
      local gtok gid grest gmod rm_flag allow_csv allow_json gm first saved_ifs
      groups_json='{}'
      # 토큰을 줄 단위로 변환해(구분자=탭→개행) read 로 순회 — 루프 본문에서 IFS 를 자유롭게 바꾼다.
      while IFS= read -r gtok; do
        [ -z "$gtok" ] && continue
        gid="${gtok%%:*}"; grest="${gtok#"$gid"}"
        printf '%s' "$gid" | grep -qE '^[0-9]+$' || die ERR_ADD_BAD_GROUP_ID "$gid"
        rm_flag=true; allow_csv=""
        # 수식어(`:` 구분): nomention / allow=csv
        saved_ifs="$IFS"; IFS=':'
        for gmod in $grest; do
          case "$gmod" in
            "")        : ;;
            nomention) rm_flag=false ;;
            allow=*)   allow_csv="${gmod#allow=}" ;;
          esac
        done
        IFS="$saved_ifs"
        allow_json='[]'
        if [ -n "$allow_csv" ]; then
          allow_json='['; first=1
          saved_ifs="$IFS"; IFS=','
          for gm in $allow_csv; do
            IFS="$saved_ifs"
            printf '%s' "$gm" | grep -qE '^[0-9]+$' || die ERR_ADD_BAD_GROUP_MEMBER "$gm"
            [ "$first" = 1 ] && first=0 || allow_json="$allow_json,"
            allow_json="$allow_json\"$gm\""
            saved_ifs="$IFS"; IFS=','
          done
          IFS="$saved_ifs"
          allow_json="$allow_json]"
        fi
        groups_json="$(printf '%s' "$groups_json" | jq -c \
          --arg id "$gid" --argjson rm "$rm_flag" --argjson af "$allow_json" \
          '. + {($id): {requireMention:$rm, allowFrom:$af}}')" || die ERR_ADD_BAD_GROUP_ID "$gid"
      done <<EOF
$(printf '%s' "$opt_groups" | tr "$GROUP_SEP" '\n')
EOF
    fi

    # 4) 권한 모드 — 플래그(검증 완료) 우선, 비대화형이면 공통 따름(프롬프트 없음),
    #    대화형이면 번호 선택 메뉴(오타 차단 + 재입력 루프, DEC-002). 빈 입력/7 = 공통 따름.
    #    셸 자동완성은 실행 중 read 프롬프트엔 동작하지 않으므로(셸이 아닌 cctg 가 stdin 을 읽음)
    #    번호 메뉴로 오타를 원천 차단한다. 번호 외에 모드명 직접 입력도 수용.
    if [ -n "$opt_mode" ]; then
      PMODE="$opt_mode"
    elif [ "$noninteractive" = 1 ]; then
      PMODE=""
    else
      local _choice
      PMODE=""
      # 메뉴를 매 반복 출력 — 잘못 입력해 재입력할 때도 옵션을 다시 보여준다.
      while :; do
        t ADD_MODE_MENU "$(t FOLLOW_SHARED)"
        t ADD_PROMPT_MODE_PS3
        read -r _choice || { PMODE=""; break; }
        case "$_choice" in
          1) PMODE=bypassPermissions; break ;;
          2) PMODE=acceptEdits; break ;;
          3) PMODE=auto; break ;;
          4) PMODE=default; break ;;
          5) PMODE=dontAsk; break ;;
          6) PMODE=plan; break ;;
          7|"") PMODE=""; break ;;
          acceptEdits|auto|bypassPermissions|default|dontAsk|plan) PMODE="$_choice"; break ;;
          *) te ERR_ADD_MODE_CHOICE ;;
        esac
      done
    fi

    # ── 커밋 구간: 모든 입력이 검증됨. 이제부터만 디스크에 쓴다. ──────────────────
    # 등록 전 비정상 종료(쓰기 실패 등) 시 우리가 새로 만든 SD 만 정리한다(DEC-004, EXIT trap).
    # 사전에 존재하던 디렉터리는 절대 건드리지 않는다(P-002). 등록(point of no return) 후 trap 해제.
    ensure_shared_settings
    CCTG_ADD_CLEANUP_DIR=""
    trap '[ -n "${CCTG_ADD_CLEANUP_DIR:-}" ] && rm -rf "$CCTG_ADD_CLEANUP_DIR"' EXIT
    [ -e "$SD" ] || CCTG_ADD_CLEANUP_DIR="$SD"
    mkdir -p "$SD/inbox" || die ERR_ADD_WRITE "$SD/inbox"

    # 토큰 → .env (600). umask 077 서브셸로 생성 — 먼저 만들고 chmod 하면 그 사이 world-readable 창이 생긴다.
    ( umask 077; printf '%s=%s\n' "$(channel_spec "$CH" token_key)" "$TOKEN" > "$SD/.env" ) || die ERR_ADD_WRITE "$SD/.env"

    # access.json — groups 미지정은 heredoc(jq 불요 — jq 없는 환경의 일반 add 동작 보존), 지정 시 사전 구성한 groups_json 으로 jq -n.
    if [ -z "$opt_groups" ]; then
      cat > "$SD/access.json" <<JSON || die ERR_ADD_WRITE "$SD/access.json"
{ "dmPolicy": "$policy", "allowFrom": $af, "groups": {} }
JSON
    else
      jq -n --arg dm "$policy" --argjson af "$af" --argjson gr "$groups_json" \
        '{dmPolicy:$dm, allowFrom:$af, groups:$gr}' > "$SD/access.json" || die ERR_ADD_WRITE "$SD/access.json"
    fi

    # launch.env 템플릿 (봇 전용 옵션 — cctg config <name> 로 수정)
    # 템플릿 주석은 봇 상태 디렉터리에 기록되는 파일 내용이라 언어 분리 대상이 아니다.
    cat > "$SD/launch.env" <<'ENV' || die ERR_ADD_WRITE "$SD/launch.env"
# 이 봇 전용 설정. `cctg config <name> ...` 로 수정하거나 직접 편집한다.

# 권한 모드: acceptEdits | auto | bypassPermissions | default | dontAsk | plan
# 비우면 공통 설정(cctg common 의 defaultMode)을 따른다.
CCTG_PERMISSION_MODE=

# 이 봇 전용 claude 추가 인자(선택). 예: CLAUDE_EXTRA_ARGS="--model opus"
CLAUDE_EXTRA_ARGS=

# 비상시(크래시·재부팅) 로그 보존: 실행 중 N초마다 tmux 화면을 last-session.log 로 스냅샷.
# 비우면 OFF(기본). `cctg config <name> snapshot <초|off>` 로 설정. 권장 30~120.
CCTG_LOG_SNAPSHOT_INTERVAL=
ENV
    [ -n "$PMODE" ] && { set_env_kv "$SD/launch.env" CCTG_PERMISSION_MODE "$PMODE" || die ERR_ADD_WRITE "$SD/launch.env"; }

    # 레지스트리 등록 (4번째 컬럼 = 채널 타입) — point of no return. 이후 cleanup 해제.
    printf '%s | %s | %s | %s\n' "$NAME" "$CWD" "$SD" "$CH" >> "$REGISTRY" || die ERR_ADD_WRITE "$REGISTRY"
    CCTG_ADD_CLEANUP_DIR=""
    trap - EXIT

    t ADD_DONE "$NAME" "$CWD" "$SD"
    # allowlist(ID 시드) → 페어링 불필요 안내 / pairing(ID 미제공) → 페어링 절차 안내(ADR-004)
    if [ "$policy" = allowlist ]; then t ADD_DONE_ALLOWLIST "$TGID"; else t ADD_DONE_PAIRING; fi
    local pmshow="${PMODE:-$(t FOLLOW_SHARED)}"
    t ADD_DONE_MODE "$pmshow" "$PROG" "$PROG" "$NAME"
    t ADD_DONE_NEXT "$PROG" "$NAME"
}

cmd_rm() {
    NAME="${1:?name 필요}"
    PURGE=0; [ "${2:-}" = "--purge" ] && PURGE=1
    row="$(lookup "$NAME")" || die ERR_NOT_REGISTERED "$NAME"
    sd="$(expand "$(cut -f2 <<<"$row")")"
    if is_running "$NAME"; then die ERR_RUNNING_DOWN_FIRST "$PROG" "$NAME"; fi
    remove_registry_line "$NAME" || die ERR_REGISTRY_UPDATE
    t RM_DONE "$NAME"
    if [ "$PURGE" = 1 ]; then
      # 안전장치: CHANNELS_DIR 하위이고 전역 채널 봇 디렉터리가 아닐 때만 삭제
      case "$sd" in
        "$CHANNELS_DIR"/*)
          if is_reserved_channel_dir "$sd"; then
            t RM_PURGE_REFUSE_GLOBAL "$sd"
          else
            rm -rf "$sd" && t RM_PURGE_DELETED "$sd"
          fi ;;
        *) t RM_PURGE_OUTSIDE "$sd" ;;
      esac
    else
      t RM_KEEP "$sd"
    fi
}

cmd_rename() {
    OLD="${1:?old name 필요}"; NEW="${2:?new name 필요}"
    KEEPDIR=0; [ "${3:-}" = "--keep-dir" ] && KEEPDIR=1
    valid_name "$NEW" || die ERR_BADNAME "$NEW"
    is_reserved_name "$NEW" && die ERR_RESERVED "$NEW" "$RESERVED_NAMES"
    [ "$OLD" = "$NEW" ] && die ERR_SAME_NAME "$OLD"
    row="$(lookup "$OLD")" || die ERR_NOT_REGISTERED "$OLD"
    if lookup "$NEW" >/dev/null 2>&1; then die ERR_ALREADY_REGISTERED "$NEW"; fi
    # 세션명이 이름 기반이므로 실행 중에는 거부 (down 후 재시도)
    if is_running "$OLD"; then die ERR_RUNNING_DOWN_FIRST "$PROG" "$OLD"; fi
    sd_raw="$(cut -f2 <<<"$row")"
    sd="$(expand "$sd_raw")"
    # 상태 디렉터리가 기본 경로($CHANNELS_DIR/<old>)면 함께 이동, 커스텀 경로면 유지
    new_sd="$sd_raw"
    if [ "$KEEPDIR" = 0 ] && [ "$sd" = "$CHANNELS_DIR/$OLD" ]; then
      target="$CHANNELS_DIR/$NEW"
      [ -e "$target" ] && die ERR_TARGET_EXISTS "$target"
      mv "$sd" "$target" || die ERR_MOVE_FAILED "$sd" "$target"
      new_sd="$target"
      t RENAME_MOVED "$sd" "$target"
    else
      t RENAME_KEPT "$sd"
    fi
    rename_registry_line "$OLD" "$NEW" "$new_sd" || die ERR_REGISTRY_UPDATE
    t RENAME_DONE "$OLD" "$NEW"
    t RENAME_NEXT "$PROG" "$NEW"
}

cmd_config() {
    # 봇별 옵션(launch.env) 보기·수정
    NAME="${1:?name 필요}"; ACTION="${2:-show}"
    local cfg_channel
    if is_reserved_name "$NAME"; then
      # 예약어 전역 봇: 레지스트리 없이 고정 좌표 사용(ADR-006/010). channel_spec 정의 채널만 지원.
      # up/down/logs/status 와 동일하게 config(token·mode·args·snapshot) 도 전역 봇을 다룬다.
      channel_spec "$NAME" plugin >/dev/null 2>&1 || die ERR_RESERVED_UNSUPPORTED "$NAME"
      sd="$CHANNELS_DIR/$NAME"; mkdir -p "$sd"
      cfg_channel="$NAME"                          # 예약어는 채널명 == 봇명
    else
      row="$(lookup "$NAME")" || die ERR_NOT_REGISTERED "$NAME"
      sd="$(expand "$(cut -f2 <<<"$row")")"
      cfg_channel="$(channel_of "$NAME")"
    fi
    LE="$sd/launch.env"
    # 이 기능 도입 전 등록된 봇엔 키가 없을 수 있으므로 템플릿 보강
    if [ ! -f "$LE" ]; then
      cat > "$LE" <<'ENV'
# 이 봇 전용 설정. `cctg config <name> ...` 로 수정하거나 직접 편집한다.

# 권한 모드: acceptEdits | auto | bypassPermissions | default | dontAsk | plan
# 비우면 공통 설정(cctg common 의 defaultMode)을 따른다.
CCTG_PERMISSION_MODE=

# 이 봇 전용 claude 추가 인자(선택). 예: CLAUDE_EXTRA_ARGS="--model opus"
CLAUDE_EXTRA_ARGS=

# 비상시(크래시·재부팅) 로그 보존: 실행 중 N초마다 tmux 화면을 last-session.log 로 스냅샷.
# 비우면 OFF(기본). `cctg config <name> snapshot <초|off>` 로 설정. 권장 30~120.
CCTG_LOG_SNAPSHOT_INTERVAL=
ENV
    fi
    case "$ACTION" in
      show)
        local pm sv; pm="$(mode_of "$sd")"; [ -n "$pm" ] || pm="$(t FOLLOW_SHARED_PAREN)"
        sv="$(snapshot_interval_of "$sd")"; if [ -n "$sv" ]; then sv="${sv}s"; else sv="off"; fi
        t CFG_SHOW_HEADER "$NAME" "$LE"
        t CFG_SHOW_CHANNEL "$cfg_channel"
        t CFG_SHOW_MODE "$pm"
        t CFG_SHOW_SNAPSHOT "$sv"
        t CFG_SHOW_LAUNCHENV
        cat "$LE" ;;
      edit)
        "${EDITOR:-vi}" "$LE" ;;
      mode)
        M="${3-}"
        [ -z "$M" ] && die ERR_CONFIG_MODE_USAGE "$PROG" "$NAME" "$VALID_MODES"
        if [ "$M" = clear ]; then
          set_env_kv "$LE" CCTG_PERMISSION_MODE ""
          t CFG_MODE_CLEARED "$NAME"
        else
          valid_mode "$M" || die ERR_BAD_MODE "$M" "$VALID_MODES"
          set_env_kv "$LE" CCTG_PERMISSION_MODE "$M"
          t CFG_MODE_SET "$NAME" "$M"
        fi
        if is_running "$NAME"; then t APPLY_RESTART "$PROG" "$NAME"; fi ;;
      args)
        ARGS="${3-}"
        set_env_kv "$LE" CLAUDE_EXTRA_ARGS "$ARGS"
        local argshow="${ARGS:-$(t EMPTY_PAREN)}"
        t CFG_ARGS_SET "$NAME" "$argshow"
        if is_running "$NAME"; then t APPLY_RESTART "$PROG" "$NAME"; fi ;;
      snapshot)
        S="${3-}"
        [ -z "$S" ] && die ERR_CONFIG_SNAPSHOT_USAGE "$PROG" "$NAME"
        if [ "$S" = off ] || [ "$S" = 0 ]; then
          set_env_kv "$LE" CCTG_LOG_SNAPSHOT_INTERVAL ""
          t CFG_SNAPSHOT_OFF "$NAME"
        else
          { printf '%s' "$S" | grep -qE '^[0-9]+$' && [ "$S" -ge 5 ]; } \
            || die ERR_BAD_SNAPSHOT "$S"
          set_env_kv "$LE" CCTG_LOG_SNAPSHOT_INTERVAL "$S"
          t CFG_SNAPSHOT_SET "$NAME" "$S"
        fi
        if is_running "$NAME"; then t APPLY_RESTART "$PROG" "$NAME"; fi ;;
      cwd)
        # 예약어 전역 봇은 $PWD 에서 기동하며 레지스트리에 저장된 cwd 가 없다(DEC-001).
        is_reserved_name "$NAME" && die ERR_CONFIG_CWD_RESERVED "$NAME"
        NEWCWD="${3-}"
        [ -z "$NEWCWD" ] && die ERR_CONFIG_CWD_USAGE "$PROG" "$NAME"
        NEWCWD="$(expand "$NEWCWD")"
        [ -d "$NEWCWD" ] || die ERR_NO_SUCH_DIR "$NEWCWD"
        set_registry_cwd "$NAME" "$NEWCWD" || die ERR_REGISTRY_UPDATE "$NAME"
        t CFG_CWD_SET "$NAME" "$NEWCWD"
        if is_running "$NAME"; then t APPLY_RESTART "$PROG" "$NAME"; fi ;;
      token)
        # $3 이후를 플래그로 파싱: --token-env <VAR> | --token-stdin (argv 토큰 직접 전달 금지 — P-003)
        shift 2
        local t_env="" t_stdin=0 NEWTOK
        while [ $# -gt 0 ]; do
          case "$1" in
            --token-env)   [ $# -ge 2 ] || die ERR_ADD_FLAG_VALUE "--token-env"; t_env="$2"; shift 2 ;;
            --token-stdin) t_stdin=1; shift ;;
            *)             die ERR_CONFIG_TOKEN_USAGE "$PROG" "$NAME" ;;
          esac
        done
        if [ "$t_stdin" = 1 ]; then IFS= read -r NEWTOK || true
        elif [ -n "$t_env" ]; then
          printf '%s' "$t_env" | grep -qE '^[A-Za-z_][A-Za-z0-9_]*$' || die ERR_ADD_BAD_ENVNAME "$t_env"
          NEWTOK="${!t_env-}"
        else t ADD_PROMPT_TOKEN; read -rs NEWTOK; echo; fi
        [ -z "$NEWTOK" ] && die ERR_EMPTY_TOKEN
        local tk; tk="$(channel_spec "$cfg_channel" token_key)"
        # umask 077 서브셸로 생성 — chmod 후행 시의 순간 world-readable 창 제거.
        ( umask 077; printf '%s=%s\n' "$tk" "$NEWTOK" > "$sd/.env" )
        t CFG_TOKEN_SET "$NAME"
        if is_running "$NAME"; then t APPLY_RESTART "$PROG" "$NAME"; fi ;;
      *)
        te ERR_CONFIG_UNKNOWN "$ACTION"
        t CFG_USAGE "$PROG" >&2
        exit 1 ;;
    esac
}

cmd_common() {
    # 공통 옵션(모든 봇에 --settings 로 주입되는 권한 정책) 보기·수정
    ensure_shared_settings
    ACTION="${1:-show}"
    case "$ACTION" in
      show)
        t COMMON_SHOW_HEADER "$SHARED_SETTINGS"
        cat "$SHARED_SETTINGS" ;;
      edit)
        "${EDITOR:-vi}" "$SHARED_SETTINGS" ;;
      mode)
        M="${2-}"
        [ -z "$M" ] && die ERR_COMMON_MODE_USAGE "$PROG" "$VALID_MODES"
        valid_mode "$M" || die ERR_BAD_MODE "$M" "$VALID_MODES"
        need_jq || exit 1
        jq_inplace "$SHARED_SETTINGS" --arg m "$M" '.permissions.defaultMode=$m' \
          && t COMMON_MODE_SET "$M" ;;
      deny|allow)
        OP="${2:?add|rm 필요}"; RULE="${3:?규칙 필요 (예: Bash(sudo *))}"
        need_jq || exit 1
        case "$OP" in
          add) jq_inplace "$SHARED_SETTINGS" --arg k "$ACTION" --arg r "$RULE" \
                 '.permissions[$k] = ((.permissions[$k] // []) + [$r] | unique)' \
                 && t COMMON_RULE_ADD "$ACTION" "$RULE" ;;
          rm)  jq_inplace "$SHARED_SETTINGS" --arg k "$ACTION" --arg r "$RULE" \
                 '.permissions[$k] = ((.permissions[$k] // []) - [$r])' \
                 && t COMMON_RULE_RM "$ACTION" "$RULE" ;;
          *)   die ERR_COMMON_OP "$ACTION" ;;
        esac ;;
      *)
        te ERR_COMMON_UNKNOWN "$ACTION"
        t COMMON_USAGE "$PROG" >&2
        exit 1 ;;
    esac
}

# 한 타겟에 라이프사이클 action 적용 — 예약어(telegram/discord)는 전용 경로로 라우팅(ADR-006).
# 성공 0 / 실패 비0 (피호출 *_one/*_reserved 의 반환을 그대로 전파).
# restart 는 down 후 up 이며 성공 판정=up 결과(기존 cmd_restart 의미 보존).
_lifecycle_apply() {
  local action="$1" name="$2"
  case "$action" in
    up)      if is_reserved_name "$name"; then up_reserved "$name"; else up_one "$name"; fi ;;
    down)    if is_reserved_name "$name"; then down_reserved "$name"; else down_one "$name"; fi ;;
    restart) if is_reserved_name "$name"; then down_reserved "$name"; up_reserved "$name"
             else down_one "$name"; up_one "$name"; fi ;;
  esac
}

# 다중 타겟 순차 처리(좌→우) + continue-on-error. 각 인자는 이름/예약어/all 로 라우팅한다.
# 처리 건수 ≥2 면 성공/실패 요약 1줄 출력. 하나라도 실패하면 비0 반환(전부 성공 0).
_lifecycle_run() {
  local action="$1"; shift
  local ok=0 fail=0 failed="" arg n
  for arg in "$@"; do
    if [ "$arg" = all ]; then
      while IFS= read -r n; do
        [ -n "$n" ] || continue
        if _lifecycle_apply "$action" "$n"; then ok=$((ok+1)); else fail=$((fail+1)); failed="${failed:+$failed }$n"; fi
      done < <(all_names)
    elif _lifecycle_apply "$action" "$arg"; then
      ok=$((ok+1))
    else
      fail=$((fail+1)); failed="${failed:+$failed }$arg"
    fi
  done
  # 단일 타겟은 per-target 출력으로 충분 — 요약은 2건 이상일 때만(하위호환, FR-005).
  if [ $((ok+fail)) -ge 2 ]; then
    if [ "$fail" -eq 0 ]; then t MULTI_SUMMARY_OK "$action" "$ok"
    else t MULTI_SUMMARY_FAIL "$action" "$ok" "$fail" "$failed"; fi
  fi
  [ "$fail" -eq 0 ]
}

cmd_up()      { [ $# -ge 1 ] || { te ERR_NEED_TARGET; usage >&2; exit 1; }; _lifecycle_run up "$@"; }
cmd_down()    { [ $# -ge 1 ] || { te ERR_NEED_TARGET; usage >&2; exit 1; }; _lifecycle_run down "$@"; }
cmd_restart() { [ $# -ge 1 ] || { te ERR_NEED_TARGET; usage >&2; exit 1; }; _lifecycle_run restart "$@"; }

cmd_status() {
    [ "${1:-}" = "--json" ] && { status_json; return; }
    if [ -n "${1:-}" ]; then te ERR_STATUS_UNKNOWN_FLAG "$1"; usage >&2; exit 1; fi

    t STATUS_GLOBAL "$CHANNELS_DIR"
    t STATUS_PROJECT_HEADER
    found=0
    while IFS= read -r n; do
      [ -z "$n" ] && continue; found=1
      row="$(lookup "$n")"
      cwd="$(expand "$(cut -f1 <<<"$row")")"
      sd="$(expand "$(cut -f2 <<<"$row")")"
      # 깨진 상태 감지: 작업 디렉터리·토큰 파일 존재 여부
      issues=""
      [ -d "$cwd" ]      || issues="$(t ISSUE_NO_CWD)"
      [ -f "$sd/.env" ]  || issues="${issues:+$issues, }$(t ISSUE_NO_TOKEN)"
      if is_running "$n"; then
        created="$(tmux display-message -p -t "$(sess_t "$n")" '#{session_created}' 2>/dev/null)"
        up=""
        if printf '%s' "$created" | grep -qE '^[0-9]+$'; then
          up="$(t STATUS_UPTIME "$(fmt_dur $(( $(date +%s) - created )))")"
        fi
        t STATUS_RUNNING "$n" "$up" "$(sess_of "$n")"
      elif [ -n "$issues" ]; then
        t STATUS_BROKEN "$n" "$issues"
        # BROKEN 사유별 복구 힌트. 토큰 키는 채널 descriptor 에서(telegram=TELEGRAM_BOT_TOKEN 등).
        [ -d "$cwd" ]     || t STATUS_HINT_NO_CWD "$cwd" "$PROG" "$n"
        [ -f "$sd/.env" ] || t STATUS_HINT_NO_TOKEN "$sd" "$PROG" "$n" "$(channel_spec "$(channel_of "$n")" token_key)"
      else
        t STATUS_STOPPED "$n"
      fi
      pm="$(mode_of "$sd")"; [ -z "$pm" ] && pm="$(t SHARED_WORD)"
      t STATUS_PATHS "$cwd" "$sd"
      t STATUS_MODE "$pm"
      # 채널 표시명. jq 있고 access.json 있으면 dmPolicy·groups 수 토폴로지까지(없으면 표시명만 — NFR-005).
      ch_disp="$(channel_spec "$(channel_of "$n")" display)"
      if command -v jq >/dev/null 2>&1 && [ -f "$sd/access.json" ]; then
        dm="$(jq -r '.dmPolicy // "?"' "$sd/access.json" 2>/dev/null)"
        gc="$(jq -r '(.groups // {}) | length' "$sd/access.json" 2>/dev/null)"
        if [ -n "$dm" ] && [ -n "$gc" ]; then
          t STATUS_CHANNEL_TOPO "$ch_disp" "$dm" "$gc"
        else
          t STATUS_CHANNEL "$ch_disp"
        fi
      else
        t STATUS_CHANNEL "$ch_disp"
      fi
    done < <(all_names)
    if [ "$found" = 0 ]; then t STATUS_NONE; fi

    # 예약어 전역 봇 섹션: channel_spec 정의 + $CHANNELS_DIR/<ch> 존재 항목만 표시(ADR-010)
    local ch_found=0
    for ch in $RESERVED_NAMES; do
      channel_spec "$ch" plugin >/dev/null 2>&1 || continue
      sd="$CHANNELS_DIR/$ch"; [ -d "$sd" ] || continue
      if [ "$ch_found" = 0 ]; then t STATUS_RESERVED_HEADER; ch_found=1; fi
      # 전역 봇은 레지스트리에 cwd 없음(DEC-001). RUNNING 시 실제 세션 cwd 를 tmux 로 조회하고,
      # 그 외(STOPPED 등 세션 부재)엔 호출 시점 $PWD 를 표시하면 오해 소지가 있어 "—"(미상)로 둔다.
      cwd="—"
      issues=""
      [ -f "$sd/.env" ] || issues="$(t ISSUE_NO_TOKEN)"
      if is_running "$ch"; then
        local sess; sess="$(sess_of "$ch")"
        cwd="$(tmux display-message -p -t "=$sess" '#{pane_current_path}' 2>/dev/null)"; [ -n "$cwd" ] || cwd="—"
        created="$(tmux display-message -p -t "=$sess" '#{session_created}' 2>/dev/null)"
        up=""
        if printf '%s' "$created" | grep -qE '^[0-9]+$'; then
          up="$(t STATUS_UPTIME "$(fmt_dur $(( $(date +%s) - created )))")"
        fi
        t STATUS_RUNNING "$ch" "$up" "$sess"
      elif [ -n "$issues" ]; then
        t STATUS_BROKEN "$ch" "$issues"
        [ -f "$sd/.env" ] || t STATUS_HINT_NO_TOKEN "$sd" "$PROG" "$ch" "$(channel_spec "$ch" token_key)"
      else
        t STATUS_STOPPED "$ch"
      fi
      pm="$(mode_of "$sd")"; [ -z "$pm" ] && pm="$(t SHARED_WORD)"
      t STATUS_PATHS "$cwd" "$sd"
      t STATUS_MODE "$pm"
      t STATUS_CHANNEL "$(channel_spec "$ch" display)"
    done
}

# status --json: 기계 판독용 봇 상태 배열. 출력은 순수 JSON(사람용 헤더 없음)이며 로케일 무관 토큰 사용.
status_json() {
    need_jq || exit 1
    local objs=() n row cwd sd sess created up_s pm running state iss issues_json now ch
    now="$(date +%s)"
    while IFS= read -r n; do
      [ -z "$n" ] && continue
      row="$(lookup "$n")"
      cwd="$(expand "$(cut -f1 <<<"$row")")"
      sd="$(expand "$(cut -f2 <<<"$row")")"
      sess="$(sess_of "$n")"
      iss=()
      [ -d "$cwd" ]     || iss+=("no-cwd")
      [ -f "$sd/.env" ] || iss+=("no-token")
      up_s=-1
      if is_running "$n"; then
        running=true; state="running"
        created="$(tmux display-message -p -t "=$sess" '#{session_created}' 2>/dev/null)"
        printf '%s' "$created" | grep -qE '^[0-9]+$' && up_s=$(( now - created ))
      elif [ "${#iss[@]}" -gt 0 ]; then
        running=false; state="broken"
      else
        running=false; state="stopped"
      fi
      pm="$(mode_of "$sd")"; [ -z "$pm" ] && pm="shared"
      ch="$(channel_of "$n")"
      if [ "${#iss[@]}" -gt 0 ]; then issues_json="$(printf '%s\n' "${iss[@]}" | jq -R . | jq -s .)"; else issues_json="[]"; fi
      objs+=("$(jq -nc \
        --arg name "$n" --arg state "$state" --argjson running "$running" \
        --arg cwd "$cwd" --arg stateDir "$sd" --arg mode "$pm" --arg session "$sess" --arg channel "$ch" \
        --argjson uptimeSeconds "$up_s" --argjson issues "$issues_json" \
        '{name:$name,state:$state,running:$running,cwd:$cwd,stateDir:$stateDir,mode:$mode,channel:$channel,session:$session,uptimeSeconds:(if $uptimeSeconds<0 then null else $uptimeSeconds end),issues:$issues}')")
    done < <(all_names)
    if [ "${#objs[@]}" -gt 0 ]; then printf '%s\n' "${objs[@]}" | jq -s .; else printf '[]\n'; fi
}

cmd_logs() {
    NAME="${1:?name 필요}"; N="${2:-50}"
    # 예약어: 전역 봇 디렉터리에서 조회 (레지스트리 lookup 불필요)
    if is_reserved_name "$NAME"; then
      # channel_spec 미정의 예약어(imessage/fakechat)는 미지원으로 안내 (up_reserved 와 동형, ADR-010)
      channel_spec "$NAME" plugin >/dev/null 2>&1 || die ERR_RESERVED_UNSUPPORTED "$NAME"
      if is_running "$NAME"; then
        tmux capture-pane -p -S -2000 -t "$(sess_t "$NAME")" | tail -n "$N"
        return
      fi
      local snap="$CHANNELS_DIR/$NAME/last-session.log"
      if [ -f "$snap" ]; then
        t LOGS_SNAPSHOT "$NAME"
        tail -n "$N" "$snap"
        return
      fi
      die LOGS_STOPPED "$NAME" "$PROG" "$NAME"
    fi
    if is_running "$NAME"; then
      tmux capture-pane -p -S -2000 -t "$(sess_t "$NAME")" | tail -n "$N"
      return
    fi
    # 정지 상태: down 시 저장한 마지막 세션 스냅샷이 있으면 보여준다.
    local row sd snap
    if row="$(lookup "$NAME")"; then
      sd="$(expand "$(cut -f2 <<<"$row")")"; snap="$sd/last-session.log"
      if [ -f "$snap" ]; then
        t LOGS_SNAPSHOT "$NAME"
        tail -n "$N" "$snap"
        return
      fi
    fi
    die LOGS_STOPPED "$NAME" "$PROG" "$NAME"
}

cmd_attach() {
    NAME="${1:?name 필요}"
    is_running "$NAME" || die ERR_NOT_RUNNING "$NAME" "$PROG" "$NAME"
    t ATTACH_DETACH_HINT
    tmux attach -t "$(sess_t "$NAME")"
}

cmd_lang() {
    local action="${1:-show}"
    case "$action" in
      show)
        local l src
        if [ -n "${CCTG_LANG:-}" ]; then
          l="$CCTG_LANG"; src="env"
        elif [ -n "$(conf_get "$CCTG_CONFIG" lang)" ]; then
          l="$(conf_get "$CCTG_CONFIG" lang)"; src=config
        elif [ -n "${LC_ALL:-${LANG:-}}" ]; then
          case "${LC_ALL:-${LANG:-}}" in ko*|*_KR*) l=ko;; *) l=en;; esac; src=auto
        else
          l=en; src=default
        fi
        t LANG_CURRENT "$l" "$src" ;;
      en|ko)
        conf_set "$CCTG_CONFIG" lang "$action"
        t LANG_SET "$action" ;;
      clear)
        conf_unset "$CCTG_CONFIG" lang
        t LANG_CLEARED ;;
      *)
        te ERR_LANG_INVALID "$action"
        t LANG_USAGE "$PROG" >&2
        exit 1 ;;
    esac
}

cmd_update() {
    # 설치 매니페스트에서 레포 위치·모드를 읽어 git pull 후 재설치한다.
    CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/cctg"
    MANIFEST="$CONFIG_DIR/install.conf"
    REPO="" MODE="copy" BINDIR=""
    if [ -f "$MANIFEST" ]; then
      REPO="$(awk -F= '$1=="repo"{print substr($0,index($0,"=")+1)}'   "$MANIFEST")"
      MODE="$(awk -F= '$1=="mode"{print substr($0,index($0,"=")+1)}'   "$MANIFEST")"
      BINDIR="$(awk -F= '$1=="bindir"{print substr($0,index($0,"=")+1)}' "$MANIFEST")"
    fi
    # 매니페스트가 없으면(구버전 설치 등) 심볼릭 설치인 경우 $0 링크로 레포를 역추적
    if [ -z "$REPO" ] && [ -L "$0" ]; then
      t_link="$(readlink "$0")"
      case "$t_link" in
        /*) REPO="$(cd "$(dirname "$t_link")" && pwd)" ;;
        *)  REPO="$(cd "$(dirname "$0")/$(dirname "$t_link")" && pwd)" ;;
      esac
      MODE="link"
    fi
    if [ -z "$REPO" ] || [ ! -d "$REPO/.git" ]; then
      te ERR_REPO_NOT_FOUND
      t ERR_REPO_HINT "$MANIFEST" >&2
      exit 1
    fi
    OLDVER="$(cctg_version)"
    t UPDATE_START "$REPO" "$MODE" "$OLDVER"
    if ! git -C "$REPO" pull --ff-only; then
      die ERR_GIT_PULL
    fi
    # 두 모드 모두 install.sh 재실행(멱등). link 모드라도 자동완성은 DATA_DIR 로 "복사"되므로
    # git pull 만으로는 갱신되지 않는다 — 재실행으로 자동완성 재복사·재링크·매니페스트 갱신을 일괄 처리.
    inst_args=""
    [ "$MODE" = "link" ] && inst_args="--dev"
    BINDIR="${BINDIR:-$HOME/.local/bin}" "$REPO/install.sh" $inst_args
    NEWVER="$(head -n1 "$REPO/VERSION" 2>/dev/null || printf '%s' "$OLDVER")"
    t UPDATE_VERSION "$OLDVER" "$NEWVER"
    # 자동완성은 현재 셸 세션에 캐싱되어 있어 즉시 반영되지 않는다(zsh: ~/.zcompdump + 로드된 _cctg).
    t UPDATE_COMPLETION_HINT
}

cmd_doctor() {
    t DOCTOR_HEADER "$(cctg_version)"
    t DOCTOR_DEPS
    for d in tmux claude caffeinate; do
      if command -v "$d" >/dev/null 2>&1; then
        t DOCTOR_OK "$d" "$(command -v "$d")"
      elif [ "$d" = caffeinate ]; then
        t DOCTOR_WARN_CAFFEINATE "$d"
      else
        t DOCTOR_MISS "$d"
      fi
    done
    if command -v jq >/dev/null 2>&1; then
      t DOCTOR_OK jq "$(command -v jq)"
    else
      t DOCTOR_WARN_JQ
    fi
    t DOCTOR_PATH
    case ":$PATH:" in
      *":$HOME/.local/bin:"*) t DOCTOR_PATH_OK ;;
      *) t DOCTOR_PATH_WARN ;;
    esac
    t DOCTOR_REGISTRY
    t DOCTOR_FILE "$REGISTRY"
    cnt=0
    while IFS= read -r n; do [ -n "$n" ] && cnt=$((cnt+1)); done < <(all_names)
    t DOCTOR_REGISTRY_COUNT "$cnt"
    t DOCTOR_SHARED
    t DOCTOR_FILE "$SHARED_SETTINGS"
    if [ -f "$SHARED_SETTINGS" ]; then
      if command -v jq >/dev/null 2>&1; then
        t DOCTOR_DEFAULTMODE "$(jq -r '.permissions.defaultMode // "default"' "$SHARED_SETTINGS" 2>/dev/null)"
        t DOCTOR_DENYALLOW "$(jq -r '(.permissions.deny // []) | length' "$SHARED_SETTINGS" 2>/dev/null)" "$(jq -r '(.permissions.allow // []) | length' "$SHARED_SETTINGS" 2>/dev/null)"
      else
        t DOCTOR_NOJQ
      fi
    else
      t DOCTOR_SHARED_NONE
    fi
    t DOCTOR_PLUGIN_HINT "$IMPLEMENTED_CHANNELS"
}

cmd_version() {
    t VERSION_LINE "$PROG" "$(cctg_version)"
}

cmd_help() {
    usage
}
