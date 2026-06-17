# lib/channels.sh — 채널 추상화 (descriptor + 조회)
# cc-tg.sh 가 런타임 source 하는 모듈(정의·전역설정 전용). 직접 실행하지 않는다.
#
# 채널 추가 방법: channel_spec 에 `<channel>:<field>` 케이스를 추가하고
# IMPLEMENTED_CHANNELS 에 채널명을 등재하면 된다. 그 외 배선(up/add)은 descriptor 경유라 불변.

# 레지스트리 channel 컬럼이 비었을 때(레거시 3컬럼)의 기본 채널.
DEFAULT_CHANNEL="telegram"
# 실제 구현·검증되어 add 가 허용하는 채널 집합(공백 구분).
# imessage 는 plugin ID·토큰/접근 규약 검증 후 descriptor 추가 + 여기 등재.
IMPLEMENTED_CHANNELS="telegram discord"

# channel_spec <channel> <field> → 값 출력(미정의 시 비-0 반환).
#   field: plugin | statedir_env | token_key | token_required
#          | display | id_label | id_required | seed_policy
channel_spec() {
  case "$1:$2" in
    telegram:plugin)         printf 'plugin:telegram@claude-plugins-official' ;;
    telegram:statedir_env)   printf 'TELEGRAM_STATE_DIR' ;;
    telegram:token_key)      printf 'TELEGRAM_BOT_TOKEN' ;;
    telegram:token_required) printf 'yes' ;;
    telegram:display)        printf 'Telegram' ;;
    telegram:id_label)       printf 'Telegram numeric ID' ;;
    telegram:id_required)    printf 'yes' ;;
    telegram:seed_policy)    printf 'allowlist' ;;
    discord:plugin)          printf 'plugin:discord@claude-plugins-official' ;;
    discord:statedir_env)    printf 'DISCORD_STATE_DIR' ;;
    discord:token_key)       printf 'DISCORD_BOT_TOKEN' ;;
    discord:token_required)  printf 'yes' ;;
    discord:display)         printf 'Discord' ;;
    discord:id_label)        printf 'Discord user snowflake' ;;
    discord:id_required)     printf 'no' ;;
    discord:seed_policy)     printf 'pairing' ;;
    *) return 1 ;;
  esac
}

# 구현·검증된 채널인지(add 허용 대상)
valid_channel() { case " $IMPLEMENTED_CHANNELS " in *" $1 "*) return 0;; *) return 1;; esac; }

# 봇의 채널 타입 조회 — 레지스트리 4번째 컬럼. 비었거나(레거시) 없으면 DEFAULT_CHANNEL.
channel_of() {
  local c=""
  [ -f "$REGISTRY" ] && c="$(awk -F'|' -v n="$1" '
    /^[[:space:]]*#/{next} /^[[:space:]]*$/{next}
    { c1=$1; gsub(/^[ \t]+|[ \t]+$/,"",c1)
      if (c1==n) { c4=$4; gsub(/^[ \t]+|[ \t]+$/,"",c4); print c4; exit } }
  ' "$REGISTRY")"
  [ -n "$c" ] && printf '%s' "$c" || printf '%s' "$DEFAULT_CHANNEL"
}
