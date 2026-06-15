#!/usr/bin/env bash
# uninstall.sh — cctg 제거
#
# copy/link 어느 모드로 설치했든 ~/.local/bin/cctg 와 자동완성 파일을 제거한다.
# 레지스트리·상태 디렉터리(~/.claude/channels/)는 건드리지 않으므로
# 데이터 손실 없이 재설치 가능하다.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO_DIR/cc-tg.sh"
BINDIR="${BINDIR:-$HOME/.local/bin}"
DEST="$BINDIR/cctg"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/cctg"
MANIFEST="$CONFIG_DIR/install.conf"

if [ -L "$DEST" ]; then
  # 링크(개발) 설치 — 이 레포가 만든 링크인지 확인 후 제거
  target="$(readlink "$DEST")"
  if [ "$target" = "$SRC" ]; then
    rm "$DEST"; echo "제거됨(링크): $DEST"
  else
    echo "건너뜀: $DEST 는 다른 대상($target)을 가리킵니다. 직접 확인하세요."; exit 1
  fi
elif [ -f "$DEST" ]; then
  # 복사(릴리스) 설치 — cc-tg.sh 헤더 시그니처로 우리 파일인지 확인 후 제거
  if grep -q 'cc-tg.sh — 프로젝트별 Claude Code Telegram 채널 봇 런처' "$DEST" 2>/dev/null; then
    rm "$DEST"; echo "제거됨(복사본): $DEST"
  else
    echo "건너뜀: $DEST 는 cctg 가 설치한 파일이 아닌 것 같습니다. 직접 확인하세요."; exit 1
  fi
else
  echo "설치된 cctg 없음: $DEST"
fi

# 자동완성 파일 제거 (매니페스트에 기록된 경로만)
if [ -f "$MANIFEST" ]; then
  for key in bashcomp zshcomp; do
    p="$(awk -F= -v k="$key" '$1==k{print substr($0,index($0,"=")+1)}' "$MANIFEST")"
    [ -n "$p" ] && [ -f "$p" ] && rm -f "$p" && echo "제거됨(자동완성): $p"
  done
fi
