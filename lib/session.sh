# lib/session.sh — tmux 세션·스냅샷·기동/정지 라이프사이클
# cc-tg.sh 가 런타임 source 하는 모듈(정의·전역설정 전용). 직접 실행하지 않는다.


sess_of() { printf '%s%s' "$SESS_PREFIX" "$1"; }
# tmux 타겟('-t')은 정확 일치가 없으면 접두(prefix)·fnmatch 로 매칭되어, 한 봇 이름이
# 다른 봇 이름의 접두인 경우(cc-tg vs cc-tg-discord) 엉뚱한 세션에 매칭된다. '=' 접두로
# 정확 일치를 강제해 오매칭을 차단한다. 세션을 *찾는* 모든 -t(조회/종료/캡처/attach)에 사용.
# 세션을 *만드는* new-session -s 는 리터럴 이름이므로 적용하지 않는다.
sess_t() { printf '=%s' "$(sess_of "$1")"; }
is_running() { tmux has-session -t "$(sess_t "$1")" 2>/dev/null; }

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
  if tmux capture-pane -p -S -2000 -t "=$sess" > "$snap.tmp" 2>/dev/null; then
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
      if tmux capture-pane -p -S -2000 -t "=$sess" > "$snap.tmp" 2>/dev/null; then
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
  if [ -n "$pid" ]; then
    if [ -z "$marker" ] || ps -ww -p "$pid" -o command= 2>/dev/null | grep -qF "$marker"; then
      kill "$pid" 2>/dev/null
    fi
  fi
  rm -f "$pidf"
}

up_one() {
  local name="$1" cwd sd row
  row="$(lookup "$name")" || { te ERR_NOT_REGISTERED "$name"; return 1; }
  cwd="$(expand "$(cut -f1 <<<"$row")")"
  sd="$(expand "$(cut -f2 <<<"$row")")"
  [ -d "$cwd" ] || { te ERR_NO_CWD "$cwd"; return 1; }
  [ -f "$sd/.env" ] || { te ERR_NO_TOKEN "$sd/.env"; return 1; }
  if is_running "$name"; then t ALREADY_RUNNING "$name"; return 0; fi
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
  if ! tmux new-session -d -s "$(sess_of "$name")" "bash -lc $(printf '%q' "$launch")"; then
    te ERR_UP_FAILED "$name"; return 1
  fi
  t UP_OK "$name" "$cwd" "$sd" "$(sess_of "$name")"

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
  [ -d "$cwd" ] || { te ERR_NO_CWD "$cwd"; return 1; }                 # up_one 과 동형 가드
  [ -f "$sd/.env" ] || { te ERR_NO_TOKEN "$sd/.env"; return 1; }       # SC-017
  # 단독소유자 가드: cctg-<ch> tmux 세션 OR bot.pid 생존 (ADR-007)
  if is_running "$ch"; then te ERR_RESERVED_UP_OCCUPIED "$ch"; return 1; fi
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

  if ! tmux new-session -d -s "$(sess_of "$ch")" bash -lc "$launch"; then
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
