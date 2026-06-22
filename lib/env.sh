# lib/env.sh — 전역 설정값
# cc-tg.sh 가 런타임 source 하는 모듈(정의·전역설정 전용). 직접 실행하지 않는다.

CHANNELS_DIR="${CC_CHANNELS_DIR:-$HOME/.claude/channels}"
REGISTRY="${CC_TG_REGISTRY:-$CHANNELS_DIR/projects.conf}"
# 모든 CCTG 봇에 --settings 로 주입되는 공통 Claude 설정(권한 allow/deny/defaultMode).
# 전역 ~/.claude/settings.json 과 merge 되며(deny 는 union, deny 가 allow 보다 우선),
# 여기 defaultMode 가 봇의 기본 권한 모드가 된다. 봇별 launch.env 의 CCTG_PERMISSION_MODE 가 우선한다.
SHARED_SETTINGS="${CC_TG_SHARED_SETTINGS:-$CHANNELS_DIR/cctg-shared.settings.json}"
# 모든 CCTG 봇에 --append-system-prompt 로 주입되는 채널 reply 리마인더 텍스트.
# cctg 가 부재 시 기본 문구로 시드(기본 ON). 비우면 주입 안 함(opt-out), 편집하면 그 내용으로 주입.
# 봇 세션에만 적용되며 사용자의 일반 claude 사용에는 영향 없다.
REPLY_REMINDER_FILE="${CC_TG_REPLY_REMINDER_FILE:-$CHANNELS_DIR/cctg-reply-reminder.txt}"
SESS_PREFIX="cctg-"
# detached 세션 폭(칼럼)의 최종 폴백 기본값. tmux detached 기본은 80 이라 logs/snapshot 캡처가
# 80 폭으로 잘린다 — client 미부착 상태에서도 더 넓은 출력을 보존하려고 new-session -x 로 고정한다.
# 유효 폭은 봇별(launch.env CCTG_SESS_WIDTH) > env(CC_TG_SESS_WIDTH) > 전역(cctg common width,
# CCTG_CONFIG sess_width) > 본 기본값 순으로 effective_sess_width() 가 해석한다(lib/config.sh).
SESS_WIDTH_DEFAULT=100

# claude --permission-mode 가 받는 유효한 모드 (claude --help 기준)
VALID_MODES="acceptEdits auto bypassPermissions default dontAsk plan"

# 전역 채널 플러그인이 ~/.claude/channels/<name>/ 를 기본 상태 디렉터리로 쓰는 예약 이름.
# 이 이름으로 봇을 만들면 전역 채널 봇의 .env·access.json 을 덮어쓰게 되므로 거부한다.
# (각 플러그인의 server.ts: <CHANNEL>_STATE_DIR ?? ~/.claude/channels/<channel>)
RESERVED_NAMES="telegram discord imessage fakechat"
