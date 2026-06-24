# bash 자동완성 — cctg
# 설치: install.sh 가 ~/.local/share/bash-completion/completions/cctg 로 복사한다.
# macOS 기본 bash 3.2 호환을 위해 _init_completion 에 의존하지 않는다.

_cctg() {
  local cur prev cmd cmds names reg channels
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  cmds="add rm rename config common up down restart status logs attach lang doctor update version help"
  reg="${CC_TG_REGISTRY:-${CC_CHANNELS_DIR:-$HOME/.claude/channels}/projects.conf}"
  # lib/channels.sh IMPLEMENTED_CHANNELS 미러 — 채널 추가 시 함께 갱신(완성 파일은 lib 를 source 안 함).
  channels="telegram discord"

  # 첫 인자: 서브커맨드
  if [ "$COMP_CWORD" -eq 1 ]; then
    COMPREPLY=( $(compgen -W "$cmds" -- "$cur") )
    return
  fi

  cmd="${COMP_WORDS[1]}"
  case "$cmd" in
    up|down|restart)
      # 다중 타겟: 모든 인자 위치에서 등록된 봇 이름·all·--help 를 보완한다.
      names=$(awk -F'|' '/^[[:space:]]*#/{next}/^[[:space:]]*$/{next}{gsub(/^[ \t]+|[ \t]+$/,"",$1);print $1}' "$reg" 2>/dev/null)
      COMPREPLY=( $(compgen -W "$names all --help" -- "$cur") )
      ;;
    rm|rename|config|logs|attach)
      # 두 번째 인자: 등록된 봇 이름 (단일 타겟).
      # rename 의 세 번째(new name)·config 의 인자는 자유 입력이라 보완하지 않는다.
      if [ "$COMP_CWORD" -eq 2 ]; then
        names=$(awk -F'|' '/^[[:space:]]*#/{next}/^[[:space:]]*$/{next}{gsub(/^[ \t]+|[ \t]+$/,"",$1);print $1}' "$reg" 2>/dev/null)
        COMPREPLY=( $(compgen -W "$names" -- "$cur") )
      elif [ "$cmd" = config ] && [ "$COMP_CWORD" -eq 3 ]; then
        COMPREPLY=( $(compgen -W "show edit mode args snapshot width cwd token --help" -- "$cur") )
      elif [ "$cmd" = config ] && [ "$COMP_CWORD" -eq 4 ]; then
        case "${COMP_WORDS[3]}" in
          mode)  COMPREPLY=( $(compgen -W "acceptEdits auto bypassPermissions default dontAsk plan clear" -- "$cur") ) ;;
          width) COMPREPLY=( $(compgen -W "clear default" -- "$cur") ) ;;
          cwd)   COMPREPLY=( $(compgen -d -- "$cur") ) ;;
          token) COMPREPLY=( $(compgen -W "--token-env --token-stdin --help" -- "$cur") ) ;;
        esac
      elif [ "$cmd" = rm ] && [ "$COMP_CWORD" -ge 3 ]; then
        COMPREPLY=( $(compgen -W "--purge --help" -- "$cur") )
      elif [ "$cmd" = rename ] && [ "$COMP_CWORD" -ge 4 ]; then
        COMPREPLY=( $(compgen -W "--keep-dir --help" -- "$cur") )
      elif [ "$cmd" = logs ] || [ "$cmd" = attach ]; then
        [ "$COMP_CWORD" -ge 3 ] && COMPREPLY=( $(compgen -W "--help" -- "$cur") )
      fi
      ;;
    common)
      # common <action> [...]
      if [ "$COMP_CWORD" -eq 2 ]; then
        COMPREPLY=( $(compgen -W "show edit mode width deny allow --help" -- "$cur") )
      elif [ "$COMP_CWORD" -eq 3 ]; then
        case "${COMP_WORDS[2]}" in
          deny|allow) COMPREPLY=( $(compgen -W "add rm" -- "$cur") ) ;;
          mode) COMPREPLY=( $(compgen -W "acceptEdits auto bypassPermissions default dontAsk plan" -- "$cur") ) ;;
          width) COMPREPLY=( $(compgen -W "clear default" -- "$cur") ) ;;
        esac
      fi
      ;;
    add)
      # add <name> <cwd> [--id <num>] [--token-env <VAR>|--token-stdin] [--mode <m>] [--channel <name>] [--group <id>[:nomention][:allow=m1,m2]]
      if [ "$COMP_CWORD" -eq 3 ]; then
        COMPREPLY=( $(compgen -d -- "$cur") )
      elif [ "$COMP_CWORD" -ge 4 ]; then
        case "$prev" in
          --mode)      COMPREPLY=( $(compgen -W "acceptEdits auto bypassPermissions default dontAsk plan" -- "$cur") ) ;;
          --token-env) COMPREPLY=( $(compgen -A variable -- "$cur") ) ;;
          --channel)   COMPREPLY=( $(compgen -W "$channels" -- "$cur") ) ;;
          --id)        ;; # 자유 입력(숫자)
          --group)     ;; # 자유 입력(컴파운드 토큰 <id>[:nomention][:allow=...])
          *)           COMPREPLY=( $(compgen -W "--id --token-env --token-stdin --mode --channel --group --help" -- "$cur") ) ;;
        esac
      fi
      ;;
    status)
      # status [--json]
      if [ "$COMP_CWORD" -eq 2 ]; then
        COMPREPLY=( $(compgen -W "--json --help" -- "$cur") )
      fi
      ;;
    lang)
      # lang [show|en|ko|clear]
      if [ "$COMP_CWORD" -eq 2 ]; then
        COMPREPLY=( $(compgen -W "show en ko clear --help" -- "$cur") )
      fi
      ;;
    update)
      # update [--version X.Y.Z | --latest | --list] [--alias|--no-alias] — 다중 위치 플래그
      COMPREPLY=( $(compgen -W "--version --latest --list --alias --no-alias --help" -- "$cur") )
      ;;
  esac
}
complete -F _cctg cctg
