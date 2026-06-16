# lib/output.sh — i18n 언어결정·메시지 출력(cctg_lang/_load_messages/t/te/die)
# cc-tg.sh 가 런타임 source 하는 모듈(정의·전역설정 전용). 직접 실행하지 않는다.

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
    # 런타임 결정 경로 — 정적 추적 불가
    # shellcheck source=/dev/null
    . "$base"
  else
    printf 'cctg: warning: message catalog not found (messages/en.sh); output may show raw keys.\n' >&2
  fi
  lang="$(cctg_lang)"
  if [ "$lang" != "en" ]; then
    # shellcheck source=/dev/null
    sel="$(find_companion "messages/$lang.sh")" && . "$sel"
  fi
}
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
