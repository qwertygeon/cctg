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
#   cc-tg.sh restart <name|all>         # 봇 재기동(down + up)
#   cc-tg.sh status                     # 등록/실행 상태 보기
#   cc-tg.sh logs <name> [N]            # 최근 로그 N줄 출력(기본 50, attach 없이)
#   cc-tg.sh attach <name>              # 해당 세션에 붙어서 로그 확인
#   cc-tg.sh doctor                     # 의존성·PATH·레지스트리 환경 진단
#   cc-tg.sh update                     # git pull 후 cctg 재설치(설치 매니페스트 기반)
#   cc-tg.sh version                    # 버전 출력
#
# 의존성: tmux, claude(CLI), caffeinate(macOS). 플러그인은 전역 설치되어 있어야 함:
#   /plugin install telegram@claude-plugins-official

set -uo pipefail

# VERSION 파일이 SoT. 아래는 파일을 못 찾을 때의 폴백.
CCTG_VERSION_FALLBACK="0.1.0"
PROG="$(basename "$0")"

# 스크립트 실제 위치 해석 (심볼릭 링크 1단계 추적). VERSION 파일 탐색에 사용.
_self="$0"
case "$_self" in */*) ;; *) _self="$(command -v "$_self" 2>/dev/null || printf '%s' "$_self")";; esac
if [ -L "$_self" ]; then
  _t="$(readlink "$_self")"
  case "$_t" in /*) _self="$_t";; *) _self="$(dirname "$_self")/$_t";; esac
fi
SCRIPT_DIR="$(cd "$(dirname "$_self")" 2>/dev/null && pwd)"

# 버전 결정: (1) 스크립트 옆 VERSION(레포/dev) → (2) 매니페스트 version=(copy) → (3) 폴백
cctg_version() {
  local mf v
  if [ -n "${SCRIPT_DIR:-}" ] && [ -f "$SCRIPT_DIR/VERSION" ]; then
    head -n1 "$SCRIPT_DIR/VERSION"; return
  fi
  mf="${XDG_CONFIG_HOME:-$HOME/.config}/cctg/install.conf"
  if [ -f "$mf" ]; then
    v="$(awk -F= '$1=="version"{print substr($0,index($0,"=")+1)}' "$mf")"
    [ -n "$v" ] && { printf '%s\n' "$v"; return; }
  fi
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
  echo "공통 설정 생성: $SHARED_SETTINGS (defaultMode=bypassPermissions + deny 안전망)" >&2
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
  local f="$1/launch.env"
  [ -f "$f" ] || { printf ''; return; }
  grep -E '^CCTG_PERMISSION_MODE=' "$f" | tail -1 \
    | sed -E "s/^CCTG_PERMISSION_MODE=//; s/^\"//; s/\"$//; s/^'//; s/'$//"
}

# jq 필요 동작 가드
need_jq() {
  command -v jq >/dev/null 2>&1 && return 0
  echo "ERROR: 이 동작은 jq가 필요합니다. 'cctg common edit'로 직접 편집하거나 jq를 설치하세요 (brew install jq)."
  return 1
}

# jq in-place 편집
jq_inplace() {
  local f="$1"; shift; local tmp
  tmp="$(mktemp)" || return 1
  jq "$@" "$f" > "$tmp" && mv "$tmp" "$f"
}

usage() {
  cat <<EOF
사용법: $PROG <command> [args]
  add <name> <cwd>       프로젝트 봇 등록
  rm  <name> [--purge]   등록 해제 (--purge: 상태 디렉터리까지 삭제)
  rename <old> <new> [--keep-dir]
                         이름 변경 (기본: 상태 디렉터리도 함께 이동.
                         --keep-dir: 디렉터리 경로 유지하고 이름만 변경)
  config <name> [show|edit|mode <m|clear>|args <str>]
                         봇별 옵션(권한 모드·추가 인자) 보기·수정
  common [show|edit|mode <m>|deny add|rm <rule>|allow add|rm <rule>]
                         공통 권한 정책(모든 봇에 적용) 보기·수정
  up   <name|all>        기동
  down <name|all>        정지
  restart <name|all>     재기동 (down + up)
  status                 등록/실행 상태
  logs <name> [N]        최근 로그 N줄 (기본 50, attach 없이)
  attach <name>          tmux 세션 attach (분리: Ctrl-b d)
  doctor                 의존성·PATH·레지스트리 환경 진단
  update                 git pull 후 재설치
  version                버전 출력
  help                   이 도움말

이름 규칙: 영문/숫자/_/- 만 허용. 'telegram'은 전역 봇 예약 이름.
EOF
}

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
  row="$(lookup "$name")" || { echo "ERROR: 등록되지 않은 프로젝트: $name"; return 1; }
  cwd="$(expand "$(cut -f1 <<<"$row")")"
  sd="$(expand "$(cut -f2 <<<"$row")")"
  [ -d "$cwd" ] || { echo "ERROR: 작업 디렉터리 없음: $cwd"; return 1; }
  [ -f "$sd/.env" ] || { echo "ERROR: 토큰 파일 없음: $sd/.env (먼저 add 하세요)"; return 1; }
  if is_running "$name"; then echo "이미 실행 중: $name"; return 0; fi

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
  echo "UP   $name  (cwd=$cwd, state=$sd, tmux=$(sess_of "$name"))"
}

down_one() {
  local name="$1"
  if is_running "$name"; then
    tmux kill-session -t "$(sess_of "$name")"
    echo "DOWN $name"
  else
    echo "정지 상태: $name"
  fi
}

CMD="${1:-}"
shift || true
case "$CMD" in
  add)
    NAME="${1:?name 필요}"; CWD="${2:?working_dir 필요}"
    if ! valid_name "$NAME"; then
      echo "ERROR: 이름은 영문/숫자/_/- 만 허용합니다: '$NAME'"; exit 1
    fi
    SD="$CHANNELS_DIR/$NAME"
    if [ "$SD" = "$CHANNELS_DIR/telegram" ]; then
      echo "ERROR: 'telegram'은 전역 봇 예약 이름입니다. 다른 이름을 쓰세요."; exit 1
    fi
    if lookup "$NAME" >/dev/null 2>&1; then echo "ERROR: 이미 등록됨: $NAME"; exit 1; fi
    mkdir -p "$SD/inbox"

    # 1) 봇 토큰 (가려서 입력)
    printf '봇 토큰 입력 (@BotFather 발급, 새 봇이어야 함): '
    read -rs TOKEN; echo
    if [ -z "$TOKEN" ]; then echo "ERROR: 토큰이 비었습니다"; exit 1; fi

    # 2) 본인 텔레그램 숫자 ID (allowlist 시드용)
    printf '본인 텔레그램 숫자 ID (모르면 @userinfobot 에 DM): '
    read -r TGID
    if ! printf '%s' "$TGID" | grep -qE '^[0-9]+$'; then
      echo "ERROR: 숫자 ID가 아닙니다: '$TGID'"; exit 1
    fi

    # 3) 토큰 → .env (600)
    printf 'TELEGRAM_BOT_TOKEN=%s\n' "$TOKEN" > "$SD/.env"
    chmod 600 "$SD/.env"

    # 4) access.json → allowlist 자동 생성 (페어링 불필요)
    #    TGID는 위에서 숫자만 통과시켰으므로 JSON 주입 위험 없음
    cat > "$SD/access.json" <<JSON
{ "dmPolicy": "allowlist", "allowFrom": ["$TGID"], "groups": {}, "pending": {} }
JSON

    # 4.5) 권한 모드 선택 (선택). 비우면 공통 설정(cctg common 의 defaultMode)을 따른다.
    printf '권한 모드 [엔터=공통 따름 | %s]: ' "$VALID_MODES"
    read -r PMODE
    if [ -n "$PMODE" ] && ! valid_mode "$PMODE"; then
      echo "ERROR: 잘못된 권한 모드: '$PMODE' (유효: $VALID_MODES)"; exit 1
    fi

    # 4.6) 공통 설정 파일 시드 (없으면)
    ensure_shared_settings

    # 5) launch.env 템플릿 (봇 전용 옵션 — cctg config <name> 로 수정)
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

    echo "등록 완료: $NAME → cwd=$CWD, state=$SD"
    echo "  allowlist에 $TGID 시드함 (페어링 불필요)"
    echo "  권한 모드: ${PMODE:-공통 따름}  (공통: $PROG common / 봇별: $PROG config $NAME)"
    echo "다음: $PROG up $NAME  → 봇에 DM하면 바로 응답합니다."
    ;;
  rm|remove)
    NAME="${1:?name 필요}"
    PURGE=0; [ "${2:-}" = "--purge" ] && PURGE=1
    row="$(lookup "$NAME")" || { echo "ERROR: 등록되지 않은 프로젝트: $NAME"; exit 1; }
    sd="$(expand "$(cut -f2 <<<"$row")")"
    if is_running "$NAME"; then
      echo "ERROR: 실행 중입니다. 먼저 '$PROG down $NAME' 후 다시 시도하세요."; exit 1
    fi
    remove_registry_line "$NAME" || { echo "ERROR: 레지스트리 갱신 실패"; exit 1; }
    echo "등록 해제: $NAME"
    if [ "$PURGE" = 1 ]; then
      # 안전장치: CHANNELS_DIR 하위이고 전역 봇 디렉터리가 아닐 때만 삭제
      case "$sd" in
        "$CHANNELS_DIR"/*)
          if [ "$sd" = "$CHANNELS_DIR/telegram" ]; then
            echo "  거부: 전역 봇 디렉터리는 삭제하지 않습니다: $sd"
          else
            rm -rf "$sd" && echo "  상태 디렉터리 삭제: $sd"
          fi ;;
        *) echo "  주의: 상태 디렉터리가 CHANNELS_DIR 밖이라 자동 삭제하지 않음: $sd" ;;
      esac
    else
      echo "  상태 디렉터리 보존: $sd (토큰/allowlist 포함). 완전 삭제하려면 --purge"
    fi
    ;;
  rename|mv)
    OLD="${1:?old name 필요}"; NEW="${2:?new name 필요}"
    KEEPDIR=0; [ "${3:-}" = "--keep-dir" ] && KEEPDIR=1
    if ! valid_name "$NEW"; then
      echo "ERROR: 이름은 영문/숫자/_/- 만 허용합니다: '$NEW'"; exit 1
    fi
    if [ "$NEW" = "telegram" ]; then
      echo "ERROR: 'telegram'은 전역 봇 예약 이름입니다. 다른 이름을 쓰세요."; exit 1
    fi
    if [ "$OLD" = "$NEW" ]; then echo "ERROR: old/new 이름이 동일합니다: $OLD"; exit 1; fi
    row="$(lookup "$OLD")" || { echo "ERROR: 등록되지 않은 프로젝트: $OLD"; exit 1; }
    if lookup "$NEW" >/dev/null 2>&1; then echo "ERROR: 이미 등록됨: $NEW"; exit 1; fi
    # 세션명이 이름 기반이므로 실행 중에는 거부 (down 후 재시도)
    if is_running "$OLD"; then
      echo "ERROR: 실행 중입니다. 먼저 '$PROG down $OLD' 후 다시 시도하세요."; exit 1
    fi
    sd_raw="$(cut -f2 <<<"$row")"
    sd="$(expand "$sd_raw")"
    # 상태 디렉터리가 기본 경로($CHANNELS_DIR/<old>)면 함께 이동, 커스텀 경로면 유지
    new_sd="$sd_raw"
    if [ "$KEEPDIR" = 0 ] && [ "$sd" = "$CHANNELS_DIR/$OLD" ]; then
      target="$CHANNELS_DIR/$NEW"
      if [ -e "$target" ]; then
        echo "ERROR: 대상 상태 디렉터리가 이미 존재합니다: $target (이동 취소)"; exit 1
      fi
      mv "$sd" "$target" || { echo "ERROR: 상태 디렉터리 이동 실패: $sd → $target"; exit 1; }
      new_sd="$target"
      echo "  상태 디렉터리 이동: $sd → $target"
    else
      echo "  상태 디렉터리 유지: $sd"
    fi
    rename_registry_line "$OLD" "$NEW" "$new_sd" || { echo "ERROR: 레지스트리 갱신 실패"; exit 1; }
    echo "이름 변경: $OLD → $NEW"
    echo "다음: $PROG up $NEW"
    ;;
  config)
    # 봇별 옵션(launch.env) 보기·수정
    NAME="${1:?name 필요}"; ACTION="${2:-show}"
    row="$(lookup "$NAME")" || { echo "ERROR: 등록되지 않은 프로젝트: $NAME"; exit 1; }
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
        echo "# $NAME 봇 옵션 ($LE)"
        echo "  권한 모드: $(mode_of "$sd" | sed 's/^$/(공통 따름)/')"
        echo "--- launch.env ---"
        cat "$LE" ;;
      edit)
        "${EDITOR:-vi}" "$LE" ;;
      mode)
        M="${3-}"
        [ -z "$M" ] && { echo "사용법: $PROG config $NAME mode <mode|clear>  (모드: $VALID_MODES)"; exit 1; }
        if [ "$M" = clear ]; then
          set_env_kv "$LE" CCTG_PERMISSION_MODE ""
          echo "$NAME 권한 모드: (공통 따름)"
        else
          valid_mode "$M" || { echo "ERROR: 잘못된 모드: '$M' (유효: $VALID_MODES)"; exit 1; }
          set_env_kv "$LE" CCTG_PERMISSION_MODE "$M"
          echo "$NAME 권한 모드: $M"
        fi
        is_running "$NAME" && echo "  적용하려면: $PROG restart $NAME" ;;
      args)
        ARGS="${3-}"
        set_env_kv "$LE" CLAUDE_EXTRA_ARGS "$ARGS"
        echo "$NAME CLAUDE_EXTRA_ARGS: ${ARGS:-(비움)}"
        is_running "$NAME" && echo "  적용하려면: $PROG restart $NAME" ;;
      *)
        echo "ERROR: 알 수 없는 config 동작: $ACTION"
        echo "사용법: $PROG config <name> [show | edit | mode <mode|clear> | args <string>]"
        exit 1 ;;
    esac
    ;;
  common)
    # 공통 옵션(모든 봇에 --settings 로 주입되는 권한 정책) 보기·수정
    ensure_shared_settings
    ACTION="${1:-show}"
    case "$ACTION" in
      show)
        echo "# 공통 설정 ($SHARED_SETTINGS)"
        cat "$SHARED_SETTINGS" ;;
      edit)
        "${EDITOR:-vi}" "$SHARED_SETTINGS" ;;
      mode)
        M="${2-}"
        [ -z "$M" ] && { echo "사용법: $PROG common mode <mode>  (모드: $VALID_MODES)"; exit 1; }
        valid_mode "$M" || { echo "ERROR: 잘못된 모드: '$M' (유효: $VALID_MODES)"; exit 1; }
        need_jq || exit 1
        jq_inplace "$SHARED_SETTINGS" --arg m "$M" '.permissions.defaultMode=$m' \
          && echo "공통 defaultMode: $M  (모든 봇 restart 후 적용)" ;;
      deny|allow)
        OP="${2:?add|rm 필요}"; RULE="${3:?규칙 필요 (예: Bash(sudo *))}"
        need_jq || exit 1
        case "$OP" in
          add) jq_inplace "$SHARED_SETTINGS" --arg k "$ACTION" --arg r "$RULE" \
                 '.permissions[$k] = ((.permissions[$k] // []) + [$r] | unique)' \
                 && echo "$ACTION += $RULE  (모든 봇 restart 후 적용)" ;;
          rm)  jq_inplace "$SHARED_SETTINGS" --arg k "$ACTION" --arg r "$RULE" \
                 '.permissions[$k] = ((.permissions[$k] // []) - [$r])' \
                 && echo "$ACTION -= $RULE  (모든 봇 restart 후 적용)" ;;
          *)   echo "ERROR: $ACTION 동작은 add|rm 만 지원"; exit 1 ;;
        esac ;;
      *)
        echo "ERROR: 알 수 없는 common 동작: $ACTION"
        echo "사용법: $PROG common [show | edit | mode <mode> | deny add|rm <rule> | allow add|rm <rule>]"
        exit 1 ;;
    esac
    ;;
  up)
    TARGET="${1:?name|all 필요}"
    if [ "$TARGET" = "all" ]; then
      while IFS= read -r n; do [ -n "$n" ] && up_one "$n"; done < <(all_names)
    else
      up_one "$TARGET"
    fi
    ;;
  down)
    TARGET="${1:?name|all 필요}"
    if [ "$TARGET" = "all" ]; then
      while IFS= read -r n; do [ -n "$n" ] && down_one "$n"; done < <(all_names)
    else
      down_one "$TARGET"
    fi
    ;;
  restart)
    TARGET="${1:?name|all 필요}"
    if [ "$TARGET" = "all" ]; then
      while IFS= read -r n; do [ -n "$n" ] && { down_one "$n"; up_one "$n"; }; done < <(all_names)
    else
      down_one "$TARGET"; up_one "$TARGET"
    fi
    ;;
  status)
    echo "전역 봇: $CHANNELS_DIR/telegram (이 스크립트는 관리하지 않음)"
    echo "--- 프로젝트 봇 ---"
    found=0
    while IFS= read -r n; do
      [ -z "$n" ] && continue; found=1
      row="$(lookup "$n")"
      cwd="$(expand "$(cut -f1 <<<"$row")")"
      sd="$(expand "$(cut -f2 <<<"$row")")"
      # 깨진 상태 감지: 작업 디렉터리·토큰 파일 존재 여부
      issues=""
      [ -d "$cwd" ]      || issues="cwd없음"
      [ -f "$sd/.env" ]  || issues="${issues:+$issues, }토큰없음"
      if is_running "$n"; then
        created="$(tmux display-message -p -t "$(sess_of "$n")" '#{session_created}' 2>/dev/null)"
        up=""
        if printf '%s' "$created" | grep -qE '^[0-9]+$'; then
          up="  up $(fmt_dur $(( $(date +%s) - created )))"
        fi
        printf '  [RUNNING] %s%s  (tmux=%s)\n' "$n" "$up" "$(sess_of "$n")"
      elif [ -n "$issues" ]; then
        printf '  [BROKEN ] %s  (%s)\n' "$n" "$issues"
      else
        printf '  [stopped] %s\n' "$n"
      fi
      pm="$(mode_of "$sd")"; [ -z "$pm" ] && pm="공통"
      printf '            cwd=%s  state=%s\n' "$cwd" "$sd"
      printf '            권한모드=%s\n' "$pm"
    done < <(all_names)
    [ "$found" = 0 ] && echo "  (등록된 프로젝트 봇 없음)"
    ;;
  logs)
    NAME="${1:?name 필요}"; N="${2:-50}"
    is_running "$NAME" || { echo "정지 상태: $NAME (로그 없음). '$PROG up $NAME' 후 다시 시도하세요."; exit 1; }
    tmux capture-pane -p -S -2000 -t "$(sess_of "$NAME")" | tail -n "$N"
    ;;
  attach)
    NAME="${1:?name 필요}"
    is_running "$NAME" || { echo "ERROR: 실행 중이 아닙니다: $NAME ('$PROG up $NAME' 먼저)"; exit 1; }
    echo "(분리하려면 Ctrl-b 누른 뒤 d)"
    tmux attach -t "$(sess_of "$NAME")"
    ;;
  update)
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
      t="$(readlink "$0")"
      case "$t" in
        /*) REPO="$(cd "$(dirname "$t")" && pwd)" ;;
        *)  REPO="$(cd "$(dirname "$0")/$(dirname "$t")" && pwd)" ;;
      esac
      MODE="link"
    fi
    if [ -z "$REPO" ] || [ ! -d "$REPO/.git" ]; then
      echo "ERROR: cctg 레포 위치를 찾을 수 없습니다."
      echo "  레포에서 install.sh 를 한 번 실행하면 매니페스트($MANIFEST)가 생성됩니다."
      exit 1
    fi
    OLDVER="$(cctg_version)"
    echo "업데이트: $REPO  (mode=$MODE, 현재 v$OLDVER)"
    if ! git -C "$REPO" pull --ff-only; then
      echo "ERROR: git pull 실패 (로컬 변경이 있거나 fast-forward 불가). 레포에서 직접 확인하세요."
      exit 1
    fi
    if [ "$MODE" = "link" ]; then
      echo "심볼릭 설치이므로 cctg 가 이미 최신입니다."
    else
      BINDIR="${BINDIR:-$HOME/.local/bin}" "$REPO/install.sh"
    fi
    NEWVER="$(head -n1 "$REPO/VERSION" 2>/dev/null || printf '%s' "$OLDVER")"
    echo "버전: v$OLDVER → v$NEWVER"
    ;;
  doctor)
    echo "cctg doctor (v$(cctg_version))"
    echo "--- 의존성 ---"
    for d in tmux claude caffeinate; do
      if command -v "$d" >/dev/null 2>&1; then
        echo "  ok   $d ($(command -v "$d"))"
      elif [ "$d" = caffeinate ]; then
        echo "  warn $d 없음 (macOS 아님 → sleep 방지 불가)"
      else
        echo "  MISS $d (필수)"
      fi
    done
    if command -v jq >/dev/null 2>&1; then
      echo "  ok   jq ($(command -v jq))"
    else
      echo "  warn jq 없음 (선택 — 'common mode/deny/allow'에 필요. 없어도 'common edit' 가능)"
    fi
    echo "--- PATH ---"
    case ":$PATH:" in
      *":$HOME/.local/bin:"*) echo "  ok   ~/.local/bin 이 PATH에 있음" ;;
      *) echo "  warn ~/.local/bin 이 PATH에 없음" ;;
    esac
    echo "--- 레지스트리 ---"
    echo "  파일: $REGISTRY"
    cnt=0
    while IFS= read -r n; do [ -n "$n" ] && cnt=$((cnt+1)); done < <(all_names)
    echo "  등록된 프로젝트 봇: $cnt 개"
    echo "--- 공통 설정(권한 정책) ---"
    echo "  파일: $SHARED_SETTINGS"
    if [ -f "$SHARED_SETTINGS" ]; then
      if command -v jq >/dev/null 2>&1; then
        echo "  defaultMode: $(jq -r '.permissions.defaultMode // "default"' "$SHARED_SETTINGS" 2>/dev/null)"
        echo "  deny: $(jq -r '(.permissions.deny // []) | length' "$SHARED_SETTINGS" 2>/dev/null) 개 / allow: $(jq -r '(.permissions.allow // []) | length' "$SHARED_SETTINGS" 2>/dev/null) 개"
      else
        echo "  (jq 없음 — 'cctg common show' 로 확인)"
      fi
    else
      echo "  (아직 없음 — 첫 add/up 시 생성)"
    fi
    echo "  (telegram 플러그인은 전역 설치 필요: /plugin install telegram@claude-plugins-official)"
    ;;
  version|--version|-v)
    echo "$PROG $(cctg_version)"
    ;;
  help|--help|-h|"")
    usage
    ;;
  *)
    echo "ERROR: 알 수 없는 명령: $CMD"
    echo
    usage
    exit 1
    ;;
esac
