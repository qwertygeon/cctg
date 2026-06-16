#!/usr/bin/env bash
# check-i18n-keys.sh — 메시지 카탈로그 키 패리티 + 사용 키 검증
#
# 1) messages/*.sh 가 모두 en.sh 와 동일한 CCTG_MSG_* 키 집합을 갖는지(번역 누락/잉여 방지)
# 2) cc-tg.sh 에서 t()/te()/die() 로 참조하는 키가 모두 en.sh 에 정의돼 있는지
#
# CI(예: GitHub Actions)나 로컬에서 실행한다. 실패 시 비정상 종료(코드 1).

set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MSG_DIR="$REPO_DIR/messages"
# 키 참조 스캔 소스: 진입점 + lib/ 모듈(명령 구현이 lib/commands.sh 등으로 분리됨)
SRCS=("$REPO_DIR/cc-tg.sh")
[ -d "$REPO_DIR/lib" ] && SRCS+=("$REPO_DIR"/lib/*.sh)
fail=0

keys_of() { grep -oE '^CCTG_MSG_[A-Z0-9_]+' "$1" | sort -u; }

[ -f "$MSG_DIR/en.sh" ] || { echo "ERROR: $MSG_DIR/en.sh 없음"; exit 1; }
base_keys="$(keys_of "$MSG_DIR/en.sh")"

# 1) 카탈로그 간 키 패리티 (en.sh 기준)
for cat in "$MSG_DIR"/*.sh; do
  [ "$cat" = "$MSG_DIR/en.sh" ] && continue
  ck="$(keys_of "$cat")"
  miss="$(comm -23 <(printf '%s\n' "$base_keys") <(printf '%s\n' "$ck"))"
  extra="$(comm -13 <(printf '%s\n' "$base_keys") <(printf '%s\n' "$ck"))"
  if [ -n "$miss" ]; then echo "ERROR: $(basename "$cat") 에 누락된 키:"; printf '  %s\n' $miss; fail=1; fi
  if [ -n "$extra" ]; then echo "ERROR: $(basename "$cat") 에 en.sh 에 없는 키:"; printf '  %s\n' $extra; fail=1; fi
done

# 2) 소스(cc-tg.sh + lib/*.sh)에서 참조하는 키가 en.sh 에 정의됐는지
#    t KEY / te KEY / die KEY 형태의 첫 인자(대문자 키)를 추출
used="$(grep -ohE '\b(t|te|die) [A-Z][A-Z0-9_]+' "${SRCS[@]}" | awk '{print "CCTG_MSG_"$2}' | sort -u)"
defined="$(printf '%s\n' "$base_keys")"
undef="$(comm -23 <(printf '%s\n' "$used") <(printf '%s\n' "$defined"))"
if [ -n "$undef" ]; then echo "ERROR: 소스가 참조하지만 en.sh 에 없는 키:"; printf '  %s\n' $undef; fail=1; fi

if [ "$fail" = 0 ]; then
  echo "OK: 카탈로그 키 패리티·참조 키 모두 정상 ($(printf '%s\n' "$base_keys" | wc -l | tr -d ' ') 키)"
fi
exit "$fail"
