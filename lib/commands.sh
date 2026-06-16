# lib/commands.sh — cmd_*(add~help) + status_json
# cc-tg.sh 가 런타임 source 하는 모듈(정의·전역설정 전용). 직접 실행하지 않는다.

cmd_add() {
    NAME="${1:?name 필요}"; CWD="${2:?working_dir 필요}"
    shift 2 || true

    # 비대화형 플래그 파싱. 토큰 플래그(--token-env/--token-stdin)가 있으면 비대화형 모드로 전환:
    # 그 경우 --id 가 필수이고, --mode 생략 시 공통 설정을 따른다(프롬프트 없음).
    # 토큰은 프로세스 목록 노출을 피하기 위해 argv 로 직접 받지 않는다(env 또는 stdin 경유).
    local opt_id="" opt_token_env="" opt_token_stdin=0 opt_mode="" noninteractive=0
    while [ $# -gt 0 ]; do
      case "$1" in
        --id)          [ $# -ge 2 ] || die ERR_ADD_FLAG_VALUE "--id";          opt_id="$2"; shift 2 ;;
        --token-env)   [ $# -ge 2 ] || die ERR_ADD_FLAG_VALUE "--token-env";   opt_token_env="$2"; noninteractive=1; shift 2 ;;
        --token-stdin) opt_token_stdin=1; noninteractive=1; shift ;;
        --mode)        [ $# -ge 2 ] || die ERR_ADD_FLAG_VALUE "--mode";        opt_mode="$2"; shift 2 ;;
        *)             die ERR_ADD_UNKNOWN_FLAG "$1" ;;
      esac
    done

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
    mkdir -p "$SD/inbox"

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

    # 2) 본인 텔레그램 숫자 ID (allowlist 시드용) — 비대화형이면 --id 필수
    if [ -n "$opt_id" ]; then
      TGID="$opt_id"
    elif [ "$noninteractive" = 1 ]; then
      die ERR_ADD_NEED_ID
    else
      t ADD_PROMPT_TGID
      read -r TGID
    fi
    printf '%s' "$TGID" | grep -qE '^[0-9]+$' || die ERR_NOT_NUMERIC_ID "$TGID"

    # 3) 토큰 → .env (600)
    printf 'TELEGRAM_BOT_TOKEN=%s\n' "$TOKEN" > "$SD/.env"
    chmod 600 "$SD/.env"

    # 4) access.json → allowlist 자동 생성 (페어링 불필요)
    #    TGID는 위에서 숫자만 통과시켰으므로 JSON 주입 위험 없음
    cat > "$SD/access.json" <<JSON
{ "dmPolicy": "allowlist", "allowFrom": ["$TGID"], "groups": {}, "pending": {} }
JSON

    # 4.5) 권한 모드 — 플래그(검증 완료) 우선, 비대화형이면 공통 따름(프롬프트 없음), 아니면 대화형
    if [ -n "$opt_mode" ]; then
      PMODE="$opt_mode"
    elif [ "$noninteractive" = 1 ]; then
      PMODE=""
    else
      t ADD_PROMPT_MODE "$VALID_MODES"
      read -r PMODE
      if [ -n "$PMODE" ] && ! valid_mode "$PMODE"; then
        die ERR_BAD_MODE_ADD "$PMODE" "$VALID_MODES"
      fi
    fi

    # 4.6) 공통 설정 파일 시드 (없으면)
    ensure_shared_settings

    # 5) launch.env 템플릿 (봇 전용 옵션 — cctg config <name> 로 수정)
    #    템플릿 주석은 봇 상태 디렉터리에 기록되는 파일 내용이라 언어 분리 대상이 아니다.
    cat > "$SD/launch.env" <<'ENV'
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
    [ -n "$PMODE" ] && set_env_kv "$SD/launch.env" CCTG_PERMISSION_MODE "$PMODE"

    # 6) 레지스트리 등록
    printf '%s | %s | %s\n' "$NAME" "$CWD" "$SD" >> "$REGISTRY"

    t ADD_DONE "$NAME" "$CWD" "$SD"
    t ADD_DONE_ALLOWLIST "$TGID"
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
    row="$(lookup "$NAME")" || die ERR_NOT_REGISTERED "$NAME"
    sd="$(expand "$(cut -f2 <<<"$row")")"
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

cmd_up() {
    TARGET="${1:?name|all 필요}"
    if [ "$TARGET" = "all" ]; then
      while IFS= read -r n; do [ -n "$n" ] && up_one "$n"; done < <(all_names)
    else
      up_one "$TARGET"
    fi
}

cmd_down() {
    TARGET="${1:?name|all 필요}"
    if [ "$TARGET" = "all" ]; then
      while IFS= read -r n; do [ -n "$n" ] && down_one "$n"; done < <(all_names)
    else
      down_one "$TARGET"
    fi
}

cmd_restart() {
    TARGET="${1:?name|all 필요}"
    if [ "$TARGET" = "all" ]; then
      while IFS= read -r n; do [ -n "$n" ] && { down_one "$n"; up_one "$n"; }; done < <(all_names)
    else
      down_one "$TARGET"; up_one "$TARGET"
    fi
}

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
        created="$(tmux display-message -p -t "$(sess_of "$n")" '#{session_created}' 2>/dev/null)"
        up=""
        if printf '%s' "$created" | grep -qE '^[0-9]+$'; then
          up="$(t STATUS_UPTIME "$(fmt_dur $(( $(date +%s) - created )))")"
        fi
        t STATUS_RUNNING "$n" "$up" "$(sess_of "$n")"
      elif [ -n "$issues" ]; then
        t STATUS_BROKEN "$n" "$issues"
        # BROKEN 사유별 복구 힌트
        [ -d "$cwd" ]     || t STATUS_HINT_NO_CWD "$cwd" "$PROG" "$n"
        [ -f "$sd/.env" ] || t STATUS_HINT_NO_TOKEN "$sd" "$PROG" "$n"
      else
        t STATUS_STOPPED "$n"
      fi
      pm="$(mode_of "$sd")"; [ -z "$pm" ] && pm="$(t SHARED_WORD)"
      t STATUS_PATHS "$cwd" "$sd"
      t STATUS_MODE "$pm"
    done < <(all_names)
    if [ "$found" = 0 ]; then t STATUS_NONE; fi
}

# status --json: 기계 판독용 봇 상태 배열. 출력은 순수 JSON(사람용 헤더 없음)이며 로케일 무관 토큰 사용.
status_json() {
    need_jq || exit 1
    local objs=() n row cwd sd sess created up_s pm running state iss issues_json now
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
        created="$(tmux display-message -p -t "$sess" '#{session_created}' 2>/dev/null)"
        printf '%s' "$created" | grep -qE '^[0-9]+$' && up_s=$(( now - created ))
      elif [ "${#iss[@]}" -gt 0 ]; then
        running=false; state="broken"
      else
        running=false; state="stopped"
      fi
      pm="$(mode_of "$sd")"; [ -z "$pm" ] && pm="shared"
      if [ "${#iss[@]}" -gt 0 ]; then issues_json="$(printf '%s\n' "${iss[@]}" | jq -R . | jq -s .)"; else issues_json="[]"; fi
      objs+=("$(jq -nc \
        --arg name "$n" --arg state "$state" --argjson running "$running" \
        --arg cwd "$cwd" --arg stateDir "$sd" --arg mode "$pm" --arg session "$sess" \
        --argjson uptimeSeconds "$up_s" --argjson issues "$issues_json" \
        '{name:$name,state:$state,running:$running,cwd:$cwd,stateDir:$stateDir,mode:$mode,session:$session,uptimeSeconds:(if $uptimeSeconds<0 then null else $uptimeSeconds end),issues:$issues}')")
    done < <(all_names)
    if [ "${#objs[@]}" -gt 0 ]; then printf '%s\n' "${objs[@]}" | jq -s .; else printf '[]\n'; fi
}

cmd_logs() {
    NAME="${1:?name 필요}"; N="${2:-50}"
    if is_running "$NAME"; then
      tmux capture-pane -p -S -2000 -t "$(sess_of "$NAME")" | tail -n "$N"
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
    tmux attach -t "$(sess_of "$NAME")"
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
    t DOCTOR_PLUGIN_HINT
}

cmd_version() {
    t VERSION_LINE "$PROG" "$(cctg_version)"
}

cmd_help() {
    usage
}
