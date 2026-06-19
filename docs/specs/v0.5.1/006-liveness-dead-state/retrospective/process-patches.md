---
작성: Retrospective Agent
버전: v1.0
최종 수정: 2026-06-19 10:59
상태: 작성중
---

# Process Patches: v0.5.1/006-liveness-dead-state

> direct 모드 차수. 프로세스·흐름 제어 개선 제안. 적용은 main session 이 사용자 승인 후 수행.

## 목차

- [PROC-001. 외부 도구 동작은 추측 말고 실측으로 확정](#proc-001-외부-도구-동작은-추측-말고-실측으로-확정)
- [PROC-002. direct 모드 결정 체크포인트의 채널 경유 운용](#proc-002-direct-모드-결정-체크포인트의-채널-경유-운용)
- [PROC-003. 완료 항목 제거 시 미구현 하위 항목 동반 삭제 방지](#proc-003-완료-항목-제거-시-미구현-하위-항목-동반-삭제-방지)
- [PROC-004. 검증 stub 의 도구 quirk 재현 강제](#proc-004-검증-stub-의-도구-quirk-재현-강제)

---

## PROC-001. 외부 도구 동작은 추측 말고 실측으로 확정

- 현재 프로세스: 외부 도구(여기선 tmux `pane_current_command`)의 출력을 문서/직관 기반으로 가정하고 설계에 반영하는 경향. 본 차수 초기에 liveness 신호로 `pane_current_command` 를 채택하려다 실측에서 claude 생존 중에도 `bash` 로 나와 폐기했다.
- 문제점: 외부 도구 동작을 추측으로 확정하면 잘못된 신호를 설계에 박을 위험. `pane_current_command`(폐기) → `pane_pid` 자손 트리의 `claude`(채택)로 전환은 실행 중 프로세스 트리를 직접 관찰(실측)해서야 확정됐다.
- 개선 방향: "liveness/health 신호 등 **외부 도구의 런타임 출력에 의존하는 설계 결정**은 venv 인용·문서가 아니라 **실행 중 상태를 직접 관찰(실측)** 해 확정한다"를 설계 게이트로. (전역 `python.md §외부 라이브러리 private API lifecycle 검증` 의 venv-실측 원칙과 동류 — CLI 도구 출력에도 일반화.) decisions.md DEC-003 "근거(실측)" 항목이 이 원칙의 모범 적용 사례.
- 영향 범위: Design Agent(research.md 외부 도구 동작 확인 절) / 전역 `python.md` 의 외부 의존 검증 원칙을 "CLI 도구 런타임 출력"까지 일반화. 본 차수는 direct 모드라 main session 의 설계 절차에 해당.

## PROC-002. direct 모드 결정 체크포인트의 채널 경유 운용

- 현재 프로세스: 결정 체크포인트(비자명 결정)는 AskUserQuestion(터미널 UI) 또는 자유 대화로 수집하고 decisions.md 에 기록한다(agent-rules §4.4). 채널(Discord/Telegram) 경유 세션에서의 운용 절차가 명문화돼 있지 않다.
- 문제점: 채널 세션에서 AskUserQuestion 의 터미널 UI 는 채널에 표시되지 않아 사용할 수 없다. 본 차수는 Discord 로 다수 마이크로 결정(버전 폴더·상태명 DEAD·up 처리 A=2·문서화 범위)을 모두 `reply` 텍스트로 처리했다(DEC-001~003 기록).
- 개선 방향: 채널 경유 세션이면 결정 체크포인트를 `reply` 로 선택지 제시·수집하고 decisions.md DEC-XXX 기록한다는 절차를 명시(PATCH-004 와 연동). 더불어 **명확한 프로젝트 컨벤션이 있는 결정(예: 누적 spec 폴더 v0.5.1/NNN)** 은 사용자 질의 없이 컨벤션 근거로 확정하고 pipeline-log 에 근거를 남기면 충분(OBS-6 — 과잉 질의 방지).
- 영향 범위: `~/.claude/rules/on-demand/claude-code-tools.md §7` / pipeline SKILL(direct 모드 결정 절차).

## PROC-003. 완료 항목 제거 시 미구현 하위 항목 동반 삭제 방지

- 현재 프로세스: 작업 완료 후 문서화 단계에서 완료된 TODO 섹션을 제거한다(TODO.md "완료하면 여기서 제거" 정책, L3).
- 문제점: 완료 섹션을 통째로 제거하면 그 섹션에 묶인 **미구현 하위 항목**이 함께 사라진다. 본 차수에서 P1 섹션 제거 시 미구현 항목(status last-activity)이 동반 삭제됐고 사용자 점검에서야 발견·복구됐다.
- 개선 방향: TODO/이슈 완료 제거 전 "동일 섹션 하위 미구현 항목 1건씩 완료 여부 확인 → 미구현분은 잔존/상위 승격" 점검을 문서화 게이트에 추가(PATCH-005).
- 영향 범위: Docs Agent(06-docs) 문서 갱신 절차 / direct 모드 문서화 절차.

## PROC-004. 검증 stub 의 도구 quirk 재현 강제

- 현재 프로세스: 외부 도구를 stub/fake 로 대체할 때, 그 도구의 비자명 동작(quirk) 재현 의무가 tmux 한정(prefix 매칭)으로만 명문화돼 있다(tmux.md).
- 문제점: 본 차수에서 두 부류의 quirk 미재현 회귀가 드러났다 — (1) tmux 타겟 종류(`=NAME` 세션 vs `=NAME:` pane), (2) `ps -o comm=` basename vs 풀패스. 기존 stub 이 행복경로만 모델링해 두 회귀를 통과시킬 수 있었다(정정: tmux stub `resolve_pane()` 추가, ps stub 조건부 가로채기 + liveness.bats #6 풀패스 테스트).
- 개선 방향: "stub 은 의존 도구의 회귀 유발 quirk(argv 토큰·타겟 종류·접두/substring 매칭·basename/풀패스 출력)를 재현한다"를 도구-불문 일반 원칙으로 Test Agent 정의에 등재(PATCH-002), 구체 사례는 도구별 on-demand 규칙으로 분리(tmux=PATCH-001, ps=PATCH-003 재배치).
- 영향 범위: Test Agent(05) AUTHORING 모드 / `tmux.md` / 신규 Bash·BSD 셸 규칙.
