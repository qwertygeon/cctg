#!/usr/bin/env bash
# install.sh — cctg 설치 스크립트
#
# git clone 후 이 스크립트를 실행하면:
#   1) 의존성(tmux, claude, caffeinate)을 점검하고
#   2) cc-tg.sh 를 설치 위치에 배치한 뒤
#   3) 셸 자동완성(bash/zsh)을 설치하고
#   4) 셸 rc(.zshrc/.bashrc 등)에 PATH·자동완성 활성화 블록을 멱등하게 추가한다.
#
# 두 가지 설치 모드:
#   copy (기본) — cc-tg.sh 를 ~/.local/bin/cctg 로 "복사"한다.
#                 레포와 분리되어 clone을 지우거나 옮겨도 동작한다(릴리스 방식).
#                 업데이트하려면 git pull 후 install.sh 를 다시 실행한다.
#   --dev/--link — ~/.local/bin/cctg 를 레포의 cc-tg.sh 로 "심볼릭 링크"한다.
#                 레포를 수정하면 즉시 반영된다(개발 방식). 레포 위치 고정 필요.
#
# 사용법:
#   ./install.sh                  # 복사 설치 (릴리스)
#   ./install.sh --dev            # 심볼릭 링크 설치 (개발)
#   ./install.sh --no-completions # 자동완성 설치 생략
#   ./install.sh --no-shell-setup # 셸 rc 자동 설정 생략
#   ./install.sh --lang en|ko     # CLI 출력 언어 시드(미지정 시 로케일 자동 감지)
#   ./install.sh                  # 짧은 별칭 명령 'cg' 가 기본으로 함께 설치된다(자동완성 포함)
#   ./install.sh --alias=NAME     # 별칭 이름을 NAME 으로 지정
#   ./install.sh --no-alias       # 별칭을 설치하지 않는다(있으면 제거)
#   BINDIR=~/bin ./install.sh     # 설치 위치 변경
#
# 별칭은 기본 활성(이름 'cg')이며, 끄려면 --no-alias 를 준다. 선택한 이름은
# 매니페스트에 기록된다. `cctg update` 의 별칭 처리 정책은 cmd_update 참조
# (옵션 없으면 기존 별칭 유지, --no-alias 로 제거).
#
# 재실행해도 안전하다(idempotent). 기존 cctg 는 갱신된다.

set -euo pipefail

# 레포 위치(이 스크립트의 절대 경로 기준) — clone 위치가 어디든 정확히 가리킨다
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO_DIR/cc-tg.sh"
BINDIR="${BINDIR:-$HOME/.local/bin}"
DEST="$BINDIR/cctg"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/cctg"
MANIFEST="$CONFIG_DIR/install.conf"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
# copy 설치 시 패키지 본체(cc-tg.sh·VERSION·messages/)를 두는 libexec 디렉터리.
# bin 에는 이 안의 cc-tg.sh 로 향하는 심볼릭만 노출한다(Homebrew식). dev 설치는 사용하지 않는다.
LIBEXECDIR="${CCTG_LIBEXEC:-$HOME/.local/libexec/cctg}"
MODE="copy"
COMPLETIONS=1
SHELL_SETUP=1
MARK_BEGIN="# >>> cctg >>>"
MARK_END="# <<< cctg <<<"

# 별칭 모드. ""(미지정)=기본 'cg' 설치 | cg | name(:_alias_name) | none(설치 안 함/제거) |
# keep(매니페스트 alias= 를 그대로 승계 — `cctg update` 가 별칭을 바꾸지 않을 때 쓰는 내부 모드).
DEFAULT_ALIAS="cg"
_alias_mode=""
_alias_name=""

LANG_OPT=""
_expect_lang=0
for arg in "$@"; do
  if [ "$_expect_lang" = 1 ]; then LANG_OPT="$arg"; _expect_lang=0; continue; fi
  case "$arg" in
    --dev|--link)      MODE="link" ;;
    --copy)            MODE="copy" ;;
    --no-completions)  COMPLETIONS=0 ;;
    --no-shell-setup)  SHELL_SETUP=0 ;;
    --lang)            _expect_lang=1 ;;
    --lang=*)          LANG_OPT="${arg#--lang=}" ;;
    --alias)           _alias_mode="cg" ;;
    --alias=*)         _alias_mode="name"; _alias_name="${arg#--alias=}" ;;
    --no-alias)        _alias_mode="none" ;;
    --alias-keep)      _alias_mode="keep" ;;
    -h|--help)
      awk 'NR==1{next} /^#/{sub(/^# ?/,"");print;next} {exit}' "$0"
      exit 0 ;;
    *) printf 'ERROR: 알 수 없는 옵션: %s\n' "$arg" >&2; exit 1 ;;
  esac
done
[ "$_expect_lang" = 1 ] && { printf 'ERROR: --lang 뒤에 값(en|ko)이 필요합니다\n' >&2; exit 1; }

# rc 파일에 cctg 관리 블록을 멱등하게 기록한다. 기존 블록은 교체, 최초 1회 .cctg-bak 백업.
ensure_block() {
  local file="$1" body="$2" tmp
  mkdir -p "$(dirname "$file")"
  if [ -f "$file" ] && ! grep -qF "$MARK_BEGIN" "$file"; then
    cp "$file" "$file.cctg-bak"
  fi
  tmp="$(mktemp)"
  if [ -f "$file" ]; then
    awk -v b="$MARK_BEGIN" -v e="$MARK_END" 'BEGIN{s=0} $0==b{s=1;next} s&&$0==e{s=0;next} !s{print}' "$file" > "$tmp"
  fi
  {
    cat "$tmp" 2>/dev/null
    printf '%s\n' "$MARK_BEGIN"
    printf '%s\n' "$body"
    printf '%s\n' "$MARK_END"
  } > "$file"
  rm -f "$tmp"
}

err() { printf '\033[31mERROR:\033[0m %s\n' "$1" >&2; }
ok()  { printf '\033[32m  ok\033[0m  %s\n' "$1"; }
warn(){ printf '\033[33m  warn\033[0m %s\n' "$1"; }

# 0) 원본 스크립트·VERSION 확인
[ -f "$SRC" ] || { err "cc-tg.sh 를 찾을 수 없습니다: $SRC"; exit 1; }
VER="$(head -n1 "$REPO_DIR/VERSION" 2>/dev/null || true)"
[ -n "$VER" ] || { err "VERSION 파일을 읽을 수 없습니다: $REPO_DIR/VERSION"; exit 1; }

# 1) 의존성 점검 (claude/tmux 는 필수, caffeinate 는 macOS 전용)
echo "의존성 점검:"
missing=0
for dep in tmux claude; do
  if command -v "$dep" >/dev/null 2>&1; then
    ok "$dep ($(command -v "$dep"))"
  else
    err "$dep 가 설치되어 있지 않습니다 (PATH에 없음)"
    missing=1
  fi
done
if command -v caffeinate >/dev/null 2>&1; then
  ok "caffeinate"
else
  warn "caffeinate 없음 — macOS가 아니거나 sleep 방지 기능을 쓸 수 없습니다"
fi
[ "$missing" = 0 ] || { err "필수 의존성을 먼저 설치하세요. 설치를 중단합니다."; exit 1; }

# 1-1) 별칭 결정. 기존 매니페스트의 alias= 를 읽어두고(이전 별칭 정리·keep 승계에 사용),
#      모드에 따라 최종 별칭 이름을 정한다. 미지정(직접 install 실행)은 기본 'cg'.
OLD_ALIAS=""
[ -f "$MANIFEST" ] && OLD_ALIAS="$(awk -F= '$1=="alias"{print substr($0,index($0,"=")+1)}' "$MANIFEST" 2>/dev/null || true)"
case "$_alias_mode" in
  cg)   ALIAS="$DEFAULT_ALIAS" ;;
  name) ALIAS="$_alias_name" ;;
  none) ALIAS="" ;;
  keep) ALIAS="$OLD_ALIAS" ;;
  "")   ALIAS="$DEFAULT_ALIAS" ;;
esac
if [ -n "$ALIAS" ]; then
  case "$ALIAS" in
    cctg) err "별칭 이름으로 'cctg' 는 쓸 수 없습니다."; exit 1 ;;
    *[!A-Za-z0-9_-]*|-*) err "별칭 이름이 올바르지 않습니다: '$ALIAS' (영문/숫자/_/-, 첫 글자는 -, 불가)"; exit 1 ;;
  esac
fi

# 2) 설치 위치 준비. 기존 cctg(파일/링크 무엇이든)는 우리가 관리하는 이름이므로 갱신한다
mkdir -p "$BINDIR"
chmod +x "$SRC"
rm -f "$DEST"

# 3) 모드별 배치
#   link(dev): bin → 레포의 cc-tg.sh 직접 심볼릭. 동반 파일은 레포에서 읽힌다.
#   copy(릴리스): 패키지를 libexec 로 복사하고 bin → libexec/cc-tg.sh 심볼릭.
#                 동반 파일(VERSION·messages/)이 cc-tg.sh 옆에 함께 복사되어, 레포를 지워도 동작한다.
LIBEXEC_INSTALLED=""
BIN_TARGET=""
if [ "$MODE" = "link" ]; then
  ln -sfn "$SRC" "$DEST"
  BIN_TARGET="$SRC"
  ok "심볼릭 링크(개발): $DEST -> $SRC"
else
  mkdir -p "$LIBEXECDIR"
  cp "$SRC" "$LIBEXECDIR/cc-tg.sh"
  chmod +x "$LIBEXECDIR/cc-tg.sh"
  cp "$REPO_DIR/VERSION" "$LIBEXECDIR/VERSION"
  # lib/ 모듈(필수) 동반 복사 — cc-tg.sh 가 SCRIPT_DIR/lib 에서 source 한다.
  if [ -d "$REPO_DIR/lib" ]; then
    rm -rf "${LIBEXECDIR:?}/lib"
    cp -R "$REPO_DIR/lib" "$LIBEXECDIR/lib"
  fi
  # i18n 메시지 카탈로그(있으면) 동반 복사 — cc-tg.sh 가 SCRIPT_DIR 기준으로 source 한다.
  if [ -d "$REPO_DIR/messages" ]; then
    rm -rf "$LIBEXECDIR/messages"
    cp -R "$REPO_DIR/messages" "$LIBEXECDIR/messages"
  fi
  ln -sfn "$LIBEXECDIR/cc-tg.sh" "$DEST"
  BIN_TARGET="$LIBEXECDIR/cc-tg.sh"
  LIBEXEC_INSTALLED="$LIBEXECDIR"
  ok "복사(릴리스): $LIBEXECDIR  (bin 심볼릭: $DEST)"
fi

# 3-0) 별칭(opt-in) bin 심볼릭 처리.
#   - 이전 별칭이 다른 이름으로 바뀌었거나(--alias=NEW) 제거(--no-alias)되면, 이전 별칭 심볼릭을 정리한다.
#   - 우리 대상(BIN_TARGET) 을 가리키는 심볼릭만 건드린다(사용자의 다른 파일은 보존).
_remove_alias_link() {  # $1=별칭 이름
  local p="$BINDIR/$1"
  if [ -L "$p" ]; then
    rm -f "$p"; ok "별칭 제거: $p"
  elif [ -e "$p" ]; then
    warn "별칭 정리 건너뜀: $p 는 심볼릭이 아닙니다(직접 확인하세요)."
  fi
}
if [ -n "$OLD_ALIAS" ] && [ "$OLD_ALIAS" != "$ALIAS" ]; then
  _remove_alias_link "$OLD_ALIAS"
fi
if [ -n "$ALIAS" ]; then
  ap="$BINDIR/$ALIAS"
  if [ -e "$ap" ] && [ ! -L "$ap" ]; then
    err "별칭 '$ALIAS' 생성 실패: $ap 가 이미 존재하며 심볼릭이 아닙니다. 다른 이름(--alias=NAME)을 쓰세요."; exit 1
  fi
  ln -sfn "$BIN_TARGET" "$ap"
  ok "별칭 명령: $ap -> $BIN_TARGET"
  # $BINDIR 밖의 동명 명령을 가리는지 안내(우리 $BINDIR 가 PATH 앞쪽이면 별칭이 우선).
  existing="$(command -v "$ALIAS" 2>/dev/null || true)"
  case "$existing" in
    ""|"$ap") ;;
    *) warn "'$ALIAS' 는 기존 명령($existing)과 이름이 겹칩니다. PATH 에서 $BINDIR 가 앞서면 별칭이 우선합니다." ;;
  esac
fi

# 3-1) 셸 자동완성 설치 (bash/zsh). 실패해도 설치 전체는 중단하지 않는다.
BASHCOMP=""; ZSHCOMP=""
if [ "$COMPLETIONS" = 1 ]; then
  bash_src="$REPO_DIR/completions/cctg.bash"
  zsh_src="$REPO_DIR/completions/_cctg"
  bash_dir="$DATA_DIR/bash-completion/completions"
  zsh_dir="$DATA_DIR/zsh/site-functions"
  if [ -f "$bash_src" ] && mkdir -p "$bash_dir" 2>/dev/null && cp "$bash_src" "$bash_dir/cctg" 2>/dev/null; then
    BASHCOMP="$bash_dir/cctg"; ok "bash 자동완성: $BASHCOMP"
    # 별칭에도 동일 완성 함수 등록(파일은 rc 에서 직접 source 되므로 한 줄 추가로 충분).
    [ -n "$ALIAS" ] && printf 'complete -F _cctg %s\n' "$ALIAS" >> "$BASHCOMP" && ok "bash 자동완성(별칭): $ALIAS"
  fi
  if [ -f "$zsh_src" ] && mkdir -p "$zsh_dir" 2>/dev/null && cp "$zsh_src" "$zsh_dir/_cctg" 2>/dev/null; then
    ZSHCOMP="$zsh_dir/_cctg"; ok "zsh 자동완성: $ZSHCOMP"
    # 별칭을 #compdef 태그에 추가(compinit 이 _cctg 함수를 cctg·별칭 모두에 연결).
    if [ -n "$ALIAS" ]; then
      ztmp="$(mktemp)"
      awk -v a="$ALIAS" 'NR==1{print "#compdef cctg " a; next} {print}' "$ZSHCOMP" > "$ztmp" && mv "$ztmp" "$ZSHCOMP"
      ok "zsh 자동완성(별칭): $ALIAS"
    fi
  fi
fi

# 3-2) 셸 통합 자동 설정 — PATH + 자동완성 활성화를 rc 파일에 멱등 기록
SHELLRC=""
if [ "$SHELL_SETUP" = 1 ]; then
  zsh_dir="$DATA_DIR/zsh/site-functions"
  bash_comp="$DATA_DIR/bash-completion/completions/cctg"
  # rc 에 들어갈 본문. \$ 는 런타임 확장(쉘 시작 시), $BINDIR 등은 지금 확장.
  zsh_body="case \":\$PATH:\" in *\":$BINDIR:\"*) ;; *) export PATH=\"$BINDIR:\$PATH\" ;; esac
fpath=($zsh_dir \$fpath)
autoload -Uz compinit && compinit"
  bash_body="case \":\$PATH:\" in *\":$BINDIR:\"*) ;; *) export PATH=\"$BINDIR:\$PATH\" ;; esac
[ -f \"$bash_comp\" ] && source \"$bash_comp\""

  files=""
  case "${SHELL##*/}" in
    zsh)  files="$HOME/.zshrc" ;;
    bash) files="$HOME/.bashrc $HOME/.bash_profile" ;;
  esac
  if [ -z "$files" ]; then
    warn "알 수 없는 셸(${SHELL##*/}). rc 자동 설정 생략. 수동: export PATH=\"$BINDIR:\$PATH\""
  else
    for f in $files; do
      case "$f" in
        *zshrc) ensure_block "$f" "$zsh_body" ;;
        *)      ensure_block "$f" "$bash_body" ;;
      esac
      SHELLRC="${SHELLRC:+$SHELLRC,}$f"
      ok "셸 설정 반영: $f (cctg 관리 블록)"
    done
    warn "적용하려면 새 터미널을 열거나 'source <rc>' 하세요."
  fi
else
  case ":$PATH:" in
    *":$BINDIR:"*) ok "$BINDIR 가 이미 PATH에 있습니다" ;;
    *) warn "$BINDIR 가 PATH에 없음(셸 자동설정 생략). 수동: export PATH=\"$BINDIR:\$PATH\"" ;;
  esac
fi

# 3-3) 설치 매니페스트 기록 — `cctg update`/uninstall 이 위치·모드·설치물을 찾는 데 쓴다
mkdir -p "$CONFIG_DIR"
{
  printf 'repo=%s\n'      "$REPO_DIR"
  printf 'mode=%s\n'      "$MODE"
  printf 'version=%s\n'   "$VER"
  printf 'bindir=%s\n'    "$BINDIR"
  printf 'libexecdir=%s\n' "$LIBEXEC_INSTALLED"
  printf 'bashcomp=%s\n'  "$BASHCOMP"
  printf 'zshcomp=%s\n'   "$ZSHCOMP"
  printf 'shellrc=%s\n'   "$SHELLRC"
  printf 'alias=%s\n'     "$ALIAS"
} > "$MANIFEST"

# 3-4) CLI 출력 언어 시드 — 매니페스트와 분리된 사용자 설정 파일(update 가 보존).
#   --lang 지정 시 그 값으로(검증), 미지정 시 파일에 lang 이 없을 때만 로케일 자동 감지값으로 시드.
CFG_FILE="$CONFIG_DIR/config"
if [ -n "$LANG_OPT" ]; then
  case "$LANG_OPT" in
    en|ko) ;;
    *) err "지원하지 않는 언어: $LANG_OPT (en|ko)"; exit 1 ;;
  esac
  if [ -f "$CFG_FILE" ] && grep -qE '^lang=' "$CFG_FILE"; then
    ltmp="$(mktemp)"; awk -F= -v v="$LANG_OPT" '$1=="lang"{print "lang="v;next}{print}' "$CFG_FILE" > "$ltmp" && mv "$ltmp" "$CFG_FILE"
  else
    printf 'lang=%s\n' "$LANG_OPT" >> "$CFG_FILE"
  fi
  ok "언어 설정: $LANG_OPT ($CFG_FILE)"
elif [ ! -f "$CFG_FILE" ] || ! grep -qE '^lang=' "$CFG_FILE"; then
  case "${LC_ALL:-${LANG:-}}" in ko*|*_KR*) seed_lang=ko ;; *) seed_lang=en ;; esac
  printf 'lang=%s\n' "$seed_lang" >> "$CFG_FILE"
  ok "언어 자동 설정: $seed_lang ($CFG_FILE) — 'cctg lang <en|ko>' 로 변경 가능"
fi
ok "매니페스트 기록: $MANIFEST (v$VER)"

echo
echo "설치 완료(cctg v$VER, $MODE). 새 터미널을 열거나 셸을 다시 로드한 뒤 확인하세요:"
echo "    cctg doctor"
[ -n "$ALIAS" ] && echo "    $ALIAS doctor   # 별칭으로도 동일하게 동작합니다"
