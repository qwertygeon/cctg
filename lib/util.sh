# lib/util.sh — 버전·모드·jq·공통설정·usage·이름검증
# cc-tg.sh 가 런타임 source 하는 모듈(정의·전역설정 전용). 직접 실행하지 않는다.

# 버전 결정: (1) 동반 VERSION(레포/dev·libexec/copy) → (2) 매니페스트 version= → (3) 폴백
cctg_version() {
  local vf v
  vf="$(find_companion VERSION)" && { head -n1 "$vf"; return; }
  v="$(conf_get "${XDG_CONFIG_HOME:-$HOME/.config}/cctg/install.conf" version)"
  [ -n "$v" ] && { printf '%s\n' "$v"; return; }
  printf '%s\n' "$CCTG_VERSION_FALLBACK"
}
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

# 서브커맨드별 1행 사용법 출력(FR-005 / ADR-005). cc-tg.sh 에서 --help/-h 선검사 시 호출.
sub_usage() {
  case "$1" in
    add)     t USAGE_ADD     "$PROG" ;;
    rm)      t USAGE_RM      "$PROG" ;;
    rename)  t USAGE_RENAME  "$PROG" ;;
    config)  t USAGE_CONFIG  "$PROG" ;;
    common)  t USAGE_COMMON  "$PROG" ;;
    up)      t USAGE_UP      "$PROG" ;;
    down)    t USAGE_DOWN    "$PROG" ;;
    restart) t USAGE_RESTART "$PROG" ;;
    status)  t USAGE_STATUS  "$PROG" ;;
    logs)    t USAGE_LOGS    "$PROG" ;;
    attach)  t USAGE_ATTACH  "$PROG" ;;
    lang)    t USAGE_LANG    "$PROG" ;;
    doctor)  t USAGE_DOCTOR  "$PROG" ;;
    update)  t USAGE_UPDATE  "$PROG" ;;
    version) t USAGE_VERSION "$PROG" ;;
    help)    t USAGE_HELP    "$PROG" ;;
    *)       usage ;;
  esac
}

# 봇 이름 검증 — tmux 세션명·레지스트리(|) 충돌 방지를 위해 영숫자/_/- 만 허용
valid_name() { printf '%s' "$1" | grep -qE '^[A-Za-z0-9_-]+$'; }
