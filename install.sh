#!/usr/bin/env bash
# install.sh — cctg 설치 스크립트
#
# git clone 후 이 스크립트를 실행하면:
#   1) 의존성(tmux, claude, caffeinate)을 점검하고
#   2) cc-tg.sh 를 설치 위치에 배치한 뒤
#   3) 셸 자동완성(bash/zsh)을 설치하고 cctg 명령으로 호출할 수 있게 한다.
#
# 두 가지 설치 모드:
#   copy (기본) — cc-tg.sh 를 ~/.local/bin/cctg 로 "복사"한다.
#                 레포와 분리되어 clone을 지우거나 옮겨도 동작한다(릴리스 방식).
#                 업데이트하려면 git pull 후 install.sh 를 다시 실행한다.
#   --dev/--link — ~/.local/bin/cctg 를 레포의 cc-tg.sh 로 "심볼릭 링크"한다.
#                 레포를 수정하면 즉시 반영된다(개발 방식). 레포 위치 고정 필요.
#
# 사용법:
#   ./install.sh                 # 복사 설치 (릴리스)
#   ./install.sh --dev           # 심볼릭 링크 설치 (개발)
#   ./install.sh --no-completions # 자동완성 설치 생략
#   BINDIR=~/bin ./install.sh    # 설치 위치 변경
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
MODE="copy"
COMPLETIONS=1

for arg in "$@"; do
  case "$arg" in
    --dev|--link)     MODE="link" ;;
    --copy)           MODE="copy" ;;
    --no-completions) COMPLETIONS=0 ;;
    -h|--help)
      awk 'NR==1{next} /^#/{sub(/^# ?/,"");print;next} {exit}' "$0"
      exit 0 ;;
    *) printf 'ERROR: 알 수 없는 옵션: %s\n' "$arg" >&2; exit 1 ;;
  esac
done

err() { printf '\033[31mERROR:\033[0m %s\n' "$1" >&2; }
ok()  { printf '\033[32m  ok\033[0m  %s\n' "$1"; }
warn(){ printf '\033[33m  warn\033[0m %s\n' "$1"; }

# 0) 원본 스크립트 존재 확인
[ -f "$SRC" ] || { err "cc-tg.sh 를 찾을 수 없습니다: $SRC"; exit 1; }

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

# 2) 설치 위치 준비. 기존 cctg(파일/링크 무엇이든)는 우리가 관리하는 이름이므로 갱신한다
mkdir -p "$BINDIR"
chmod +x "$SRC"
rm -f "$DEST"

# 3) 모드별 배치
if [ "$MODE" = "link" ]; then
  ln -sfn "$SRC" "$DEST"
  ok "심볼릭 링크(개발): $DEST -> $SRC"
else
  cp "$SRC" "$DEST"
  chmod +x "$DEST"
  ok "복사(릴리스): $DEST  (소스: $SRC)"
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
  fi
  if [ -f "$zsh_src" ] && mkdir -p "$zsh_dir" 2>/dev/null && cp "$zsh_src" "$zsh_dir/_cctg" 2>/dev/null; then
    ZSHCOMP="$zsh_dir/_cctg"; ok "zsh 자동완성: $ZSHCOMP"
    case ":$FPATH:" in
      *":$zsh_dir:"*) : ;;
      *) warn "zsh 에서 자동완성을 쓰려면 ~/.zshrc 에 다음을 추가하세요:"
         echo "    fpath=($zsh_dir \$fpath); autoload -Uz compinit && compinit" ;;
    esac
  fi
fi

# 3-2) 설치 매니페스트 기록 — `cctg update`/uninstall 이 위치·모드·설치물을 찾는 데 쓴다
mkdir -p "$CONFIG_DIR"
{
  printf 'repo=%s\n'     "$REPO_DIR"
  printf 'mode=%s\n'     "$MODE"
  printf 'bindir=%s\n'   "$BINDIR"
  printf 'bashcomp=%s\n' "$BASHCOMP"
  printf 'zshcomp=%s\n'  "$ZSHCOMP"
} > "$MANIFEST"
ok "매니페스트 기록: $MANIFEST"

# 4) PATH 점검 및 안내
case ":$PATH:" in
  *":$BINDIR:"*)
    ok "$BINDIR 가 이미 PATH에 있습니다"
    ;;
  *)
    warn "$BINDIR 가 PATH에 없습니다. 셸 설정 파일에 아래 줄을 추가하세요:"
    case "${SHELL##*/}" in
      zsh)  echo "    echo 'export PATH=\"$BINDIR:\$PATH\"' >> ~/.zshrc && source ~/.zshrc" ;;
      bash) echo "    echo 'export PATH=\"$BINDIR:\$PATH\"' >> ~/.bash_profile && source ~/.bash_profile" ;;
      *)    echo "    export PATH=\"$BINDIR:\$PATH\"" ;;
    esac
    ;;
esac

echo
echo "설치 완료($MODE). 새 터미널을 열거나 셸을 다시 로드한 뒤 확인하세요:"
echo "    cctg doctor"
