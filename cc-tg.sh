#!/usr/bin/env bash
# cc-tg.sh — 프로젝트별 Claude Code Telegram 채널 봇 런처
#
# 전역 봇(기본 상태 디렉터리 ~/.claude/channels/telegram/)은 건드리지 않는다.
# 프로젝트 봇은 각자 TELEGRAM_STATE_DIR(상태 디렉터리) + 토큰 + 작업 디렉터리를 갖는다.
#
# 사용법:
#   cc-tg.sh add <name> <working_dir>   # 새 프로젝트 봇 등록(상태 디렉터리·토큰 스캐폴딩·텔레그램ID 입력 → allowlist 자동 생성)
#   cc-tg.sh rm  <name> [--purge]       # 등록 해제(--purge: 상태 디렉터리까지 삭제)
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

CCTG_VERSION="0.1.0"
PROG="$(basename "$0")"
CHANNELS_DIR="${CC_CHANNELS_DIR:-$HOME/.claude/channels}"
REGISTRY="${CC_TG_REGISTRY:-$CHANNELS_DIR/projects.conf}"
PLUGIN="plugin:telegram@claude-plugins-official"
SESS_PREFIX="cctg-"

mkdir -p "$CHANNELS_DIR"
[ -f "$REGISTRY" ] || printf '# name | working_dir | state_dir\n' > "$REGISTRY"

usage() {
  cat <<EOF
사용법: $PROG <command> [args]
  add <name> <cwd>       프로젝트 봇 등록
  rm  <name> [--purge]   등록 해제 (--purge: 상태 디렉터리까지 삭제)
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

    # 5) 레지스트리 등록
    printf '%s | %s | %s\n' "$NAME" "$CWD" "$SD" >> "$REGISTRY"

    echo "등록 완료: $NAME → cwd=$CWD, state=$SD"
    echo "  allowlist에 $TGID 시드함 (페어링 불필요)"
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
      if is_running "$n"; then echo "  [RUNNING] $n  (tmux: $(sess_of "$n"))"
      else echo "  [stopped] $n"; fi
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
    echo "업데이트: $REPO  (mode=$MODE)"
    if ! git -C "$REPO" pull --ff-only; then
      echo "ERROR: git pull 실패 (로컬 변경이 있거나 fast-forward 불가). 레포에서 직접 확인하세요."
      exit 1
    fi
    if [ "$MODE" = "link" ]; then
      echo "심볼릭 설치이므로 cctg 가 이미 최신입니다."
    else
      BINDIR="${BINDIR:-$HOME/.local/bin}" "$REPO/install.sh"
    fi
    ;;
  doctor)
    echo "cctg doctor (v$CCTG_VERSION)"
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
    echo "  (telegram 플러그인은 전역 설치 필요: /plugin install telegram@claude-plugins-official)"
    ;;
  version|--version|-v)
    echo "$PROG $CCTG_VERSION"
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
