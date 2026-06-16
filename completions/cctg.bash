# bash 자동완성 — cctg
# 설치: install.sh 가 ~/.local/share/bash-completion/completions/cctg 로 복사한다.
# macOS 기본 bash 3.2 호환을 위해 _init_completion 에 의존하지 않는다.

_cctg() {
  local cur prev cmd cmds names extra reg
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  cmds="add rm rename config common up down restart status logs attach lang doctor update version help"
  reg="${CC_TG_REGISTRY:-${CC_CHANNELS_DIR:-$HOME/.claude/channels}/projects.conf}"

  # 첫 인자: 서브커맨드
  if [ "$COMP_CWORD" -eq 1 ]; then
    COMPREPLY=( $(compgen -W "$cmds" -- "$cur") )
    return
  fi

  cmd="${COMP_WORDS[1]}"
  case "$cmd" in
    rm|rename|config|up|down|restart|logs|attach)
      # 두 번째 인자: 등록된 봇 이름 (up/down/restart 는 all 도)
      # rename 의 세 번째(new name)·config 의 인자는 자유 입력이라 보완하지 않는다.
      if [ "$COMP_CWORD" -eq 2 ]; then
        names=$(awk -F'|' '/^[[:space:]]*#/{next}/^[[:space:]]*$/{next}{gsub(/^[ \t]+|[ \t]+$/,"",$1);print $1}' "$reg" 2>/dev/null)
        case "$cmd" in up|down|restart) extra="all" ;; *) extra="" ;; esac
        COMPREPLY=( $(compgen -W "$names $extra" -- "$cur") )
      elif [ "$cmd" = config ] && [ "$COMP_CWORD" -eq 3 ]; then
        COMPREPLY=( $(compgen -W "show edit mode args snapshot" -- "$cur") )
      elif [ "$cmd" = rm ] && [ "$COMP_CWORD" -ge 3 ]; then
        COMPREPLY=( $(compgen -W "--purge" -- "$cur") )
      elif [ "$cmd" = rename ] && [ "$COMP_CWORD" -ge 4 ]; then
        COMPREPLY=( $(compgen -W "--keep-dir" -- "$cur") )
      fi
      ;;
    common)
      # common <action> [...]
      if [ "$COMP_CWORD" -eq 2 ]; then
        COMPREPLY=( $(compgen -W "show edit mode deny allow" -- "$cur") )
      elif [ "$COMP_CWORD" -eq 3 ]; then
        case "${COMP_WORDS[2]}" in
          deny|allow) COMPREPLY=( $(compgen -W "add rm" -- "$cur") ) ;;
          mode) COMPREPLY=( $(compgen -W "acceptEdits auto bypassPermissions default dontAsk plan" -- "$cur") ) ;;
        esac
      fi
      ;;
    add)
      # add <name> <cwd> [--id <num>] [--token-env <VAR>|--token-stdin] [--mode <m>] [--channel <name>]
      if [ "$COMP_CWORD" -eq 3 ]; then
        COMPREPLY=( $(compgen -d -- "$cur") )
      elif [ "$COMP_CWORD" -ge 4 ]; then
        case "$prev" in
          --mode)      COMPREPLY=( $(compgen -W "acceptEdits auto bypassPermissions default dontAsk plan" -- "$cur") ) ;;
          --token-env) COMPREPLY=( $(compgen -A variable -- "$cur") ) ;;
          --channel)   COMPREPLY=( $(compgen -W "telegram" -- "$cur") ) ;;
          --id)        ;; # 자유 입력(숫자)
          *)           COMPREPLY=( $(compgen -W "--id --token-env --token-stdin --mode --channel" -- "$cur") ) ;;
        esac
      fi
      ;;
    status)
      # status [--json]
      if [ "$COMP_CWORD" -eq 2 ]; then
        COMPREPLY=( $(compgen -W "--json" -- "$cur") )
      fi
      ;;
    lang)
      # lang [show|en|ko|clear]
      if [ "$COMP_CWORD" -eq 2 ]; then
        COMPREPLY=( $(compgen -W "show en ko clear" -- "$cur") )
      fi
      ;;
  esac
}
complete -F _cctg cctg
