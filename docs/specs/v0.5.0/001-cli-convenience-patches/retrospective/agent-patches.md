---
작성: Retrospective Agent
버전: v1.0
최종 수정: 2026-06-17 23:50
상태: 작성중
---

# Agent Patches: cli-convenience-patches (v0.5.0/001)

> 본 spec 은 cctg 프로젝트 코드 변경(순수 Bash 셸)이며, 관찰 결함은 흐름 제어 차원이다.
> 전역 Agent/rule/docs/skill 신규 패치 후보: **없음**.
> context.md/infra.md 갱신 패치(PATCH-CXT)는 `context-infra-updates.md` 에 분리 작성(Task output 분리 요청).
> process(흐름 제어) 개선은 `process-patches.md` 에 작성.

## 목차

- [전역 Agent·규칙·문서·스킬 패치 후보](#전역-agent규칙문서스킬-패치-후보)
- [패치 대상 적합성 검토 (오염 방지 게이트)](#패치-대상-적합성-검토-오염-방지-게이트)

---

## 전역 Agent·규칙·문서·스킬 패치 후보

전역 문서(`~/.claude/agents/`·`rules/`·`docs/`·`skills/`) 대상 신규 패치: **없음**.

근거:
- agent-observations.md 의 유일 관찰 OBS-001(모델 라우팅 침묵 실패)은 전역 Agent **정의** 결함이 아니라 **흐름 제어(main session spawn 절차)** 차원의 문제다 → `process-patches.md` PROC-R7-01/PROC-R7-02 로 라우팅한다.
- 설계 워크플로우 8개 항목 전수 준수(retrospective-report §3), 서킷 브레이커 미발동, 단계 정의 미흡으로 인한 재작업 0건 → Agent 정의 보강 사유 부재.
- DEC-001 Spec→Planning 재작업은 §6.2 단축·STALE 처리·DEC 기록이 모두 정상 작동(retrospective-report §2) → 정의 결함 아님.

---

## 패치 대상 적합성 검토 (오염 방지 게이트)

본 차수에서 전역 등재를 검토했으나 게이트 미통과로 **재배치**한 후보:

| 후보 내용 | 1차 검토 대상 | 적합성 판정 | 재배치 |
|---|---|---|---|
| "Phase Agent spawn 시 model 명시 고정 권고" | `~/.claude/rules/on-demand/agent-rules.md` 또는 orchestration 절차 | 범용 O / 역할정합 **△→O** — 모델 라우팅 침묵 실패가 **2회차 관찰**(v0.4.0/001 PROC-002 + 본 OBS-001)로 반복 검증 충족. 단 1회당 흐름 제어 실행 절차 문제이므로 정의 본문보다 process 절차가 적합 | 재배치: 전역패치→process-patches.md PROC-R7-01 (전역 승격 검토를 PROC 내에서 명시) |
| "0토큰 idle 침묵 실패 감지 방어로직" | `~/.claude/docs/pipeline-recovery.md §4.2` | 범용 O / 역할정합 O — recovery 의 spawn 실패 감지 절차에 부합 | 재배치: process-patches.md PROC-R7-02 (recovery 승격 후보로 등재 — 적합성: 범용 O / 역할정합 O) |

> 모델 라우팅 침묵 실패가 1개 spec 의 1회 관찰이 아니라 **2개 차수 연속 관찰**이므로, 본 차수에서는 process-patches 에 등재하되 **전역 승격 시점이 도래**했음을 PROC-R7-01 에 명시한다(직전 차수 PROC-002 의 "관찰 1회·보류" 근거 소멸).
</content>
