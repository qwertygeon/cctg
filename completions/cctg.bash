# bash 자동완성 — cctg
# 설치: install.sh 가 ~/.local/share/bash-completion/completions/cctg 로 복사한다.
# macOS 기본 bash 3.2 호환을 위해 _init_completion 에 의존하지 않는다.

_cctg() {
  local cur prev cmd cmds names extra reg
  cur="${COMP_WORDS[COMP_CWORD]}"
  cmds="add rm rename up down restart status logs attach doctor update version help"
  reg="${CC_TG_REGISTRY:-${CC_CHANNELS_DIR:-$HOME/.claude/channels}/projects.conf}"

  # 첫 인자: 서브커맨드
  if [ "$COMP_CWORD" -eq 1 ]; then
    COMPREPLY=( $(compgen -W "$cmds" -- "$cur") )
    return
  fi

  cmd="${COMP_WORDS[1]}"
  case "$cmd" in
    rm|rename|up|down|restart|logs|attach)
      # 두 번째 인자: 등록된 봇 이름 (up/down/restart 는 all 도)
      # rename 의 세 번째 인자(new name)는 자유 입력이라 보완하지 않는다.
      if [ "$COMP_CWORD" -eq 2 ]; then
        names=$(awk -F'|' '/^[[:space:]]*#/{next}/^[[:space:]]*$/{next}{gsub(/^[ \t]+|[ \t]+$/,"",$1);print $1}' "$reg" 2>/dev/null)
        case "$cmd" in up|down|restart) extra="all" ;; *) extra="" ;; esac
        COMPREPLY=( $(compgen -W "$names $extra" -- "$cur") )
      fi
      ;;
    add)
      # add <name> <cwd> — 세 번째 인자는 디렉터리
      if [ "$COMP_CWORD" -eq 3 ]; then
        COMPREPLY=( $(compgen -d -- "$cur") )
      fi
      ;;
  esac
}
complete -F _cctg cctg
