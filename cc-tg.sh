#!/usr/bin/env bash
# cc-tg.sh — CCTG (Claude Code Tmux Gateway)
#
# 프로젝트별 Claude Code 텔레그램 채널 봇을 각자의 tmux 세션으로 띄우고 관리하는 런처.
# 전역 봇(기본 상태 디렉터리 ~/.claude/channels/telegram/)은 건드리지 않는다.
# 프로젝트 봇은 각자 TELEGRAM_STATE_DIR(상태 디렉터리) + 토큰 + 작업 디렉터리를 갖는다.
#
# 사용법:
#   cc-tg.sh add <name> <working_dir>   # 새 프로젝트 봇 등록(상태 디렉터리·토큰 스캐폴딩·텔레그램ID 입력 → allowlist 자동 생성)
#   cc-tg.sh rm  <name> [--purge]       # 등록 해제(--purge: 상태 디렉터리까지 삭제)
#   cc-tg.sh rename <old> <new> [--keep-dir]  # 이름 변경(기본: 상태 디렉터리도 이동)
#   cc-tg.sh config <name> [...]        # 봇별 옵션(권한 모드·추가 인자) 보기·수정
#   cc-tg.sh common [...]               # 공통 권한 정책(--settings 주입) 보기·수정
#   cc-tg.sh up  <name|all>             # 봇 기동(detached tmux + caffeinate)
#   cc-tg.sh down <name|all>            # 봇 정지
#   cc-tg.sh restart <name|all>         # 재기동
#   cc-tg.sh status                     # 등록/실행 상태
#   cc-tg.sh logs <name> [N]            # 최근 로그 N줄
#   cc-tg.sh attach <name>              # tmux 세션 attach
#   cc-tg.sh lang [show|en|ko|clear]    # CLI 출력 언어 보기·변경
#   cc-tg.sh doctor                     # 환경 진단
#   cc-tg.sh update                     # git pull 후 재설치
#   cc-tg.sh version                    # 버전 출력
#   cc-tg.sh help                       # 도움말
#
# 출력 문자열은 messages/<lang>.sh 카탈로그로 분리되어 있고, t()/die()가 키로 조회해 출력한다.
# 명령 구현은 cmd_*() 함수로 분리되어 있고, 하단의 얇은 디스패처가 라우팅한다.

set -uo pipefail

# VERSION 파일이 SoT. 아래는 파일을 못 찾을 때의 폴백.
CCTG_VERSION_FALLBACK="0.1.0"
PROG="$(basename "$0")"

# 스크립트 실제 위치 해석 (심볼릭 링크 1단계 추적). VERSION·messages 동반 파일 탐색에 사용.
_self="$0"
case "$_self" in */*) ;; *) _self="$(command -v "$_self" 2>/dev/null || printf '%s' "$_self")";; esac
if [ -L "$_self" ]; then
  _t="$(readlink "$_self")"
  case "$_t" in /*) _self="$_t";; *) _self="$(dirname "$_self")/$_t";; esac
fi
SCRIPT_DIR="$(cd "$(dirname "$_self")" 2>/dev/null && pwd)"

# 사용자 설정 파일(언어 등). 설치 매니페스트(install.conf)와 분리 — update 가 매니페스트를 재작성해도 보존된다.
CCTG_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/cctg/config"

# 패키지 동반 파일(VERSION·messages/* 등)을 cc-tg.sh 옆에서 찾는다.
# copy 설치: ~/.local/libexec/cctg/ 안, dev(symlink) 설치: 레포 안 — 둘 다 cc-tg.sh 와 같은
# 디렉터리(SCRIPT_DIR)에 동반 파일이 놓이므로 한 경로 해석으로 양쪽을 모두 처리한다.
find_companion() {
  [ -n "${SCRIPT_DIR:-}" ] && [ -f "$SCRIPT_DIR/$1" ] && { printf '%s' "$SCRIPT_DIR/$1"; return 0; }
  return 1
}

# key=value 설정 파일에서 키 값을 읽는다(마지막 매치, '=' 뒤 전체). 없거나 빈 값이면 빈 문자열.
conf_get() {
  local file="$1" key="$2"
  [ -f "$file" ] || return 0
  awk -F= -v k="$key" '$1==k{v=substr($0,index($0,"=")+1)} END{if(v!="")print v}' "$file"
}

# key=value 설정 파일에 키를 upsert(있으면 치환, 없으면 추가). 디렉터리/파일 없으면 생성.
conf_set() {
  local file="$1" key="$2" val="$3" tmp
  mkdir -p "$(dirname "$file")"
  [ -f "$file" ] || : > "$file"
  tmp="$(mktemp)" || return 1
  if grep -qE "^${key}=" "$file" 2>/dev/null; then
    awk -F= -v k="$key" -v v="$val" '$1==k{print k"="v;next}{print}' "$file" > "$tmp" && mv "$tmp" "$file"
  else
    cp "$file" "$tmp" && printf '%s=%s\n' "$key" "$val" >> "$tmp" && mv "$tmp" "$file"
  fi
}

# key=value 설정 파일에서 키 제거. 파일 없으면 무동작.
conf_unset() {
  local file="$1" key="$2" tmp
  [ -f "$file" ] || return 0
  tmp="$(mktemp)" || return 1
  awk -F= -v k="$key" '$1==k{next}{print}' "$file" > "$tmp" && mv "$tmp" "$file"
}

# 언어 결정: CCTG_LANG(환경) > 사용자설정(config lang=) > 로케일($LC_ALL/$LANG, ko* → ko) > en
cctg_lang() {
  local l="${CCTG_LANG:-}"
  [ -n "$l" ] || l="$(conf_get "$CCTG_CONFIG" lang)"
  if [ -z "$l" ]; then
    case "${LC_ALL:-${LANG:-}}" in ko*|*_KR*) l=ko;; *) l=en;; esac
  fi
  printf '%s' "$l"
}

# 메시지 카탈로그 로드: en 을 베이스로 깔고(폴백 기준) 선택 언어로 덮어쓴다.
# 파일을 못 찾으면 t() 가 키 이름(!KEY!)으로 폴백하므로 절대 깨지지 않는다.
_load_messages() {
  local lang base sel
  if base="$(find_companion messages/en.sh)"; then
    . "$base"
  else
    printf 'cctg: warning: message catalog not found (messages/en.sh); output may show raw keys.\n' >&2
  fi
  lang="$(cctg_lang)"
  if [ "$lang" != "en" ]; then
    sel="$(find_companion "messages/$lang.sh")" && . "$sel"
  fi
}
_load_messages

# 메시지 출력: 키로 printf 템플릿을 조회해 출력한다. set -u 안전을 위해 eval 간접 확장 사용.
# t   = stdout, te = stderr(에러/경고), die = stderr 후 exit 1.
t() {
  local key="$1"; shift
  local f=""
  eval "f=\"\${CCTG_MSG_$key-}\""
  [ -n "$f" ] || f="!$key!\n"
  # '--' 로 옵션 파싱 종료 — 포맷이 '---' 등 '-' 로 시작해도 printf 가 옵션으로 오인하지 않게.
  # shellcheck disable=SC2059
  printf -- "$f" "$@"
}
te()  { t "$@" >&2; }
die() { t "$@" >&2; exit 1; }

# 버전 결정: (1) 동반 VERSION(레포/dev·libexec/copy) → (2) 매니페스트 version= → (3) 폴백
cctg_version() {
  local vf v
  vf="$(find_companion VERSION)" && { head -n1 "$vf"; return; }
  v="$(conf_get "${XDG_CONFIG_HOME:-$HOME/.config}/cctg/install.conf" version)"
  [ -n "$v" ] && { printf '%s\n' "$v"; return; }
  printf '%s\n' "$CCTG_VERSION_FALLBACK"
}

CHANNELS_DIR="${CC_CHANNELS_DIR:-$HOME/.claude/channels}"
REGISTRY="${CC_TG_REGISTRY:-$CHANNELS_DIR/projects.conf}"
# 모든 CCTG 봇에 --settings 로 주입되는 공통 Claude 설정(권한 allow/deny/defaultMode).
# 전역 ~/.claude/settings.json 과 merge 되며(deny 는 union, deny 가 allow 보다 우선),
# 여기 defaultMode 가 봇의 기본 권한 모드가 된다. 봇별 launch.env 의 CCTG_PERMISSION_MODE 가 우선한다.
SHARED_SETTINGS="${CC_TG_SHARED_SETTINGS:-$CHANNELS_DIR/cctg-shared.settings.json}"
PLUGIN="plugin:telegram@claude-plugins-official"
SESS_PREFIX="cctg-"

# claude --permission-mode 가 받는 유효한 모드 (claude --help 기준)
VALID_MODES="acceptEdits auto bypassPermissions default dontAsk plan"

mkdir -p "$CHANNELS_DIR"
[ -f "$REGISTRY" ] || printf '# name | working_dir | state_dir\n' > "$REGISTRY"

# 공통 설정 파일 시드(없을 때만). 기본은 "위험하지 않은 건 자동승인"을 위해 bypassPermissions +
# deny 안전망. deny 규칙·PreToolUse 훅(git-guard)은 bypassPermissions 에서도 그대로 작동한다.
ensure_shared_settings() {
  [ -f "$SHARED_SETTINGS" ] && return 0
  cat > "$SHARED_SETTINGS" <<'JSON'
{
  "permissions": {
    "defaultMode": "bypassPermissions",
    "deny": [
      "Bash(sudo *)",
      "Bash(rm -rf /*)",
      "Bash(rm -rf ~*)",
      "Bash(rm -rf .*)",
      "Bash(git push --force*)",
      "Bash(git push -f*)",
      "Bash(git reset --hard*)",
      "Bash(git clean -fd*)",
      "Bash(git clean -fdx*)",
      "Read(~/.ssh/**)",
      "Read(~/.aws/**)"
    ],
    "allow": []
  }
}
JSON
  te SHARED_CREATED "$SHARED_SETTINGS"
}

# 모드 유효성 검사
valid_mode() { case " $VALID_MODES " in *" $1 "*) return 0;; *) return 1;; esac; }

# launch.env 에 KEY="value" upsert (있으면 치환, 없으면 추가). 값은 그대로 기록(셸 치환 주의는 호출측 책임).
set_env_kv() {
  local file="$1" key="$2" val="$3" tmp
  [ -f "$file" ] || : > "$file"
  tmp="$(mktemp)" || return 1
  if grep -qE "^${key}=" "$file" 2>/dev/null; then
    awk -v k="$key" -v v="$val" '$0 ~ "^"k"=" { print k"=\""v"\""; next } { print }' "$file" > "$tmp" && mv "$tmp" "$file"
  else
    cp "$file" "$tmp" && printf '%s="%s"\n' "$key" "$val" >> "$tmp" && mv "$tmp" "$file"
  fi
}

# launch.env 에서 CCTG_PERMISSION_MODE 값만 추출(따옴표 제거). 없으면 빈 문자열.
mode_of() {
  conf_get "$1/launch.env" CCTG_PERMISSION_MODE \
    | sed -E 's/^"//; s/"$//; s/^'\''//; s/'\''$//'
}

# jq 필요 동작 가드
need_jq() {
  command -v jq >/dev/null 2>&1 && return 0
  te ERR_NEED_JQ
  return 1
}

# jq in-place 편집
jq_inplace() {
  local f="$1"; shift; local tmp
  tmp="$(mktemp)" || return 1
  jq "$@" "$f" > "$tmp" && mv "$tmp" "$f"
}

usage() { t USAGE "$PROG"; }

# 봇 이름 검증 — tmux 세션명·레지스트리(|) 충돌 방지를 위해 영숫자/_/- 만 허용
valid_name() { printf '%s' "$1" | grep -qE '^[A-Za-z0-9_-]+$'; }

# 레지스트리에서 name 줄 제거 (주석·빈 줄은 보존)
remove_registry_line() {
  local name="$1" tmp
  tmp="$(mktemp)" || return 1
  awk -F'|' -v n="$name" '
    /^[[:space:]]*#/ {print; next}
    /^[[:space:]]*$/ {print; next}
    { c1=$1; gsub(/^[ \t]+|[ \t]+$/,"",c1); if (c1==n) next; print }
  ' "$REGISTRY" > "$tmp" && mv "$tmp" "$REGISTRY"
}

# 레지스트리에서 name 줄의 1번 컬럼(이름)·3번 컬럼(상태 디렉터리)을 갱신.
# working_dir(2번 컬럼)는 보존한다. 주석·빈 줄도 보존.
rename_registry_line() {
  local old="$1" new="$2" newsd="$3" tmp
  tmp="$(mktemp)" || return 1
  awk -F'|' -v o="$old" -v nn="$new" -v ns="$newsd" '
    /^[[:space:]]*#/ {print; next}
    /^[[:space:]]*$/ {print; next}
    {
      c1=$1; gsub(/^[ \t]+|[ \t]+$/,"",c1)
      if (c1==o) {
        c2=$2; gsub(/^[ \t]+|[ \t]+$/,"",c2)
        printf "%s | %s | %s\n", nn, c2, ns
        next
      }
      print
    }
  ' "$REGISTRY" > "$tmp" && mv "$tmp" "$REGISTRY"
}

# 선행 ~ 확장
expand() { case "$1" in "~"*) printf '%s' "${HOME}${1#\~}";; *) printf '%s' "$1";; esac; }

# 레지스트리에서 name으로 한 줄 찾기 → "cwd<TAB>statedir"
lookup() {
  awk -F'|' -v n="$1" '
    /^[[:space:]]*#/ {next} /^[[:space:]]*$/ {next}
    { gsub(/^[ \t]+|[ \t]+$/,"",$1); gsub(/^[ \t]+|[ \t]+$/,"",$2); gsub(/^[ \t]+|[ \t]+$/,"",$3);
      if ($1==n) { print $2 "\t" $3; found=1 } }
    END { if (!found) exit 1 }
  ' "$REGISTRY"
}

# 모든 등록된 name 출력
all_names() {
  awk -F'|' '/^[[:space:]]*#/{next} /^[[:space:]]*$/{next} {gsub(/^[ \t]+|[ \t]+$/,"",$1); print $1}' "$REGISTRY"
}

sess_of() { printf '%s%s' "$SESS_PREFIX" "$1"; }
is_running() { tmux has-session -t "$(sess_of "$1")" 2>/dev/null; }

# 초 → 사람이 읽는 기간 (예: 2d3h / 4h5m / 7m)
fmt_dur() {
  local s="$1" d h m
  d=$(( s / 86400 )); h=$(( (s % 86400) / 3600 )); m=$(( (s % 3600) / 60 ))
  if   [ "$d" -gt 0 ]; then printf '%dd%dh' "$d" "$h"
  elif [ "$h" -gt 0 ]; then printf '%dh%dm' "$h" "$m"
  else                      printf '%dm' "$m"; fi
}

up_one() {
  local name="$1" cwd sd row
  row="$(lookup "$name")" || { te ERR_NOT_REGISTERED "$name"; return 1; }
  cwd="$(expand "$(cut -f1 <<<"$row")")"
  sd="$(expand "$(cut -f2 <<<"$row")")"
  [ -d "$cwd" ] || { te ERR_NO_CWD "$cwd"; return 1; }
  [ -f "$sd/.env" ] || { te ERR_NO_TOKEN "$sd/.env"; return 1; }
  if is_running "$name"; then t ALREADY_RUNNING "$name"; return 0; fi

  # 공통 설정(권한 정책)을 --settings 로 주입. 없으면 시드.
  ensure_shared_settings
  local shared_arg=""
  [ -f "$SHARED_SETTINGS" ] && shared_arg="--settings $(printf '%q' "$SHARED_SETTINGS")"

  # 상태 디렉터리/토큰을 분리 주입하고 caffeinate로 sleep 방지하며 채널 세션 기동.
  # 봇별 launch.env(있으면)에서 CCTG_PERMISSION_MODE / CLAUDE_EXTRA_ARGS 를 읽어 claude 인자로 전달한다.
  #   - CCTG_PERMISSION_MODE 가 있으면 --permission-mode 로 공통 defaultMode 를 override (없으면 공통값 사용).
  #   - \$ 이스케이프로 런타임(launch.env source 이후)에 단어 분리되도록 한다.
  local launch="cd $(printf '%q' "$cwd") \
&& export TELEGRAM_STATE_DIR=$(printf '%q' "$sd") \
&& set -a && source $(printf '%q' "$sd/.env") \
&& { [ -f $(printf '%q' "$sd/launch.env") ] && source $(printf '%q' "$sd/launch.env") || true; } \
&& set +a \
&& MODE_ARG=\"\" \
&& { [ -n \"\${CCTG_PERMISSION_MODE:-}\" ] && MODE_ARG=\"--permission-mode \${CCTG_PERMISSION_MODE}\" || true; } \
&& caffeinate -is claude --channels $PLUGIN $shared_arg \${MODE_ARG} \${CLAUDE_EXTRA_ARGS:-}; exec bash"

  tmux new-session -d -s "$(sess_of "$name")" "bash -lc $(printf '%q' "$launch")"
  t UP_OK "$name" "$cwd" "$sd" "$(sess_of "$name")"
}

down_one() {
  local name="$1"
  if is_running "$name"; then
    tmux kill-session -t "$(sess_of "$name")"
    t DOWN_OK "$name"
  else
    t DOWN_STOPPED "$name"
  fi
}

cmd_add() {
    NAME="${1:?name 필요}"; CWD="${2:?working_dir 필요}"
    valid_name "$NAME" || die ERR_BADNAME "$NAME"
    SD="$CHANNELS_DIR/$NAME"
    [ "$SD" = "$CHANNELS_DIR/telegram" ] && die ERR_RESERVED
    if lookup "$NAME" >/dev/null 2>&1; then die ERR_ALREADY_REGISTERED "$NAME"; fi
    mkdir -p "$SD/inbox"

    # 1) 봇 토큰 (가려서 입력)
    t ADD_PROMPT_TOKEN
    read -rs TOKEN; echo
    [ -z "$TOKEN" ] && die ERR_EMPTY_TOKEN

    # 2) 본인 텔레그램 숫자 ID (allowlist 시드용)
    t ADD_PROMPT_TGID
    read -r TGID
    printf '%s' "$TGID" | grep -qE '^[0-9]+$' || die ERR_NOT_NUMERIC_ID "$TGID"

    # 3) 토큰 → .env (600)
    printf 'TELEGRAM_BOT_TOKEN=%s\n' "$TOKEN" > "$SD/.env"
    chmod 600 "$SD/.env"

    # 4) access.json → allowlist 자동 생성 (페어링 불필요)
    #    TGID는 위에서 숫자만 통과시켰으므로 JSON 주입 위험 없음
    cat > "$SD/access.json" <<JSON
{ "dmPolicy": "allowlist", "allowFrom": ["$TGID"], "groups": {}, "pending": {} }
JSON

    # 4.5) 권한 모드 선택 (선택). 비우면 공통 설정(cctg common 의 defaultMode)을 따른다.
    t ADD_PROMPT_MODE "$VALID_MODES"
    read -r PMODE
    if [ -n "$PMODE" ] && ! valid_mode "$PMODE"; then
      die ERR_BAD_MODE_ADD "$PMODE" "$VALID_MODES"
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
      # 안전장치: CHANNELS_DIR 하위이고 전역 봇 디렉터리가 아닐 때만 삭제
      case "$sd" in
        "$CHANNELS_DIR"/*)
          if [ "$sd" = "$CHANNELS_DIR/telegram" ]; then
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
    [ "$NEW" = "telegram" ] && die ERR_RESERVED
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
ENV
    fi
    case "$ACTION" in
      show)
        local pm; pm="$(mode_of "$sd")"; [ -n "$pm" ] || pm="$(t FOLLOW_SHARED_PAREN)"
        t CFG_SHOW_HEADER "$NAME" "$LE"
        t CFG_SHOW_MODE "$pm"
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
        is_running "$NAME" && t APPLY_RESTART "$PROG" "$NAME" ;;
      args)
        ARGS="${3-}"
        set_env_kv "$LE" CLAUDE_EXTRA_ARGS "$ARGS"
        local argshow="${ARGS:-$(t EMPTY_PAREN)}"
        t CFG_ARGS_SET "$NAME" "$argshow"
        is_running "$NAME" && t APPLY_RESTART "$PROG" "$NAME" ;;
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
      else
        t STATUS_STOPPED "$n"
      fi
      pm="$(mode_of "$sd")"; [ -z "$pm" ] && pm="$(t SHARED_WORD)"
      t STATUS_PATHS "$cwd" "$sd"
      t STATUS_MODE "$pm"
    done < <(all_names)
    [ "$found" = 0 ] && t STATUS_NONE
}

cmd_logs() {
    NAME="${1:?name 필요}"; N="${2:-50}"
    is_running "$NAME" || die LOGS_STOPPED "$NAME" "$PROG" "$NAME"
    tmux capture-pane -p -S -2000 -t "$(sess_of "$NAME")" | tail -n "$N"
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
          l="$CCTG_LANG"; src=env
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

CMD="${1:-}"
shift || true
case "$CMD" in
  add)                  cmd_add "$@" ;;
  rm|remove)            cmd_rm "$@" ;;
  rename|mv)            cmd_rename "$@" ;;
  config)               cmd_config "$@" ;;
  common)               cmd_common "$@" ;;
  up)                   cmd_up "$@" ;;
  down)                 cmd_down "$@" ;;
  restart)              cmd_restart "$@" ;;
  status)               cmd_status "$@" ;;
  logs)                 cmd_logs "$@" ;;
  attach)               cmd_attach "$@" ;;
  lang)                 cmd_lang "$@" ;;
  update)               cmd_update "$@" ;;
  doctor)               cmd_doctor "$@" ;;
  version|--version|-v) cmd_version "$@" ;;
  help|--help|-h|"")    cmd_help "$@" ;;
  *)
    te ERR_UNKNOWN_CMD "$CMD"
    printf '\n' >&2
    usage >&2
    exit 1
    ;;
esac
