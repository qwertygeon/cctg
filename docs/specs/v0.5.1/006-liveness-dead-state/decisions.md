# decisions.md — v0.5.1/006-liveness-dead-state

> 작성: 2026-06-19 07:04 | 버전: 1.0 | 최종 수정: 2026-06-19 07:04 | 상태: 확정

## DEC-001. `up` 의 dead 상태 처리 = status 정확화만 (자동 재기동 안 함)

- **결정**: claude 가 죽어 세션만 남은 `dead` 상태를 `status`/`--json` 에서 정확히 표기하되, `up`/`is_running` 의 라이프사이클 동작은 **현행 유지**한다. 자동 stale 정리·재기동은 하지 않으며 사용자가 수동 `restart` 한다.
- **근거**: 사용자 확정(A=2). 자동복구(restart-on-failure)는 TODO P2 별도 차수(옵트인). 본 차수는 "거짓 UP 제거(가시성)"에 한정해 표면·위험을 최소화(P-005).
- **영향**: `is_running()` 불변 → `up`/`down`/`restart` 회귀 위험 0. `status` 만 신규 분기.

## DEC-002. 신규 상태명 = `DEAD`

- **결정**: 세션은 있으나 claude 자손이 없는 상태의 명칭을 `DEAD` 로 한다(텍스트 라벨 `[DEAD   ]`, json `state:"dead"`).
- **근거**: 사용자 확정(B). CRASHED/STALE 후보 대비 "프로세스 죽음"을 직관적으로 전달.

## DEC-003. liveness 감지 신호 = pane_pid 자손 트리의 `claude` 프로세스

- **결정**: tmux `#{pane_pid}` 의 프로세스 자손 트리에서 `comm` 이 `claude`(경로 basename) 인 프로세스 존재 여부로 판정한다. `pane_current_command` 는 사용하지 않는다.
- **근거(실측)**: 실행 중 봇에서 `pane_current_command` 가 claude 생존 중에도 `bash` 로 나와 신뢰 불가. pane_pid(2721) 자손에 `claude`(2732) 존재가 유일한 신뢰 신호. 모든 채널이 동일 launch(`caffeinate -is claude --channels $plugin`)로 떠 채널 플러그인이 claude 자식으로 동작 → `claude` 가 **채널-무관 단일 불변 신호**(확장성: 채널별 분기 불필요).
- **제약 준수**: BSD `ps -ax -o pid=,ppid=,comm=` + awk(BFS·맵)로 Bash 3.2 호환(P-001). comm 만 매칭하여 토큰(argv 의 `--settings` 등) 비노출(P-003).
- **엣지**: claude 기동 직후/종료 직전 짧은 전이 구간은 스냅샷 시점 판정이라 transient `dead` 가능(허용 — status 는 순간 조회). 향후 P2 에서 grace 적용 검토.
