# messages/ko.sh — CCTG 한국어 메시지 카탈로그
#
# 각 메시지는 printf 템플릿을 담은 CCTG_MSG_<KEY> 스칼라 변수다(Bash 3.2 호환 — 연관배열 미사용).
# cc-tg.sh 의 t() 가 키로 조회해 `printf "$템플릿" "$@"` 로 출력한다. %s 자리표시자·\n 포함.
# en.sh 와 동일한 키 집합을 유지한다(키 패리티). 값만 언어별로 다르다.

CCTG_MSG_SHARED_CREATED="공통 설정 생성: %s (defaultMode=bypassPermissions + deny 안전망)\n"
CCTG_MSG_ERR_NEED_JQ="ERROR: 이 동작은 jq가 필요합니다. 'cctg common edit'로 직접 편집하거나 jq를 설치하세요 (brew install jq).\n"

CCTG_MSG_USAGE="사용법: %s <command> [args]\n  add <name> <cwd> [--id <num>] [--token-env <VAR>|--token-stdin] [--mode <m>]\n                         프로젝트 봇 등록 (플래그 사용 시 비대화형, --id 필수)\n  rm  <name> [--purge]   등록 해제 (--purge: 상태 디렉터리까지 삭제)\n  rename <old> <new> [--keep-dir]\n                         이름 변경 (기본: 상태 디렉터리도 함께 이동.\n                         --keep-dir: 디렉터리 경로 유지하고 이름만 변경)\n  config <name> [show|edit|mode <m|clear>|args <str>]\n                         봇별 옵션(권한 모드·추가 인자) 보기·수정\n  common [show|edit|mode <m>|deny add|rm <rule>|allow add|rm <rule>]\n                         공통 권한 정책(모든 봇에 적용) 보기·수정\n  up   <name|all>        기동\n  down <name|all>        정지\n  restart <name|all>     재기동 (down + up)\n  status [--json]        등록/실행 상태 (--json: 기계 판독용)\n  logs <name> [N]        최근 로그 N줄 (기본 50, attach 없이)\n  attach <name>          tmux 세션 attach (분리: Ctrl-b d)\n  lang [show|en|ko|clear]  CLI 출력 언어 보기·변경\n  doctor                 의존성·PATH·레지스트리 환경 진단\n  update                 git pull 후 재설치\n  version                버전 출력\n  help                   이 도움말\n\n이름 규칙: 영문/숫자/_/- 만 허용. 전역 채널 이름(telegram/discord/imessage/fakechat)은 예약됨.\n"

# 공용 조각
CCTG_MSG_FOLLOW_SHARED="공통 따름"
CCTG_MSG_FOLLOW_SHARED_PAREN="(공통 따름)"
CCTG_MSG_EMPTY_PAREN="(비움)"
CCTG_MSG_SHARED_WORD="공통"
CCTG_MSG_ISSUE_NO_CWD="cwd없음"
CCTG_MSG_ISSUE_NO_TOKEN="토큰없음"

# 공통 에러
CCTG_MSG_ERR_NOT_REGISTERED="ERROR: 등록되지 않은 프로젝트: %s\n"
CCTG_MSG_ERR_BADNAME="ERROR: 이름은 영문/숫자/_/- 만 허용합니다: '%s'\n"
CCTG_MSG_ERR_RESERVED="ERROR: '%s'은(는) 예약된 전역 채널 이름입니다 (%s). 해당 채널 전역 봇의 상태 디렉터리와 충돌합니다. 다른 이름을 쓰세요.\n"
CCTG_MSG_ERR_FOREIGN_STATEDIR="ERROR: %s 에 이미 다른 채널 봇의 상태(.env/access.json, cctg launch.env 없음)가 있습니다. 덮어쓰지 않습니다. 다른 이름을 쓰거나 해당 디렉터리를 옮기세요.\n"
CCTG_MSG_ERR_ALREADY_REGISTERED="ERROR: 이미 등록됨: %s\n"
CCTG_MSG_ERR_RUNNING_DOWN_FIRST="ERROR: 실행 중입니다. 먼저 '%s down %s' 후 다시 시도하세요.\n"
CCTG_MSG_ERR_REGISTRY_UPDATE="ERROR: 레지스트리 갱신 실패\n"
CCTG_MSG_ERR_BAD_MODE="ERROR: 잘못된 모드: '%s' (유효: %s)\n"

# up / down
CCTG_MSG_ERR_NO_CWD="ERROR: 작업 디렉터리 없음: %s\n"
CCTG_MSG_ERR_NO_TOKEN="ERROR: 토큰 파일 없음: %s (먼저 add 하세요)\n"
CCTG_MSG_ALREADY_RUNNING="이미 실행 중: %s\n"
CCTG_MSG_UP_OK="UP   %s  (cwd=%s, state=%s, tmux=%s)\n"
CCTG_MSG_DOWN_OK="DOWN %s\n"
CCTG_MSG_DOWN_STOPPED="정지 상태: %s\n"

# add
CCTG_MSG_ADD_PROMPT_TOKEN="봇 토큰 입력 (@BotFather 발급, 새 봇이어야 함): "
CCTG_MSG_ERR_EMPTY_TOKEN="ERROR: 토큰이 비었습니다\n"
CCTG_MSG_ADD_PROMPT_TGID="본인 텔레그램 숫자 ID (모르면 @userinfobot 에 DM): "
CCTG_MSG_ERR_NOT_NUMERIC_ID="ERROR: 숫자 ID가 아닙니다: '%s'\n"
CCTG_MSG_ADD_PROMPT_MODE="권한 모드 [엔터=공통 따름 | %s]: "
CCTG_MSG_ERR_BAD_MODE_ADD="ERROR: 잘못된 권한 모드: '%s' (유효: %s)\n"
CCTG_MSG_ERR_ADD_UNKNOWN_FLAG="ERROR: 알 수 없는 add 플래그: '%s' (유효: --id <num>, --token-env <VAR>, --token-stdin, --mode <m>)\n"
CCTG_MSG_ERR_ADD_FLAG_VALUE="ERROR: %s 에는 값이 필요합니다\n"
CCTG_MSG_ERR_ADD_BAD_ENVNAME="ERROR: '%s' 은(는) 유효한 환경변수 이름이 아닙니다\n"
CCTG_MSG_ERR_ADD_NEED_ID="ERROR: 비대화형 add(--token-env/--token-stdin)에는 --id <num> 가 필수입니다\n"
CCTG_MSG_ADD_DONE="등록 완료: %s → cwd=%s, state=%s\n"
CCTG_MSG_ADD_DONE_ALLOWLIST="  allowlist에 %s 시드함 (페어링 불필요)\n"
CCTG_MSG_ADD_DONE_MODE="  권한 모드: %s  (공통: %s common / 봇별: %s config %s)\n"
CCTG_MSG_ADD_DONE_NEXT="다음: %s up %s  → 봇에 DM하면 바로 응답합니다.\n"

# rm
CCTG_MSG_RM_DONE="등록 해제: %s\n"
CCTG_MSG_RM_PURGE_REFUSE_GLOBAL="  거부: 전역 봇 디렉터리는 삭제하지 않습니다: %s\n"
CCTG_MSG_RM_PURGE_DELETED="  상태 디렉터리 삭제: %s\n"
CCTG_MSG_RM_PURGE_OUTSIDE="  주의: 상태 디렉터리가 CHANNELS_DIR 밖이라 자동 삭제하지 않음: %s\n"
CCTG_MSG_RM_KEEP="  상태 디렉터리 보존: %s (토큰/allowlist 포함). 완전 삭제하려면 --purge\n"

# rename
CCTG_MSG_ERR_SAME_NAME="ERROR: old/new 이름이 동일합니다: %s\n"
CCTG_MSG_ERR_TARGET_EXISTS="ERROR: 대상 상태 디렉터리가 이미 존재합니다: %s (이동 취소)\n"
CCTG_MSG_ERR_MOVE_FAILED="ERROR: 상태 디렉터리 이동 실패: %s → %s\n"
CCTG_MSG_RENAME_MOVED="  상태 디렉터리 이동: %s → %s\n"
CCTG_MSG_RENAME_KEPT="  상태 디렉터리 유지: %s\n"
CCTG_MSG_RENAME_DONE="이름 변경: %s → %s\n"
CCTG_MSG_RENAME_NEXT="다음: %s up %s\n"

# config
CCTG_MSG_CFG_SHOW_HEADER="# %s 봇 옵션 (%s)\n"
CCTG_MSG_CFG_SHOW_MODE="  권한 모드: %s\n"
CCTG_MSG_CFG_SHOW_LAUNCHENV="--- launch.env ---\n"
CCTG_MSG_ERR_CONFIG_MODE_USAGE="사용법: %s config %s mode <mode|clear>  (모드: %s)\n"
CCTG_MSG_CFG_MODE_CLEARED="%s 권한 모드: (공통 따름)\n"
CCTG_MSG_CFG_MODE_SET="%s 권한 모드: %s\n"
CCTG_MSG_APPLY_RESTART="  적용하려면: %s restart %s\n"
CCTG_MSG_CFG_ARGS_SET="%s CLAUDE_EXTRA_ARGS: %s\n"
CCTG_MSG_ERR_CONFIG_UNKNOWN="ERROR: 알 수 없는 config 동작: %s\n"
CCTG_MSG_CFG_USAGE="사용법: %s config <name> [show | edit | mode <mode|clear> | args <string>]\n"

# common
CCTG_MSG_COMMON_SHOW_HEADER="# 공통 설정 (%s)\n"
CCTG_MSG_ERR_COMMON_MODE_USAGE="사용법: %s common mode <mode>  (모드: %s)\n"
CCTG_MSG_COMMON_MODE_SET="공통 defaultMode: %s  (모든 봇 restart 후 적용)\n"
CCTG_MSG_COMMON_RULE_ADD="%s += %s  (모든 봇 restart 후 적용)\n"
CCTG_MSG_COMMON_RULE_RM="%s -= %s  (모든 봇 restart 후 적용)\n"
CCTG_MSG_ERR_COMMON_OP="ERROR: %s 동작은 add|rm 만 지원\n"
CCTG_MSG_ERR_COMMON_UNKNOWN="ERROR: 알 수 없는 common 동작: %s\n"
CCTG_MSG_COMMON_USAGE="사용법: %s common [show | edit | mode <mode> | deny add|rm <rule> | allow add|rm <rule>]\n"

# status
CCTG_MSG_STATUS_GLOBAL="전역 봇: %s/telegram (이 스크립트는 관리하지 않음)\n"
CCTG_MSG_STATUS_PROJECT_HEADER="--- 프로젝트 봇 ---\n"
CCTG_MSG_STATUS_RUNNING="  [RUNNING] %s%s  (tmux=%s)\n"
CCTG_MSG_STATUS_BROKEN="  [BROKEN ] %s  (%s)\n"
CCTG_MSG_STATUS_HINT_NO_CWD="            ↳ 작업 디렉터리 없음: %s — 디렉터리를 만들거나 '%s rm %s' 후 올바른 경로로 다시 add\n"
CCTG_MSG_STATUS_HINT_NO_TOKEN="            ↳ 토큰 없음: %s/.env — '%s rm %s' 후 다시 add 하거나 해당 파일에 TELEGRAM_BOT_TOKEN= 추가\n"
CCTG_MSG_STATUS_STOPPED="  [stopped] %s\n"
CCTG_MSG_ERR_STATUS_UNKNOWN_FLAG="ERROR: 알 수 없는 status 플래그: '%s' (유효: --json)\n"
CCTG_MSG_STATUS_PATHS="            cwd=%s  state=%s\n"
CCTG_MSG_STATUS_MODE="            권한모드=%s\n"
CCTG_MSG_STATUS_UPTIME="  up %s"
CCTG_MSG_STATUS_NONE="  (등록된 프로젝트 봇 없음)\n"

# logs / attach
CCTG_MSG_LOGS_STOPPED="정지 상태: %s (로그 없음). '%s up %s' 후 다시 시도하세요.\n"
CCTG_MSG_LOGS_SNAPSHOT="# %s 정지됨 — 마지막 세션 로그를 표시합니다(가장 최근 'down' 시점 저장).\n"
CCTG_MSG_ERR_NOT_RUNNING="ERROR: 실행 중이 아닙니다: %s ('%s up %s' 먼저)\n"
CCTG_MSG_ATTACH_DETACH_HINT="(분리하려면 Ctrl-b 누른 뒤 d)\n"

# update
CCTG_MSG_ERR_REPO_NOT_FOUND="ERROR: cctg 레포 위치를 찾을 수 없습니다.\n"
CCTG_MSG_ERR_REPO_HINT="  레포에서 install.sh 를 한 번 실행하면 매니페스트(%s)가 생성됩니다.\n"
CCTG_MSG_UPDATE_START="업데이트: %s  (mode=%s, 현재 v%s)\n"
CCTG_MSG_ERR_GIT_PULL="ERROR: git pull 실패 (로컬 변경이 있거나 fast-forward 불가). 레포에서 직접 확인하세요.\n"
CCTG_MSG_UPDATE_VERSION="버전: v%s → v%s\n"
CCTG_MSG_UPDATE_COMPLETION_HINT="자동완성을 반영하려면 새 터미널을 여세요 (zsh 즉시 적용: rm -f ~/.zcompdump*; exec zsh).\n"

# doctor
CCTG_MSG_DOCTOR_HEADER="cctg doctor (v%s)\n"
CCTG_MSG_DOCTOR_DEPS="--- 의존성 ---\n"
CCTG_MSG_DOCTOR_OK="  ok   %s (%s)\n"
CCTG_MSG_DOCTOR_WARN_CAFFEINATE="  warn %s 없음 (macOS 아님 → sleep 방지 불가)\n"
CCTG_MSG_DOCTOR_MISS="  MISS %s (필수)\n"
CCTG_MSG_DOCTOR_WARN_JQ="  warn jq 없음 (선택 — 'common mode/deny/allow'에 필요. 없어도 'common edit' 가능)\n"
CCTG_MSG_DOCTOR_PATH="--- PATH ---\n"
CCTG_MSG_DOCTOR_PATH_OK="  ok   ~/.local/bin 이 PATH에 있음\n"
CCTG_MSG_DOCTOR_PATH_WARN="  warn ~/.local/bin 이 PATH에 없음\n"
CCTG_MSG_DOCTOR_REGISTRY="--- 레지스트리 ---\n"
CCTG_MSG_DOCTOR_FILE="  파일: %s\n"
CCTG_MSG_DOCTOR_REGISTRY_COUNT="  등록된 프로젝트 봇: %s 개\n"
CCTG_MSG_DOCTOR_SHARED="--- 공통 설정(권한 정책) ---\n"
CCTG_MSG_DOCTOR_DEFAULTMODE="  defaultMode: %s\n"
CCTG_MSG_DOCTOR_DENYALLOW="  deny: %s 개 / allow: %s 개\n"
CCTG_MSG_DOCTOR_NOJQ="  (jq 없음 — 'cctg common show' 로 확인)\n"
CCTG_MSG_DOCTOR_SHARED_NONE="  (아직 없음 — 첫 add/up 시 생성)\n"
CCTG_MSG_DOCTOR_PLUGIN_HINT="  (telegram 플러그인은 전역 설치 필요: /plugin install telegram@claude-plugins-official)\n"

# version / 디스패처
CCTG_MSG_VERSION_LINE="%s %s\n"
CCTG_MSG_ERR_UNKNOWN_CMD="ERROR: 알 수 없는 명령: %s\n"

# lang
CCTG_MSG_LANG_CURRENT="현재 언어: %s (출처: %s)\n"
CCTG_MSG_LANG_SET="언어 설정: %s\n"
CCTG_MSG_LANG_CLEARED="언어 설정 제거됨 (자동 감지로 회귀)\n"
CCTG_MSG_ERR_LANG_INVALID="ERROR: 지원하지 않는 언어: '%s' (지원: en, ko)\n"
CCTG_MSG_LANG_USAGE="사용법: %s lang [show | en | ko | clear]\n"
