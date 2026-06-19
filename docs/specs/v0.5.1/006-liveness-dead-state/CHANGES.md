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
| `docs/commands.md`·`docs/commands.ko.md` | status 상태 열거에 DEAD 추가(설명·정렬순서), `--json` state 에 `dead`·null uptime 명시. |
| `.claude/docs/infra.md` | status 상태에 DEAD 반영. |
| `.claude/docs/constitution.md`·`.claude/docs/context.md` | bats 스위트 수치 최신화(81/119 → 201) + context 에 ps stub 반영. |

## 설계 결정 (decisions.md)

- **DEC-001**: `up`/`is_running` 라이프사이클 불변(자동복구 안 함, 수동 restart) — 사용자 A=2.
- **DEC-002**: 상태명 `DEAD` — 사용자 B.
- **DEC-003**: 감지 신호 = pane_pid 자손 트리의 `claude`(채널-무관 단일 불변 신호). `pane_current_command` 는 claude 생존 중에도 `bash` 라 폐기(실측).

## 검증

- bash -n / shellcheck -S warning / i18n 키 패리티(169키) / bats **196 통과**(신규 5 포함).
- 회귀 증명: `claude_alive` 를 항상-true 로 강제 시 DEAD 케이스 3건 FAIL → 실구현 시 전부 PASS.
- 실 tmux 3.6b 로 실행 중 봇 프로세스 트리 실측(claude=pane_pid 자손)으로 신호 타당성 확인.

## 완성도 보완 (2026-06-19 07:25, 사용자 분석 요청 후)

자가 비판 분석에서 도출한 갭 반영:

- **봇당 `ps -ax` 스캔 2회 → 1회**: 텍스트 status 가 `_status_class`(정렬 분류)와 렌더에서 `claude_alive` 를 각각 호출하던 것을, 분류 시 판정한 state 를 렌더 함수 인자(`$2`)로 넘겨 재판정을 제거. 렌더는 더 이상 `claude_alive`/`is_running` 을 호출하지 않는다. `_status_render_{project,reserved}_bot` 을 state 기반 `case` 로 재작성.
- **예약봇 DEAD 테스트 추가**: 프로젝트봇만 덮던 DEAD 커버리지를 예약(telegram) 경로까지 확장(liveness.bats #5).
- **풀패스 comm 테스트 추가**: `ps -o comm=` 가 풀패스(`/usr/local/bin/claude`)를 반환하는 경우에도 RUNNING 판정됨을 검증(#6). 정규식 `(^|/)claude$` 의 풀패스 처리 보증.
- **가정 문서화**: `claude_alive` 주석에 "claude 의 comm 이 'claude' 라는 가정 + 프로세스명 변경 시 caffeinate 보조신호 확장" 명시.

- **`up` DEAD 인지 메시지(#7)**: `up <dead-bot>` 이 기존엔 `Already running` 만 출력하고 restart 안내는 `status` 전용이라 discoverability 갭이 있었다. `up_one`/`up_reserved` 의 `is_running` 분기에서 `claude_alive` 를 판정해 DEAD 면 `ALREADY_RUNNING_DEAD`(프로젝트봇, exit 0 유지) / `ERR_RESERVED_UP_DEAD`(예약봇, 거부) 로 `restart` 경로를 안내. 자동 재기동은 안 함(A=2).
- **awk 이식성·`up`-DEAD UX 한계 문서화(#4/#7)**: decisions.md DEC-003(awk 호스트 의존·CI 미검증)·DEC-001(up DEAD 메시지 분기)에 명시.

검증: bats **201 통과**(liveness 10케이스 — status 7 + up 3). claude_alive 호출지점 = 분류 2 + json 1 + up 2 (status 렌더 0).

## 범위 밖 (별도 차수)

- P2 자동복구(restart-on-failure)·재부팅 지속성(launchd), P3 장애 통지 — TODO 잔존.
- last-activity(`last-session.log` mtime) 표기 — 이번 스코프 미포함.
