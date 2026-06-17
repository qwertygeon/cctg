---
작성: Spec Agent
버전: v1.0
최종 수정: 2026-06-17
상태: 확정
---

# Assumptions: cli-convenience-patches

| ID | 가정 내용 | 확인 필요 여부 | 확인 방법 |
|---|---|---|---|
| ASM-001 | 예약어(telegram/discord) 전역 봇 기동 시 cwd 는 `$PWD`(cctg 호출 시점 현재 작업 디렉터리)를 사용한다. 전역 봇은 레지스트리에 없으므로 lookup() 으로 cwd 를 조회할 수 없으며, 호출 시점의 셸 현재 디렉터리를 그대로 사용한다. | 불필요 — DEC-001 로 확정(사용자 명시, 2026-06-17) | DEC-001 로 확정(사용자 명시, 2026-06-17) |
| ASM-002 | `completions/_cctg` 와 `completions/cctg.bash` 에 `cctg` 및 `config <name>` 액션 목록이 있으며, 신규 액션(cwd/token) 추가 시 양쪽 파일을 동시에 갱신해야 한다. (ADR-003: lib 를 source 하지 않는 로컬 리터럴 미러 방식) | 불필요 — 코드 확인됨 | `completions/_cctg:60` / `completions/cctg.bash:29-30` 확인 |
| ASM-003 | 서브커맨드별 `--help` 는 cc-tg.sh 의 case 디스패처에서 각 서브커맨드 진입 전 `--help` 인자를 감지하거나, 각 cmd_*() 함수 내에서 인자로 처리한다. 구현 패턴은 Design Agent 가 결정한다. | 불필요 — 범위 내 | Design Agent 결정 사항 |
| ASM-004 | 예약어 `up` 의 단독소유자 가드에서 `bot.pid` PID 생존 여부는 `kill -0 <pid>` 로 확인한다. macOS Bash 3.2 에서 `kill -0` 은 지원된다. | 불필요 — macOS 기본 동작 | bash 3.2 kill -0 지원 확인됨 |
| ASM-005 | `config <name> cwd` 의 레지스트리 갱신은 `registry.sh` 의 기존 `rename_registry_line()` 함수와 동일한 awk+mktemp+mv 패턴으로 신규 함수를 작성하거나, 기존 함수를 재활용한다. 구현 패턴은 Design Agent 가 결정한다. | 불필요 — 범위 내 | Design Agent 결정 사항 |
