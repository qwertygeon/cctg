# CHANGES — v0.5.1/006-liveness-dead-state

> 작성: 2026-06-19 07:10 | 상태: 구현 완료·검증 통과

## 무엇을 / 왜

`cctg status` 의 거짓 UP 제거. 기동 launch 가 `caffeinate -is claude …; exec bash` 로 끝나 claude 가 죽어도 pane 에 bash 가 남아 tmux 세션이 생존 → 기존 `is_running()`(=`tmux has-session`)이 죽은 봇을 `RUNNING` 으로 오보했다. 세션 내 `claude` 생존을 직접 확인해 신규 상태 `DEAD` 로 구분한다.

## 변경 파일

| 파일 | 변경 |
|---|---|
| `lib/session.sh` | `claude_alive(name)` 신설 — `tmux #{pane_pid}` → `ps -ax -o pid=,ppid=,comm=` → awk BFS 로 자손 트리에서 `comm~/(^|/)claude$/` 탐색. BSD ps/Bash 3.2 호환(맵·BFS=awk). |
| `lib/commands.sh` | `_status_class`·`_status_class_reserved`(정렬 분류), `_status_render_project_bot`·`_status_render_reserved_bot`(렌더), `status_json` 에 `dead` 분기 추가. 정렬 순서 running→dead→broken→stopped. `is_running` 불변. |
| `messages/en.sh`·`messages/ko.sh` | `STATUS_DEAD`(`[DEAD   ]` 라벨), `STATUS_HINT_DEAD`(restart 복구 힌트). |
| `tests/stubs/tmux` | `display-message` 포맷 인지 — `#{pane_pid}`→`FAKE_TMUX_PANE_PID`. |
| `tests/stubs/ps` | 신규. `comm=`(claude_alive) 호출만 가로채 `FAKE_PS_TREE`/기본 healthy 트리 반환, `command=`(snapshotter) 는 실제 ps 로 passthrough. |
| `tests/test_helper.bash` | `FAKE_TMUX_PANE_PID=700001` 기본 — running 세션이 기본 healthy 트리로 RUNNING 판정. |
| `tests/liveness.bats` | 신규 5케이스(RUNNING/DEAD 텍스트·JSON·정렬). |
| `CHANGELOG.md` | `[Unreleased] Added` 항목. |
| `docs/TODO.md` | P1 항목 제거(완료) + supervision 섹션 노트 갱신. |

## 설계 결정 (decisions.md)

- **DEC-001**: `up`/`is_running` 라이프사이클 불변(자동복구 안 함, 수동 restart) — 사용자 A=2.
- **DEC-002**: 상태명 `DEAD` — 사용자 B.
- **DEC-003**: 감지 신호 = pane_pid 자손 트리의 `claude`(채널-무관 단일 불변 신호). `pane_current_command` 는 claude 생존 중에도 `bash` 라 폐기(실측).

## 검증

- bash -n / shellcheck -S warning / i18n 키 패리티(169키) / bats **196 통과**(신규 5 포함).
- 회귀 증명: `claude_alive` 를 항상-true 로 강제 시 DEAD 케이스 3건 FAIL → 실구현 시 전부 PASS.
- 실 tmux 3.6b 로 실행 중 봇 프로세스 트리 실측(claude=pane_pid 자손)으로 신호 타당성 확인.

## 범위 밖 (별도 차수)

- P2 자동복구(restart-on-failure)·재부팅 지속성(launchd), P3 장애 통지 — TODO 잔존.
- last-activity(`last-session.log` mtime) 표기 — 이번 스코프 미포함.
