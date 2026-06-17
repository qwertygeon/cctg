---
작성: Retrospective Agent
버전: v1.0
최종 수정: 2026-06-18 07:14
상태: 적용 완료 (2026-06-18, main session) — PROC-R7-01 → orchestration.md §1.1 / PROC-R7-02 → pipeline-recovery.md §4.2.1 적용. PROC-R7-03 N/A(점검 통과). 변경로그: ~/.claude/docs-change-logs/2026-06-18-001.md
---

# Process Patches: cli-convenience-patches (v0.5.0/001)

## 목차

- [PROC-R7-01 — Phase Agent spawn 시 model 명시 고정 (전역 승격 검토)](#proc-r7-01--phase-agent-spawn-시-model-명시-고정-전역-승격-검토)
- [PROC-R7-02 — 0토큰 idle 침묵 실패 감지 방어로직](#proc-r7-02--0토큰-idle-침묵-실패-감지-방어로직)
- [PROC-R7-03 — 사후 운영 검증 피드백 사이클 점검 (PROC-014)](#proc-r7-03--사후-운영-검증-피드백-사이클-점검-proc-014)

---

## PROC-R7-01 — Phase Agent spawn 시 model 명시 고정 (전역 승격 검토)

- **현재 프로세스**: main session 이 Agent 도구로 Phase Agent 를 spawn 할 때, 모델을 명시하지 않으면 **세션 기본 모델**로 라우팅된다. Agent 정의 frontmatter 의 `model:`(예: 03-design=opus)이 이 세션 기본을 덮지 못하는 환경이 관찰되었다. 모델 명시 고정에 대한 명문화된 기본 권고가 없다.
- **문제점**: 본 차수 3단계 Design Agent spawn 이 세션 기본 Fable 5 로 라우팅 → Fable 5 unavailable 시 **0-token 침묵 실패**(idle "available" + 산출물 0 + 로그 0, duration_ms=18). named teammate 로 2회 spawn 했으나 둘 다 침묵, 3번째 no-name blocking spawn 에서야 `Claude Fable 5 is currently unavailable` 표면화. 사용자 승인(§11 모델 오버라이드) 후 `model=opus` 명시 고정으로 우회 → 이후 dev/test/docs=sonnet, retro=opus 까지 전 단계 명시 고정. (OBS-001)
- **반복 검증(핵심원칙 §8c)**: **2회차 관찰**. 직전 차수 v0.4.0/001 의 PROC-002 가 동일 패턴(fable-5 unavailable → 0-token 실패 → model=opus 재spawn)을 1회 관찰하고 "관찰 1회 · 환경 특정 가능성 → 전역 승격 보류" 로 보수적 등재했다. 본 OBS-001 이 2회차 → 반복 검증 충족 → **보류 근거 소멸**.
- **개선 방향**: 다음 두 단계 중 사용자 채택:
  1. (권고 — 즉시) orchestration spawn 절차에 "Phase Agent spawn 시 `model` 파라미터를 agent 정의 frontmatter 와 일치하도록 명시 고정한다(세션 기본 모델 라우팅이 frontmatter 를 무시하는 환경 대비)" 를 기본 권고로 명문화. 대상: `~/.claude/skills/pipeline/SKILL.md` 의 Agent spawn 단계, 또는 `~/.claude/docs/pipeline-architecture.md`(orchestration spawn 절차 SSOT).
  2. (병행) 침묵 실패 감지는 PROC-R7-02 로 처리.
- **영향 범위**: main session(Pipeline Orchestration) spawn 절차. 전역 대상 = `~/.claude/skills/pipeline/SKILL.md` (spawn 단계) — Agent 정의 본문 변경 불요(frontmatter model 은 이미 정확, 무시되는 것이 문제).
- **적합성**: 범용 O(모델 라우팅은 프로젝트 무관 harness 동작) / 역할정합 O(흐름 제어 spawn 절차).
- **우선순위**: **High** (2회 관찰 · 사용자 매 차수 수동 개입 비용 · 침묵으로 진행 정지 위험).

---

## PROC-R7-02 — 0토큰 idle 침묵 실패 감지 방어로직

- **현재 프로세스**: Phase Agent spawn 후 즉시 idle("available") 상태로 돌아오고 산출물·로그가 0인 경우에 대한 감지 절차가 `pipeline-recovery.md` 에 없다. 현재는 사용자/main 이 한참 뒤(또는 blocking spawn 재시도)에야 실패를 인지한다.
- **문제점**: 본 차수 3단계에서 2회의 idle spawn 이 **침묵**했고(오류 미표면), 3번째 blocking spawn 에서야 모델 unavailable 오류가 드러났다. 침묵 구간 동안 진행이 정지하나 신호가 없어 main 이 정상 idle 인지 실패인지 구분 불가.
- **개선 방향**: `pipeline-recovery.md §4.2`(spawn 실패 감지)에 다음 패턴을 spawn 실패 신호로 분류하는 항목 추가: "Phase Agent spawn 직후 (a) status='available'/idle + (b) 해당 단계 산출물 파일 0 + (c) pipeline-log 본인 이벤트 0 + (d) duration 이 수십 ms 수준(정상 작업 불가능한 시간) 이 동시 충족되면 → **모델 라우팅/spawn 실패로 분류**하고, (1) 모델 가용성 점검(또는 model 명시 재spawn — PROC-R7-01 연계), (2) pipeline-log 에 'spawn 실패 감지(0-token idle)' 이벤트 기록, (3) 사용자 안내."
- **영향 범위**: `~/.claude/docs/pipeline-recovery.md §4.2`. main session 의 spawn 직후 self-check.
- **적합성**: 범용 O / 역할정합 O(recovery 의 spawn 실패 감지 절차에 부합).
- **우선순위**: **High** (PROC-R7-01 과 짝 — 명시 고정으로 예방, 감지로 잔여 케이스 방어).

---

## PROC-R7-03 — 사후 운영 검증 피드백 사이클 점검 (PROC-014)

- **현재 프로세스**: 본 spec 은 selection-phases 전부 N(통합/E2E 테스트 없음). 실제 채널 API 연결·tmux 기동 검증은 spec "범위 외"(SC 전부 unit/static, fake tmux 기반). spec.md "사후 운영 검증 피드백 사이클" 절(325~333행)에 사용자 점검 시나리오 4건(예약어 up→DM 응답, bot.pid 생존 시 up 거부 안내, cwd 변경 후 새 경로 기동, token 변경 후 restart 적용)과 결함 발견 시 재진입 경로(spec.md "배경 및 목적" 또는 hotfix spec)가 합의 기재됨.
- **점검 결과(옵션 무관 — PROC-014 a/b/c)**:
  - (a) 사후 운영 결함 피드백: **미발생**(파이프라인 완료 직후 시점). 사용자 spec 수정/hotfix 신설/archive 백업 이벤트 없음.
  - (b) 해당 없음(피드백 미발생).
  - (c) 차후 점검 계획: spec "사후 운영 검증 피드백 사이클" 에 시나리오 4건 + 재진입 경로 합의 기재 → **모니터링 계획 존재**.
  - → **결함 없음.** 단 본 spec 은 파이프라인 내 실 환경 통합검증을 수행하지 않는 구조(옵션 C 류)이므로, 예약어 런타임(up/down/status)·cwd=$PWD 기동의 실 tmux 동작은 사후 운영 검증에서만 확정된다. coverage-gap.md 의 SC-025 error-path($PWD 삭제) 1건도 운영 위임.
- **개선 방향**: 추가 패치 불요(절차 정상). 사용자 운영 검증 결과(특히 cwd=$PWD 기동·예약어 up DM 응답)를 **다음 cycle 진입 시점에 확인**할 것을 권고(정보 항목 — 별도 패치 아님).
- **영향 범위**: 없음(점검 통과). 정보 기록 목적.
- **우선순위**: N/A (점검 결과 정상).
</content>
