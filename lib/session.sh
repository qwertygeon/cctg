# lib/session.sh — tmux 세션·스냅샷·기동/정지 라이프사이클
# cc-tg.sh 가 런타임 source 하는 모듈(정의·전역설정 전용). 직접 실행하지 않는다.


sess_of() { printf '%s%s' "$SESS_PREFIX" "$1"; }
# tmux 타겟('-t')은 정확 일치가 없으면 접두(prefix)·fnmatch 로 매칭되어, 한 봇 이름이
# 다른 봇 이름의 접두인 경우(cc-tg vs cc-tg-discord) 엉뚱한 세션에 매칭된다. '=' 접두로
# 정확 일치를 강제해 오매칭을 차단한다. 세션을 *만드는* new-session -s 는 리터럴 이름이므로 미적용.
#
# 단, '=NAME' 단독은 **target-session** 문법(has-session/kill-session/attach)에서만 유효하다.
# capture-pane/display-message 는 **target-pane** 을 받는데, target-pane 문법에선 '=NAME'
# 만으로는 pane 으로 해석되지 않아 capture-pane 은 "can't find pane", display-message 는 빈
# 결과를 낸다. pane 타겟은 뒤에 ':' 를 붙여 "정확매칭 세션의 기본 window/pane" 으로 해석시킨다.
# 따라서 두 헬퍼를 구분한다: sess_t(세션 타겟), sess_pt(pane 타겟).
sess_t()  { printf '=%s'  "$(sess_of "$1")"; }
sess_pt() { printf '=%s:' "$(sess_of "$1")"; }
is_running() { tmux has-session -t "$(sess_t "$1")" 2>/dev/null; }

# 세션 안의 claude(채널-무관 게이트웨이 본체)가 살아있는지 — 거짓 UP 판별용.
# is_running 은 tmux 세션 존재만 본다. launch 가 '...; exec bash' 로 끝나므로 claude 종료 후에도
# pane 에 bash 가 남아 세션이 생존한다(거짓 UP). pane_current_command 는 claude 생존 중에도 "bash"
# 로 나와 신뢰할 수 없어(실측), pane_pid 의 프로세스 자손 트리에서 comm==claude 를 찾는다.
# 모든 채널이 동일 launch(caffeinate -is claude --channels …)로 떠 채널 플러그인이 claude 의
# 자식으로 동작하므로, claude 가 채널 불문 단일 불변 신호다.
# BSD ps / Bash 3.2 호환: 맵·BFS 는 awk 가 수행(bash 연관배열 미사용). comm 만 보므로 토큰 비노출.
# 가정: claude 의 프로세스명(comm)이 'claude' 다(풀패스 호출 '/…/claude' 도 정규식이 처리).
#   claude CLI 가 향후 프로세스명을 바꾸면(node/래퍼 등) false DEAD 가능 — 그때는 launch 래퍼
#   'caffeinate'(이름 안정) 를 보조 신호로 병행하도록 정규식을 확장한다.
claude_alive() {
  local pp
  pp="$(tmux display-message -p -t "$(sess_pt "$1")" '#{pane_pid}' 2>/dev/null)"
  printf '%s' "$pp" | grep -qE '^[0-9]+$' || return 1
  ps -ax -o pid=,ppid=,comm= 2>/dev/null | awk -v root="$pp" '
    { ppid[$1]=$2; comm[$1]=$3 }
    END {
      n=0; q[n++]=root
      for (i=0; i<n; i++)
        for (p in ppid)
          if (ppid[p]==q[i]) { q[n++]=p; if (comm[p] ~ /(^|\/)claude$/) found=1 }
      exit found?0:1
    }'
}

# detached 세션 기동 공통 경로(일반봇·예약봇 공용). 호출자가 동일 launch 문자열을 만들고
# 본 함수로 위임한다 — 채널 종류가 늘어도 기동 형식/폭을 한 곳에서 관리한다.
#   - 명령 전달은 다중 인자 직접형(bash -lc "$launch")으로 통일한다: 단일 인자형은 tmux 가
#     sh -c 로 한 겹 더 감싸 불필요한 셸 계층·이식성 부담을 만든다.
#   - -x "$width": detached 기본 80 폭으로 캡처가 잘리지 않도록 폭을 고정한다.
# $1=세션명(sess_of 결과), $2=launch 문자열, $3=폭(effective_sess_width 결과; 생략 시 기본값).
# 반환코드는 tmux new-session 그대로 전파.
start_session() {
  tmux new-session -d -x "${3:-$SESS_WIDTH_DEFAULT}" -s "$1" bash -lc "$2"
}

# 봇의 마지막 활동 시각(epoch) 을 stdout 으로. 세션 생존($3=1)이면 tmux #{window_activity}(라이브
# 출력 활동 시각), 비실행이면 last-session.log mtime(마지막 down 스냅샷) 으로 폴백한다.
# 알 수 없으면(미실행·미스냅샷·비숫자) 비-0 반환. $1=봇/채널명 $2=상태디렉터리 $3=세션생존(1/0).
# 주의: window_activity 는 출력 활동 기준이라 '살아있지만 멈춘' 봇 식별의 보조 지표다(완전 신뢰 X).
last_activity_epoch() {
  local name="$1" sd="$2" live="$3" e=""
  if [ "$live" = 1 ]; then
    e="$(tmux display-message -p -t "$(sess_pt "$name")" '#{window_activity}' 2>/dev/null)"
  elif [ -f "$sd/last-session.log" ]; then
    e="$(file_mtime "$sd/last-session.log")"
  fi
  case "$e" in ''|*[!0-9]*) return 1 ;; esac
  printf '%s' "$e"
}

# 초 → 사람이 읽는 기간 (예: 2d3h / 4h5m / 7m)
fmt_dur() {
  local s="$1" d h m
  d=$(( s / 86400 )); h=$(( (s % 86400) / 3600 )); m=$(( (s % 3600) / 60 ))
  if   [ "$d" -gt 0 ]; then printf '%dd%dh' "$d" "$h"
  elif [ "$h" -gt 0 ]; then printf '%dh%dm' "$h" "$m"
  else                      printf '%dm' "$m"; fi
}

# 세션의 현재 화면(렌더 텍스트, 스크롤백 2000줄)을 last-session.log(600)로 원자적 저장.
# capture-pane 의 렌더 텍스트라 ANSI 잡음이 없다. tmp→mv 라 읽는 쪽이 부분 파일을 보지 않는다.
take_snapshot() {
  local sess="$1" sd="$2" snap="$2/last-session.log"
  [ -d "$sd" ] || return 0
  if tmux capture-pane -p -S -2000 -t "=$sess:" > "$snap.tmp" 2>/dev/null; then
    mv "$snap.tmp" "$snap" && chmod 600 "$snap" 2>/dev/null
  else
    rm -f "$snap.tmp"
  fi
}

# 실행 중인 봇 세션을 interval 초마다 스냅샷하는 백그라운드 watcher 기동(크래시·재부팅 대비).
# 세션이 사라지면 watcher 가 스스로 종료한다. PID 는 <sd>/.snapshotter.pid 로 추적해 down 시 정지.
# nohup + fd 리다이렉트로 호출 셸과 분리되어 cctg 종료 후에도 계속 동작한다.
start_snapshotter() {
  local name="$1" sd="$2" interval="$3" sess pidf marker wpid
  sess="$(sess_of "$name")"; pidf="$sd/.snapshotter.pid"
  # 식별 마커: 이 watcher 프로세스 argv 에 박아 stop 시 PID 재사용 오살을 막는다(대조용).
  marker="cctg-snapshotter:$sess"
  stop_snapshotter "$sd"   # 재기동 시 기존 watcher 정리
  # 루프 본문은 단일 인용 문자열이라 부모 셸 확장과 무관(인자로 값 전달).
  # $0 자리에 marker 를 두어 ps 명령줄로 식별 가능하게 한다($0 는 본문에서 미사용).
  nohup bash -c '
    sess="$1"; sd="$2"; interval="$3"; snap="$sd/last-session.log"
    while tmux has-session -t "=$sess" 2>/dev/null; do
      if tmux capture-pane -p -S -2000 -t "=$sess:" > "$snap.tmp" 2>/dev/null; then
        mv "$snap.tmp" "$snap" && chmod 600 "$snap" 2>/dev/null
      else
        rm -f "$snap.tmp"
      fi
      sleep "$interval"
    done
    rm -f "$sd/.snapshotter.pid"
  ' "$marker" "$sess" "$sd" "$interval" >/dev/null 2>&1 &
  wpid=$!
  # PID(1행) + 마커(2행) 기록 — stop 이 PID 와 마커를 대조해 우리 watcher 일 때만 kill.
  { printf '%s\n' "$wpid"; printf '%s\n' "$marker"; } > "$pidf"
  chmod 600 "$pidf" 2>/dev/null
  # 기동 확인 — watcher 가 즉시 죽었으면(드묾) pidf 를 정리하고 실패를 알린다(호출측이 경고).
  kill -0 "$wpid" 2>/dev/null || { rm -f "$pidf"; return 1; }
  return 0
}

# watcher 정지(있으면). PID 파일을 읽어 종료하고 파일 제거. 없으면 무동작.
stop_snapshotter() {
  local pidf="$1/.snapshotter.pid" pid marker
  [ -f "$pidf" ] || return 0
  pid="$(sed -n '1p' "$pidf" 2>/dev/null)"
  marker="$(sed -n '2p' "$pidf" 2>/dev/null)"
  # PID 재사용 오살 방지: PID 의 명령줄에 우리 watcher 마커가 있을 때만 kill.
  # 마커 미기록(구버전 pidf)이면 기존 동작(존재 시 kill)으로 폴백한다.
  # ps -ww: 명령줄 truncation 방지(마커는 긴 스크립트 본문 뒤 argv 에 위치).
  # 매칭은 공백 분리 토큰 *완전 일치*로 한다 — substring(grep -F)이면 형제 봇 마커
  # (cctg-snapshotter:cctg-cc-tg 가 cctg-snapshotter:cctg-cc-tg-discord 의 접두)를
  # 오매칭해, PID 재사용 시 형제 watcher 를 오살할 수 있다(tmux '=' 정확매칭과 동류).
  if [ -n "$pid" ]; then
    if [ -z "$marker" ] || ps -ww -p "$pid" -o command= 2>/dev/null \
         | awk -v m="$marker" '{for(i=1;i<=NF;i++) if($i==m) f=1} END{exit f?0:1}'; then
      kill "$pid" 2>/dev/null
    fi
  fi
  rm -f "$pidf"
}

up_one() {
  local name="$1" cwd sd row
  row="$(lookup "$name")" || { te ERR_NOT_REGISTERED "$name" "$PROG"; return 1; }
  cwd="$(expand "$(cut -f1 <<<"$row")")"
  sd="$(expand "$(cut -f2 <<<"$row")")"
  [ -d "$cwd" ] || { te ERR_NO_CWD "$(tilde "$cwd")"; te ERR_NO_CWD_HINT "$PROG" "$name"; return 1; }
  [ -f "$sd/.env" ] || { te ERR_NO_TOKEN "$(tilde "$sd/.env")"; return 1; }
  if is_running "$name"; then
    # 세션은 있으나 claude 가 죽은 DEAD 면 복구 경로(restart)를 안내한다. 자동 재기동은
    # 하지 않는다(DEC-001/A=2) — is_running 기반 idempotent 동작 유지 위해 return 0.
    if claude_alive "$name"; then t ALREADY_RUNNING "$name"
    else t ALREADY_RUNNING_DEAD "$name" "$PROG" "$name"; fi
    return 0
  fi
  # claude 부재 시 세션은 exec bash 로 살아남아 거짓 UP 이 되므로 기동 전에 거부.
  need_claude || return 1

  # 공통 설정(권한 정책)을 --settings 로 주입. 없으면 시드.
  ensure_shared_settings
  local shared_arg=""
  [ -f "$SHARED_SETTINGS" ] && shared_arg="--settings $(printf '%q' "$SHARED_SETTINGS")"

  # 상태 디렉터리/토큰을 분리 주입하고 caffeinate로 sleep 방지하며 채널 세션 기동.
  # 봇별 launch.env(있으면)에서 CCTG_PERMISSION_MODE / CLAUDE_EXTRA_ARGS 를 읽어 claude 인자로 전달한다.
  #   - CCTG_PERMISSION_MODE 가 있으면 --permission-mode 로 공통 defaultMode 를 override (없으면 공통값 사용).
  #   - \$ 이스케이프로 런타임(launch.env source 이후)에 단어 분리되도록 한다.
  # 봇의 채널 타입에 따라 상태디렉터리 env 이름·플러그인 ID 를 descriptor 에서 해석(기본 telegram).
  local ch sd_env plugin
  ch="$(channel_of "$name")"
  sd_env="$(channel_spec "$ch" statedir_env)"
  plugin="$(channel_spec "$ch" plugin)"
  local launch
  launch="cd $(printf '%q' "$cwd") \
&& export ${sd_env}=$(printf '%q' "$sd") \
&& set -a && source $(printf '%q' "$sd/.env") \
&& { [ -f $(printf '%q' "$sd/launch.env") ] && source $(printf '%q' "$sd/launch.env") || true; } \
&& set +a \
&& MODE_ARG=\"\" \
&& { [ -n \"\${CCTG_PERMISSION_MODE:-}\" ] && MODE_ARG=\"--permission-mode \${CCTG_PERMISSION_MODE}\" || true; } \
&& caffeinate -is claude --channels $plugin $shared_arg \${MODE_ARG} \${CLAUDE_EXTRA_ARGS:-}; exec bash"

  # new-session 실패(서버 기동 불가·리소스 부족·직전 race 등)를 확인 — 미확인 시 거짓 UP 보고.
  if ! start_session "$(sess_of "$name")" "$launch" "$(effective_sess_width "$sd")"; then
    te ERR_UP_FAILED "$name"; return 1
  fi
  t UP_OK "$name" "$(tilde "$cwd")" "$(tilde "$sd")" "$(sess_of "$name")"

  # 옵트인: launch.env 의 CCTG_LOG_SNAPSHOT_INTERVAL(초)가 양수면 주기 스냅샷 watcher 기동.
  local snap_iv; snap_iv="$(snapshot_interval_of "$sd")"
  if printf '%s' "$snap_iv" | grep -qE '^[0-9]+$' && [ "$snap_iv" -gt 0 ]; then
    if start_snapshotter "$name" "$sd" "$snap_iv"; then
      t UP_SNAPSHOT_ON "$snap_iv"
    else
      te WARN_SNAPSHOT_FAILED "$name"
    fi
  fi
}

down_one() {
  local name="$1" row sd=""
  [ -n "$name" ] && row="$(lookup "$name")" && sd="$(expand "$(cut -f2 <<<"$row")")"
  if is_running "$name"; then
    # 종료 전 마지막 세션 출력을 보존한다(live 캡처) — 종료 후에도 `cctg logs` 로 조회 가능.
    [ -n "$sd" ] && take_snapshot "$(sess_of "$name")" "$sd"
    # 세션을 실제로 종료한 뒤에만 watcher 를 멈춘다 — kill 실패(드묾) 시 watcher 가 계속 돌아
    # "watcher 는 멈췄는데 세션은 살아있는" 불일치를 피한다. kill 성공 시 watcher 는 다음 틱에서
    # has-session=false 로 스스로 멈추지만, 즉시 정지 + pidf 정리를 위해 명시적으로 stop 한다.
    if ! tmux kill-session -t "$(sess_t "$name")"; then
      te ERR_DOWN_FAILED "$name"; return 1
    fi
    [ -n "$sd" ] && stop_snapshotter "$sd"
    t DOWN_OK "$name"
  else
    # 세션이 외부에서 종료된 경우 남아 있을 수 있는 watcher PID 파일을 정리한다.
    [ -n "$sd" ] && stop_snapshotter "$sd"
    t DOWN_STOPPED "$name"
  fi
}

# bot.pid 가 존재하고 PID 가 살아 있으면 true. stale(파일 있어도 PID 없음) 이면 false.
# 한계: kill -0 는 다른 사용자 소유 PID 에 대해 macOS 에서 EPERM(exit 1)을 반환하므로
# "죽음"으로 오판한다 → stale 취급 → 기동 허용되어 드물게 409 conflict 가능. cctg 는
# 단일 사용자 운영을 전제하므로 무해하나(전역 봇 좌표가 사용자별 $CHANNELS_DIR 하위),
# 다중 사용자 공유 환경에선 이 가드만으로 단독 소유를 보장하지 못한다.
reserved_runner_alive() {
  local pidf="$1/bot.pid" pid
  [ -f "$pidf" ] || return 1
  pid="$(head -n1 "$pidf" 2>/dev/null)"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

# 예약어 채널 전역 봇 기동. lookup 없이 고정 좌표($PWD / $CHANNELS_DIR/<ch>) 사용.
up_reserved() {
  local ch="$1" sd cwd
  # imessage/fakechat 등 channel_spec 미정의 채널은 미지원(ADR-010).
  channel_spec "$ch" plugin >/dev/null 2>&1 || { te ERR_RESERVED_UNSUPPORTED "$ch"; return 1; }
  sd="$CHANNELS_DIR/$ch"
  cwd="$PWD"                                                            # DEC-001: cctg 호출 시점 현재 작업 디렉터리
  [ -d "$cwd" ] || { te ERR_NO_CWD "$(tilde "$cwd")"; te ERR_NO_CWD_HINT_RESERVED; return 1; }   # up_one 과 동형 가드(전역 봇은 복구 경로가 다름)
  [ -f "$sd/.env" ] || { te ERR_NO_TOKEN "$(tilde "$sd/.env")"; return 1; }       # SC-017
  # 단독소유자 가드: cctg-<ch> tmux 세션 OR bot.pid 생존 (ADR-007)
  # DEAD(세션 생존·claude 종료)면 점유 거부 메시지 대신 restart 복구 경로를 안내한다.
  if is_running "$ch"; then
    if claude_alive "$ch"; then te ERR_RESERVED_UP_OCCUPIED "$ch"
    else te ERR_RESERVED_UP_DEAD "$ch" "$PROG" "$ch"; fi
    return 1
  fi
  if reserved_runner_alive "$sd"; then te ERR_RESERVED_UP_RUNNER "$ch"; return 1; fi
  need_claude || return 1

  ensure_shared_settings
  local shared_arg=""
  [ -f "$SHARED_SETTINGS" ] && shared_arg="--settings $(printf '%q' "$SHARED_SETTINGS")"

  local sd_env plugin
  sd_env="$(channel_spec "$ch" statedir_env)"
  plugin="$(channel_spec "$ch" plugin)"
  local launch
  launch="cd $(printf '%q' "$cwd") \
&& export ${sd_env}=$(printf '%q' "$sd") \
&& set -a && source $(printf '%q' "$sd/.env") \
&& { [ -f $(printf '%q' "$sd/launch.env") ] && source $(printf '%q' "$sd/launch.env") || true; } \
&& set +a \
&& MODE_ARG=\"\" \
&& { [ -n \"\${CCTG_PERMISSION_MODE:-}\" ] && MODE_ARG=\"--permission-mode \${CCTG_PERMISSION_MODE}\" || true; } \
&& caffeinate -is claude --channels $plugin $shared_arg \${MODE_ARG} \${CLAUDE_EXTRA_ARGS:-}; exec bash"

  if ! start_session "$(sess_of "$ch")" "$launch" "$(effective_sess_width "$sd")"; then
    te ERR_UP_FAILED "$ch"; return 1
  fi
  t RESERVED_UP "$ch" "$(sess_of "$ch")"
}

# 예약어 채널 전역 봇 정지. cctg 가 기동한 tmux 세션만 kill (ADR-008).
# bot.pid 러너는 종료하지 않음(NFR-003 — cctg 관리 범위 외).
# stop_snapshotter/take_snapshot 미호출(전역 봇에는 cctg launch.env·watcher 없음, P-002).
down_reserved() {
  local ch="$1"
  if is_running "$ch"; then
    if ! tmux kill-session -t "$(sess_t "$ch")"; then
      te ERR_DOWN_FAILED "$ch"; return 1
    fi
    t DOWN_OK "$ch"
  else
    t RESERVED_DOWN_NONE "$ch"
  fi
}
