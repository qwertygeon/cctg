#!/usr/bin/env bash
# uninstall.sh — cctg 제거
#
# copy/link 어느 모드로 설치했든 ~/.local/bin/cctg 와 자동완성 파일을 제거한다.
# 레지스트리·상태 디렉터리(~/.claude/channels/)는 건드리지 않으므로
# 데이터 손실 없이 재설치 가능하다.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO_DIR/cc-tg.sh"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/cctg"
MANIFEST="$CONFIG_DIR/install.conf"

# 매니페스트에서 설치 경로를 읽는다 (copy 설치는 bin 이 libexec/cc-tg.sh 로의 심볼릭).
BINDIR_M=""
LIBEXECDIR_M=""
ALIAS_M=""
if [ -f "$MANIFEST" ]; then
  BINDIR_M="$(awk -F= '$1=="bindir"{print substr($0,index($0,"=")+1)}' "$MANIFEST")"
  LIBEXECDIR_M="$(awk -F= '$1=="libexecdir"{print substr($0,index($0,"=")+1)}' "$MANIFEST")"
  ALIAS_M="$(awk -F= '$1=="alias"{print substr($0,index($0,"=")+1)}' "$MANIFEST")"
fi
# BINDIR 우선순위: 환경변수 > 매니페스트 bindir= > 기본값
BINDIR="${BINDIR:-${BINDIR_M:-$HOME/.local/bin}}"
DEST="$BINDIR/cctg"

if [ -L "$DEST" ]; then
  # 심볼릭 설치 — dev(레포 cc-tg.sh) 또는 copy(libexec/cc-tg.sh) 둘 다 우리 링크인지 확인 후 제거
  target="$(readlink "$DEST")"
  if [ "$target" = "$SRC" ] || { [ -n "$LIBEXECDIR_M" ] && [ "$target" = "$LIBEXECDIR_M/cc-tg.sh" ]; }; then
    rm "$DEST"; echo "제거됨(링크): $DEST"
  else
    echo "건너뜀: $DEST 는 다른 대상($target)을 가리킵니다. 직접 확인하세요."; exit 1
  fi
elif [ -f "$DEST" ]; then
  # 복사(릴리스) 설치 — cc-tg.sh 헤더의 프로젝트 정체성 문자열로 우리 파일인지 확인 후 제거
  if grep -q 'CCTG (Claude Code Tmux Gateway)' "$DEST" 2>/dev/null; then
    rm "$DEST"; echo "제거됨(복사본): $DEST"
  else
    echo "건너뜀: $DEST 는 cctg 가 설치한 파일이 아닌 것 같습니다. 직접 확인하세요."; exit 1
  fi
else
  echo "설치된 cctg 없음: $DEST"
fi

# 별칭(opt-in) bin 제거 — 우리 대상(레포 cc-tg.sh 또는 libexec/cc-tg.sh)을 가리키는 심볼릭만 제거한다.
if [ -n "$ALIAS_M" ]; then
  ALIAS_DEST="$BINDIR/$ALIAS_M"
  if [ -L "$ALIAS_DEST" ]; then
    atarget="$(readlink "$ALIAS_DEST")"
    if [ "$atarget" = "$SRC" ] || { [ -n "$LIBEXECDIR_M" ] && [ "$atarget" = "$LIBEXECDIR_M/cc-tg.sh" ]; }; then
      rm "$ALIAS_DEST"; echo "제거됨(별칭): $ALIAS_DEST"
    else
      echo "건너뜀: $ALIAS_DEST 는 다른 대상($atarget)을 가리킵니다. 직접 확인하세요."
    fi
  elif [ -e "$ALIAS_DEST" ]; then
    echo "건너뜀: $ALIAS_DEST 는 심볼릭이 아닙니다. 직접 확인하세요."
  fi
fi

# libexec 패키지 디렉터리 제거 (copy 설치 — 우리 cc-tg.sh 가 든 디렉터리만)
if [ -n "$LIBEXECDIR_M" ] && [ -d "$LIBEXECDIR_M" ]; then
  if grep -q 'CCTG (Claude Code Tmux Gateway)' "$LIBEXECDIR_M/cc-tg.sh" 2>/dev/null; then
    rm -rf "$LIBEXECDIR_M"; echo "제거됨(libexec): $LIBEXECDIR_M"
  else
    echo "건너뜀: $LIBEXECDIR_M 는 cctg libexec 가 아닌 것 같습니다. 직접 확인하세요."
  fi
fi

# 자동완성 파일 제거 (매니페스트에 기록된 경로만)
if [ -f "$MANIFEST" ]; then
  for key in bashcomp zshcomp; do
    p="$(awk -F= -v k="$key" '$1==k{print substr($0,index($0,"=")+1)}' "$MANIFEST")"
    [ -n "$p" ] && [ -f "$p" ] && rm -f "$p" && echo "제거됨(자동완성): $p"
  done

  # 셸 rc 의 cctg 관리 블록 제거 (마커 사이만 삭제, 나머지는 보존)
  MARK_BEGIN="# >>> cctg >>>"
  MARK_END="# <<< cctg <<<"
  rcs="$(awk -F= '$1=="shellrc"{print substr($0,index($0,"=")+1)}' "$MANIFEST")"
  if [ -n "$rcs" ]; then
    IFS=','
    for f in $rcs; do
      [ -f "$f" ] || continue
      if grep -qF "$MARK_BEGIN" "$f"; then
        tmp="$(mktemp)"
        awk -v b="$MARK_BEGIN" -v e="$MARK_END" 'BEGIN{s=0} $0==b{s=1;next} s&&$0==e{s=0;next} !s{print}' "$f" > "$tmp" && mv "$tmp" "$f"
        echo "제거됨(셸 블록): $f"
      fi
      # install.sh 가 만든 rc 백업 제거 (DEC-002: 삭제하고 안내)
      [ -f "$f.cctg-bak" ] && rm -f "$f.cctg-bak" && echo "제거됨(rc 백업): $f.cctg-bak (필요 시 재설치 전 직접 백업 권장)"
    done
    unset IFS
  fi
fi

# cctg 설정 디렉터리 정리 — 상태 디렉터리(~/.claude/channels/)는 보존하고,
# 도구 메타데이터(언어 설정·설치 매니페스트)만 제거해 깨끗한 언인스톨로 만든다.
[ -f "$CONFIG_DIR/config" ] && rm -f "$CONFIG_DIR/config" && echo "제거됨(언어 설정): $CONFIG_DIR/config"
[ -f "$MANIFEST" ] && rm -f "$MANIFEST" && echo "제거됨(매니페스트): $MANIFEST"
[ -d "$CONFIG_DIR" ] && rmdir "$CONFIG_DIR" 2>/dev/null && echo "제거됨(설정 디렉터리): $CONFIG_DIR" || true
