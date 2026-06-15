#!/usr/bin/env bash
# cc-tg.sh — 프로젝트별 Claude Code Telegram 채널 봇 런처
#
# 전역 봇(기본 상태 디렉터리 ~/.claude/channels/telegram/)은 건드리지 않는다.
# 프로젝트 봇은 각자 TELEGRAM_STATE_DIR(상태 디렉터리) + 토큰 + 작업 디렉터리를 갖는다.
#
# 사용법:
#   cc-tg.sh add <name> <working_dir>   # 새 프로젝트 봇 등록(상태 디렉터리·토큰 스캐폴딩·텔레그램ID 입력 → allowlist 자동 생성)
#   cc-tg.sh up  <name|all>             # 봇 기동(detached tmux + caffeinate)
#   cc-tg.sh down <name|all>            # 봇 정지
#   cc-tg.sh status                     # 등록/실행 상태 보기
#   cc-tg.sh attach <name>              # 해당 세션에 붙어서 로그 확인
#
# 의존성: tmux, claude(CLI), caffeinate(macOS). 플러그인은 전역 설치되어 있어야 함:
#   /plugin install telegram@claude-plugins-official

set -uo pipefail

CHANNELS_DIR="${CC_CHANNELS_DIR:-$HOME/.claude/channels}"
REGISTRY="${CC_TG_REGISTRY:-$CHANNELS_DIR/projects.conf}"
PLUGIN="plugin:telegram@claude-plugins-official"
SESS_PREFIX="cctg-"

mkdir -p "$CHANNELS_DIR"
[ -f "$REGISTRY" ] || printf '# name | working_dir | state_dir\n' > "$REGISTRY"

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

up_one() {
  local name="$1" cwd sd row
  row="$(lookup "$name")" || { echo "ERROR: 등록되지 않은 프로젝트: $name"; return 1; }
  cwd="$(expand "$(cut -f1 <<<"$row")")"
  sd="$(expand "$(cut -f2 <<<"$row")")"
  [ -d "$cwd" ] || { echo "ERROR: 작업 디렉터리 없음: $cwd"; return 1; }
  [ -f "$sd/.env" ] || { echo "ERROR: 토큰 파일 없음: $sd/.env (먼저 add 하세요)"; return 1; }
  if is_running "$name"; then echo "이미 실행 중: $name"; return 0; fi

  # 상태 디렉터리/토큰을 분리 주입하고 caffeinate로 sleep 방지하며 채널 세션 기동
  local launch="cd $(printf '%q' "$cwd") \
&& export TELEGRAM_STATE_DIR=$(printf '%q' "$sd") \
&& set -a && source $(printf '%q' "$sd/.env") && set +a \
&& caffeinate -is claude --channels $PLUGIN; exec bash"

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

    # 5) 레지스트리 등록
    printf '%s | %s | %s\n' "$NAME" "$CWD" "$SD" >> "$REGISTRY"

    echo "등록 완료: $NAME → cwd=$CWD, state=$SD"
    echo "  allowlist에 $TGID 시드함 (페어링 불필요)"
    echo "다음: cc-tg.sh up $NAME  → 봇에 DM하면 바로 응답합니다."
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
  status)
    echo "전역 봇: $CHANNELS_DIR/telegram (이 스크립트는 관리하지 않음)"
    echo "--- 프로젝트 봇 ---"
    found=0
    while IFS= read -r n; do
      [ -z "$n" ] && continue; found=1
      if is_running "$n"; then echo "  [RUNNING] $n  (tmux: $(sess_of "$n"))"
      else echo "  [stopped] $n"; fi
    done < <(all_names)
    [ "$found" = 0 ] && echo "  (등록된 프로젝트 봇 없음)"
    ;;
  attach)
    NAME="${1:?name 필요}"
    tmux attach -t "$(sess_of "$NAME")"
    ;;
  *)
    echo "사용법: cc-tg.sh {add <name> <cwd>|up <name|all>|down <name|all>|status|attach <name>}"
    exit 1
    ;;
esac
