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

# ── 모듈 로드 ─────────────────────────────────────────────────────────────────
# cc-tg.sh 동반 파일(lib/·messages/)은 SCRIPT_DIR 옆에 놓인다(copy=libexec, dev=레포).
[ -n "${SCRIPT_DIR:-}" ] && [ -d "$SCRIPT_DIR/lib" ] || { printf 'cctg: lib/ 디렉터리를 런처 옆에서 찾지 못했습니다.\n' >&2; exit 1; }
# 정의·전역설정만 로드(함수 호출은 아래 init). 정의 전용이라 source 순서는 무관하다.
# shellcheck source=lib/env.sh
. "$SCRIPT_DIR/lib/env.sh"
# shellcheck source=lib/channels.sh
. "$SCRIPT_DIR/lib/channels.sh"
# shellcheck source=lib/output.sh
. "$SCRIPT_DIR/lib/output.sh"
# shellcheck source=lib/config.sh
. "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=lib/util.sh
. "$SCRIPT_DIR/lib/util.sh"
# shellcheck source=lib/registry.sh
. "$SCRIPT_DIR/lib/registry.sh"
# shellcheck source=lib/session.sh
. "$SCRIPT_DIR/lib/session.sh"
# shellcheck source=lib/commands.sh
. "$SCRIPT_DIR/lib/commands.sh"

# ── 초기화 ───────────────────────────────────────────────────────────────────
_load_messages
# 상태 루트·레지스트리 초기화 실패(권한·디스크)를 침묵하지 않는다 — 이후 모든 명령이 cryptic 하게 깨진다.
mkdir -p "$CHANNELS_DIR" || die ERR_ADD_WRITE "$CHANNELS_DIR"
[ -f "$REGISTRY" ] || printf '# name | working_dir | state_dir\n' > "$REGISTRY" || die ERR_ADD_WRITE "$REGISTRY"

CMD="${1:-}"
shift || true

# 서브커맨드 --help/-h 선검사: 인자 중 --help/-h 가 있으면 해당 sub_usage 출력 후 exit 0 (ADR-005).
# top-level `cctg --help` (CMD=""/"help") 는 아래 case 의 help 분기가 처리하므로 충돌 없음.
# 예외: `config <name> args <value>` 의 <value> 는 임의 문자열이므로(예: `args -h`,
# `args --help`) 선스캔 대상에서 제외한다 — 값으로 온 --help/-h 가 usage 를 가리지 않게.
case "$CMD" in
  config)
    if [ "${2:-}" = args ]; then
      # config <name> args 까지(=$1 $2)만 검사하고 $3(값)부터는 건너뛴다.
      case "${1:-}" in --help|-h) sub_usage config; exit 0 ;; esac
    else
      for _a in "$@"; do
        case "$_a" in --help|-h) sub_usage config; exit 0 ;; esac
      done
    fi ;;
  add|rm|rename|common|up|down|restart|status|logs|attach|lang|doctor|update|version|help)
    for _a in "$@"; do
      case "$_a" in --help|-h) sub_usage "$CMD"; exit 0 ;; esac
    done ;;
esac

case "$CMD" in
  add)                  cmd_add "$@" ;;
  rm)                   cmd_rm "$@" ;;
  rename)               cmd_rename "$@" ;;
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
