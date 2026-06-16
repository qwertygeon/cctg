# lib/session.sh — tmux 세션·스냅샷·기동/정지 라이프사이클
# cc-tg.sh 가 런타임 source 하는 모듈(정의·전역설정 전용). 직접 실행하지 않는다.


sess_of() { printf '%s%s' "$SESS_PREFIX" "$1"; }
is_running() { tmux has-session -t "$(sess_of "$1")" 2>/dev/null; }

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
  if tmux capture-pane -p -S -2000 -t "$sess" > "$snap.tmp" 2>/dev/null; then
    mv "$snap.tmp" "$snap" && chmod 600 "$snap" 2>/dev/null
  else
    rm -f "$snap.tmp"
  fi
}

# 실행 중인 봇 세션을 interval 초마다 스냅샷하는 백그라운드 watcher 기동(크래시·재부팅 대비).
# 세션이 사라지면 watcher 가 스스로 종료한다. PID 는 <sd>/.snapshotter.pid 로 추적해 down 시 정지.
# nohup + fd 리다이렉트로 호출 셸과 분리되어 cctg 종료 후에도 계속 동작한다.
start_snapshotter() {
  local name="$1" sd="$2" interval="$3" sess pidf
  sess="$(sess_of "$name")"; pidf="$sd/.snapshotter.pid"
  stop_snapshotter "$sd"   # 재기동 시 기존 watcher 정리
  # 루프 본문은 단일 인용 문자열이라 부모 셸 확장과 무관(인자로 값 전달).
  nohup bash -c '
    sess="$1"; sd="$2"; interval="$3"; snap="$sd/last-session.log"
    while tmux has-session -t "$sess" 2>/dev/null; do
      if tmux capture-pane -p -S -2000 -t "$sess" > "$snap.tmp" 2>/dev/null; then
        mv "$snap.tmp" "$snap" && chmod 600 "$snap" 2>/dev/null
      else
        rm -f "$snap.tmp"
      fi
      sleep "$interval"
    done
    rm -f "$sd/.snapshotter.pid"
  ' cctg-snapshotter "$sess" "$sd" "$interval" >/dev/null 2>&1 &
  printf '%s\n' "$!" > "$pidf"
  chmod 600 "$pidf" 2>/dev/null
}

# watcher 정지(있으면). PID 파일을 읽어 종료하고 파일 제거. 없으면 무동작.
stop_snapshotter() {
  local pidf="$1/.snapshotter.pid" pid
  [ -f "$pidf" ] || return 0
  pid="$(head -n1 "$pidf" 2>/dev/null)"
  [ -n "$pid" ] && kill "$pid" 2>/dev/null
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

  # 공통 설정(권한 정책)을 --settings 로 주입. 없으면 시드.
  ensure_shared_settings
  local shared_arg=""
  [ -f "$SHARED_SETTINGS" ] && shared_arg="--settings $(printf '%q' "$SHARED_SETTINGS")"

  # 상태 디렉터리/토큰을 분리 주입하고 caffeinate로 sleep 방지하며 채널 세션 기동.
  # 봇별 launch.env(있으면)에서 CCTG_PERMISSION_MODE / CLAUDE_EXTRA_ARGS 를 읽어 claude 인자로 전달한다.
  #   - CCTG_PERMISSION_MODE 가 있으면 --permission-mode 로 공통 defaultMode 를 override (없으면 공통값 사용).
  #   - \$ 이스케이프로 런타임(launch.env source 이후)에 단어 분리되도록 한다.
  local launch
  launch="cd $(printf '%q' "$cwd") \
&& export TELEGRAM_STATE_DIR=$(printf '%q' "$sd") \
&& set -a && source $(printf '%q' "$sd/.env") \
&& { [ -f $(printf '%q' "$sd/launch.env") ] && source $(printf '%q' "$sd/launch.env") || true; } \
&& set +a \
&& MODE_ARG=\"\" \
&& { [ -n \"\${CCTG_PERMISSION_MODE:-}\" ] && MODE_ARG=\"--permission-mode \${CCTG_PERMISSION_MODE}\" || true; } \
&& caffeinate -is claude --channels $PLUGIN $shared_arg \${MODE_ARG} \${CLAUDE_EXTRA_ARGS:-}; exec bash"

  tmux new-session -d -s "$(sess_of "$name")" "bash -lc $(printf '%q' "$launch")"
  t UP_OK "$name" "$cwd" "$sd" "$(sess_of "$name")"

  # 옵트인: launch.env 의 CCTG_LOG_SNAPSHOT_INTERVAL(초)가 양수면 주기 스냅샷 watcher 기동.
  local snap_iv; snap_iv="$(snapshot_interval_of "$sd")"
  if printf '%s' "$snap_iv" | grep -qE '^[0-9]+$' && [ "$snap_iv" -gt 0 ]; then
    start_snapshotter "$name" "$sd" "$snap_iv"
    t UP_SNAPSHOT_ON "$snap_iv"
  fi
}

down_one() {
  local name="$1" row sd=""
  [ -n "$name" ] && row="$(lookup "$name")" && sd="$(expand "$(cut -f2 <<<"$row")")"
  if is_running "$name"; then
    # 정지 watcher 가 우리 최종 스냅샷을 덮어쓰지 않도록 먼저 멈춘다.
    [ -n "$sd" ] && stop_snapshotter "$sd"
    # 종료 전 마지막 세션 출력을 보존한다 — 종료 후에도 `cctg logs` 로 조회 가능.
    [ -n "$sd" ] && take_snapshot "$(sess_of "$name")" "$sd"
    tmux kill-session -t "$(sess_of "$name")"
    t DOWN_OK "$name"
  else
    # 세션이 외부에서 종료된 경우 남아 있을 수 있는 watcher PID 파일을 정리한다.
    [ -n "$sd" ] && stop_snapshotter "$sd"
    t DOWN_STOPPED "$name"
  fi
}
