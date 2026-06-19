---
작성: Retrospective Agent
버전: v1.1
최종 수정: 2026-06-19 11:13
상태: 적용 완료 (2026-06-19, 사용자 승인 "ABC 전부 적용")
적용 결과:
  - PATCH-001/002/004/005/006 + PATCH-003(신규 shell.md + CLAUDE.md 등록) 전역 적용 → 변경로그 ~/.claude/docs-change-logs/2026-06-19-001.md
  - PATCH-CXT-003 (context.md §3.3 DEAD) 프로젝트 적용 → {project}/.claude/docs-change-logs/2026-06-19-001.md
  - PATCH-CXT-001/002 는 차수 중 기 반영(갱신 불필요 검토 완료)
---

# Agent Patches: v0.5.1/006-liveness-dead-state

> 본 차수는 **direct 모드**(main session 이 직접 수행, Phase Agent orchestration 없음)로 진행됐다.
> 따라서 패치 근거는 main session 이 전달한 OBS-1~6 + decisions.md + pipeline-log.md + 코드/테스트/문서다.
> 모든 패치는 **후보**이며, 적용은 main session 이 사용자 승인 후 수행한다(agent-rules §12).
>
> 각 전역 패치 후보는 "패치 대상 적합성 2단계 검토"(범용성·역할정합) 결과를 1줄로 명시한다.

## 목차

- [전역 규칙·참조 문서·스킬 패치](#전역-규칙참조-문서스킬-패치)
- [Agent 정의 패치](#agent-정의-패치)
- [프로젝트 context.md / infra.md 갱신 패치 (PATCH-CXT)](#프로젝트-contextmd--inframd-갱신-패치-patch-cxt)
- [기각·재배치된 후보](#기각재배치된-후보)

---

## 전역 규칙·참조 문서·스킬 패치

### PATCH-001: tmux.md — 검증용 stub 이 실제 tmux 의 타겟 종류(session vs pane) quirk 를 재현해야 한다

- 대상 파일: `~/.claude/rules/on-demand/tmux.md`
- 대상 섹션: `## 테스트 작성 규칙` (기존 "stub/fake 로 대체 … 실제 tmux 의 접두 매칭 동작을 재현" 항목 확장)
- 현재 내용: 테스트 작성 규칙은 "실제 tmux 의 **접두(prefix) 매칭** 동작을 재현해야 한다"만 명시한다(정확매칭만 흉내내면 prefix 충돌 버그가 빠져나간다는 근거).
- 변경 내용: stub 이 재현해야 할 quirk 목록에 **타겟 종류 구분(target-session vs target-pane)** 을 추가한다. 구체적으로: `=NAME` 단독은 `has-session`/`kill-session`(target-session)에서만 유효하고, `capture-pane`/`display-message`(target-pane)에서는 `=NAME:`(뒤에 `:`)로 window/pane 을 명시해야 resolve 된다. stub 이 두 형식을 무구분으로 모두 수락하면 `=NAME` 을 pane 명령에 넘기는 회귀(빈 출력/can't find pane)가 스위트를 통과해 빠져나간다. 일반화 문구: "stub 은 의존 도구의 argv 토큰 종류·타겟 종류·접두 매칭 등 **회귀를 유발하는 quirk** 를 재현해야 한다 — 행복경로만 모델링한 stub 은 그 quirk 류 버그를 잡지 못한다."
- 변경 근거: OBS-1. 본 차수에서 `=NAME`(세션) vs `=NAME:`(pane) 문법 차이로 `logs`/`status`/snapshot 회귀가 발생했고, 기존 stub(접두매칭만 모델)이 이를 통과시켰다. 정정 후 `tests/stubs/tmux` 에 `resolve_pane()` 가 추가되어 target-pane quirk 를 재현한다(확인: `tests/stubs/tmux` L55-69, L106-125).
- 강제도: SHOULD (테스트 작성 규칙 — 기존 항목과 동일 강제도)
- 적합성: 범용 O(tmux 를 쓰는 모든 프로젝트의 검증 stub 에 적용) / 역할정합 O(tmux.md "테스트 작성 규칙"의 직접 확장)

### PATCH-002: rules/on-demand 신설 — 검증용 stub/fake 설계 원칙(도구 quirk 재현 의무) 일반화

- 대상 파일: 후보 (a) `~/.claude/agents/05-test.md` "AUTHORING 모드 사전 점검" 절에 1항 추가, 또는 (b) test-agent detail(`agents/detail/05-test.detail.md`)에 원칙 항목 추가
- 대상 섹션: 테스트 stub/fake 설계 원칙
- 현재 내용: Test Agent 정의에 "stub 은 의존 도구의 행복경로만 모델링하면 quirk 류 회귀를 놓친다"는 일반 원칙이 없다(tmux 한정 교훈만 tmux.md 에 존재).
- 변경 내용: 도구-불문 일반 원칙 추가 — "외부 도구를 stub/fake 로 대체할 때, 테스트 대상 코드가 의존하는 도구의 **비자명한 동작(quirk)** — argv 토큰 형식·타겟 종류·접두/substring 매칭·basename vs 풀패스 출력 등 — 을 재현한다. 행복경로만 흉내낸 stub 은 그 quirk 에서 발생하는 회귀를 통과시킨다. 구체 사례는 도구별 on-demand 규칙(tmux.md 등) 참조." + 본 차수 사례 2건(tmux `=NAME` pane 타겟, `ps -o comm=` basename vs 풀패스)을 근거 주석으로.
- 변경 근거: OBS-1(tmux 타겟 종류) + OBS-2(`ps -o comm=` basename/풀패스 — 정정 테스트 liveness.bats #6 "full-path claude comm"). 두 사례 모두 "stub 이 quirk 미재현 시 회귀 통과" 동일 부류.
- 강제도: SHOULD
- 적합성: 범용 O(언어·도구 불문 외부 도구 stub 일반 원칙) / 역할정합 O(Test Agent 의 stub 작성 책임) — **단 구체 도구 한정 quirk 예시는 본 일반 원칙에 두지 않고 도구별 on-demand 규칙으로 분리(tmux 사례=PATCH-001, ps 사례=PATCH-003)하여 오염 방지.**

### PATCH-003: python.md(또는 신규 bash/shell on-demand) — `ps -o comm=` basename/풀패스·필드 분해 quirk 검증

- 대상 파일: 후보 — 본 사례는 Bash/BSD 한정이라 Python 규칙(python.md)에 두지 않는다. **재배치 권고**: 신규 `~/.claude/rules/on-demand/shell.md`(없으면) 또는 `tmux.md` 와 동급의 macOS/BSD 셸 도구 규칙 파일에 등재. 임시로는 프로젝트 context.md/decisions 로 흡수 가능.
- 대상 섹션: 외부 프로세스 조회(`ps`) 출력 파싱 주의
- 현재 내용: 전역 규칙에 BSD `ps -o comm=` 의 출력 형태(호출 방식에 따라 basename `claude` 또는 풀패스 `/usr/local/bin/claude`)·경로 공백 시 필드 분해 깨짐 quirk 가 문서화돼 있지 않다.
- 변경 내용: "`ps -o comm=` 출력은 프로세스 호출 방식에 따라 basename 또는 풀패스로 나온다. 프로세스명 매칭 정규식은 `(^|/)NAME$` 처럼 양쪽을 모두 수용해야 한다. comm 필드는 공백 포함 경로에서 분해가 깨질 수 있으니, 경로 공백 가능성이 있으면 `command=` 전체 + 앵커 매칭 또는 `-p <pid> -o comm=` 개별 조회를 고려한다." (BSD/macOS 한정 태그)
- 변경 근거: OBS-2 + DEC-003(실측: `pane_current_command` 가 claude 생존 중에도 bash 라 폐기) + TODO P3 "claude_alive comm 공백 경로 엣지". 정정 테스트 liveness.bats #6 가 풀패스 RUNNING 판정을 보증.
- 강제도: SHOULD
- 적합성: **재배치 — python.md → shell/BSD 한정 규칙 (사유: Python 무관, Bash/BSD ps 한정 — 범용 X. 전역 일반 규칙 오염 방지).** 적용 보류 가능(낮은 빈도). 우선 프로젝트 decisions.md 에 이미 기록됨.

### PATCH-004: claude-code-tools.md §7 — direct 모드에서 채널(Discord/Telegram) 경유 결정 체크포인트 운용 노트

- 대상 파일: `~/.claude/rules/on-demand/claude-code-tools.md`
- 대상 섹션: §7 AskUserQuestion — 구조화된 사용자 입력 (또는 §2 인근)
- 현재 내용: AskUserQuestion 은 터미널 UI 도구로 전제돼 있고, 채널(Discord/Telegram) 세션에서 진행하는 경우의 대체 경로가 명시돼 있지 않다.
- 변경 내용: "[SHOULD] [main] 세션이 채널(Discord/Telegram) 경유로 구동 중이면 AskUserQuestion 의 터미널 UI 가 채널에 보이지 않으므로, 구조화된 결정도 `reply` 텍스트로 선택지를 제시·수집한다. 비자명 결정은 decisions.md DEC-XXX 로 기록한다(direct 모드 결정 체크포인트는 채널 reply 로 운용 가능)." 근거 주석: 채널 메시지 응답 원칙(전역 CLAUDE.md)과 정합.
- 변경 근거: OBS-3. 본 차수는 Discord 채널로 다수 마이크로 결정(버전 폴더·상태명·up 처리·문서화 범위)을 reply 로 주고받았고, DEC-001~003 으로 기록됐다. AskUserQuestion 은 사용 불가했다.
- 강제도: SHOULD
- 적합성: 범용 O(채널 경유 세션은 cctg 외 다른 프로젝트에도 발생 가능) / 역할정합 O(claude-code-tools.md 의 도구 활용 정책)

---

## Agent 정의 패치

### PATCH-005: 07-retrospective(또는 06-docs) — "완료 항목 제거 시 미구현 하위/연관 항목 보존" TODO hygiene 게이트

- 대상 파일: 후보 (a) `~/.claude/agents/06-docs.md`(문서 갱신 단계에서 TODO 갱신 시), 또는 (b) `~/.claude/skills/pipeline/SKILL.md`(direct 모드 문서화 절차)
- 대상 섹션: 문서/TODO 갱신 절차
- 현재 내용: 완료된 작업의 TODO 섹션을 제거할 때, 그 섹션에 묶여 있던 **미구현 하위·연관 항목** 을 함께 떨어뜨리지 않도록 점검하라는 명시 게이트가 없다.
- 변경 내용: "[SHOULD] TODO/이슈 목록에서 완료 항목(섹션)을 제거할 때, 동일 섹션 하위의 **미구현/미착수 항목** 을 식별해 잔존시키거나 적절한 상위 항목으로 승격한다(완료 처리가 미구현 항목을 동반 삭제하지 않도록). 제거 전 해당 섹션의 하위 항목을 1건씩 완료 여부 확인."
- 변경 근거: OBS-4. 본 차수에서 완료된 P1 섹션을 통째 제거하며 그 하위 미구현 항목(status last-activity)이 함께 떨어졌고, 사용자 점검에서 발견·복구됐다(TODO.md 현재 P3 "status last-activity 표기"로 복원 확인 — L66-72).
- 강제도: SHOULD
- 적합성: 범용 O(TODO/이슈 hygiene 은 모든 프로젝트 공통) / 역할정합 O(Docs Agent 의 문서 갱신 책임)

### PATCH-006: 07-retrospective(또는 06-docs) — "문서화만 하고 미구현"인 재사용 가능 미래작업의 가시성 승격 기준

- 대상 파일: 후보 `~/.claude/agents/06-docs.md` 또는 `~/.claude/agents/07-retrospective.md`(미래작업 가시성 점검)
- 대상 섹션: 미래작업/스코프 컷 가시성
- 현재 내용: spec 폴더의 decisions.md / scope.md 에 기록된 "수용했으나 미구현"인 재사용 가능 항목을 프로젝트 수준 TODO(또는 이슈 트래커)로 승격하는 기준이 없다.
- 변경 내용: "[SHOULD] decisions.md/scope.md 에 기록된 '문서화만 하고 미구현'인 항목 중 **재사용 가능·후속 차수 후보** 인 것은 프로젝트 수준 TODO(`docs/TODO.md` 등) 또는 이슈로 승격한다 — spec 폴더에만 묻히면 가시성이 낮아 후속 작업에서 누락된다. 일회성·이번-차수 한정 결정은 승격하지 않는다."
- 변경 근거: OBS-5. 본 차수에서 P2/P3 미래작업(자동복구·재부팅 지속성·통지·last-activity·liveness 견고화·comm 공백 엣지)이 docs/TODO.md 로 승격돼 가시성을 확보했다(TODO.md L42-80, L170-176 확인).
- 강제도: SHOULD
- 적합성: 범용 O(미래작업 가시성은 공통) / 역할정합 O(Docs/Retrospective 의 산출물 가시성 책임)

---

## 프로젝트 context.md / infra.md 갱신 패치 (PATCH-CXT)

> 본 차수의 context.md / infra.md / constitution.md 갱신은 **이미 본 차수에서 main session 이 수행**했다
> (CHANGES.md §변경 파일: infra.md status DEAD 반영, constitution+context bats 수치 201 최신화, context ps stub 반영).
> 아래는 잔여·검증 결과다.

### PATCH-CXT-001 (검토 결과: 갱신 불필요 — 이미 반영됨)

- 대상 파일: `{project}/.claude/docs/infra.md`
- 대상 섹션: §4 모니터링·로깅 / §5 연결 실패 재시도
- 변경 내용: 갱신 불필요. infra.md §4(L39) 가 이미 "RUNNING/uptime/DEAD/BROKEN + 복구 힌트; DEAD=세션 생존·claude 종료를 pane 자손 트리로 감지"로 본 차수 변경을 반영. §5(L46) 도 "stopped/BROKEN 으로 표면화"를 유지(DEAD 는 §4 에 반영).
- 변경 근거: 산출물 분석.
- 코드 검증: `infra.md` L39 Read 확인 — `lib/commands.sh` status DEAD 분기·`claude_alive`(pane 자손 트리) 와 일치. 추가 갱신 없음.

### PATCH-CXT-002 (검토 결과: 갱신 불필요 — 이미 반영됨)

- 대상 파일: `{project}/.claude/docs/context.md`
- 대상 섹션: §2 핵심 모듈(테스트 행) — bats 201·ps stub
- 변경 내용: 갱신 불필요. context.md L34 가 이미 "stubs/{tmux,ps,claude} … (+조건부 ps stub: liveness 트리) … 검증(201)"로 반영. constitution.md L88 도 "현 201개"로 최신화됨.
- 변경 근거: 산출물 분석 + CHANGES.md §변경 파일.
- 코드 검증: `context.md` L34 / `constitution.md` L88 Grep 확인 — `tests/stubs/ps` 신규 파일 존재(Read 확인), bats 201(pipeline-log L18 "198→201")과 일치.

> **(PROC-R02 점검)**: context.md 에 "버저닝 이력/changelog 성" 섹션 신규 행 추가 패치 **없음** — context.md 는 이력 섹션을 보유하지 않으며 §1 "현재 버전"은 `VERSION` 파일 SoT 포인터(하드코딩 안 함)라 갱신 대상 아님. PROC-R02 위반 없음.

### PATCH-CXT-003 (후보 — 상태 머신 DEAD 반영 검토)

- 대상 파일: `{project}/.claude/docs/context.md`
- 대상 섹션: §3.3 상태 흐름 (state machine, L53-63)
- 변경 내용: 현재 state machine 다이어그램은 `registered → running → stopped` + `BROKEN` 만 표기하고 신규 `DEAD`(세션 생존·claude 종료) 가 누락돼 있다. running 에서 분기하는 `DEAD` 상태(claude 자손 없음, 수동 restart 로 복구)를 다이어그램·설명에 추가하는 패치 후보.
- 변경 근거: 본 차수 신규 상태 `DEAD` 도입(DEC-002). infra.md §4 는 반영됐으나 context.md §3.3 state machine 은 미반영(누락).
- 코드 검증: `lib/commands.sh` `_status_class`/`status_json` 가 running→dead→broken→stopped 정렬·`state:"dead"` 분기(CHANGES.md L14, liveness.bats #3 `state=dead` 확인). `context.md` L53-63 Read 확인 — DEAD 미표기. **갱신 권장(High) — 본 차수 핵심 상태 추가가 context state machine 에 누락된 사실 불일치.**
- 강제도: SHOULD

---

## 기각·재배치된 후보

- **(기각)** "direct 모드에서 spec/plan/tasks 미작성" — 이미 pipeline-log L16 에 no-silent-caps 로 기록됨. 모드 정의상 정상 절차(architecture §10)이므로 패치 불필요.
- **(재배치)** PATCH-003 의 `ps comm` quirk 는 python.md 가 아닌 Bash/BSD 한정 규칙으로 재배치(범용 X). 위 PATCH-003 참조.
- **(보류)** OBS-6(버전·spec 폴더 결정) — 기존 폴더 컨벤션 근거로 사용자 질의 없이 v0.5.1/006 확정한 것은 정상 판단(pipeline-log L7, "새 기능≠버전올림" §10). 신규 패치 불요. 단 PATCH-004(채널 결정 운용)와 묶어 "명확한 컨벤션 기반 결정은 질의 생략 가능"을 process-patches PROC-002 에 노트.
