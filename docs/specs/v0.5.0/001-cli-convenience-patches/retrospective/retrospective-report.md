---
작성: Retrospective Agent
버전: v1.0
최종 수정: 2026-06-17 23:50
상태: 검토중
---

# 회고 분석 리포트

> 대상: v0.5.0/001-cli-convenience-patches (그룹 A 사후변경·B 자동완성·C 예약어 런타임)
> 결론 요약: 1~6 + PPG-1 전 단계 정상 완료(gate PASS), 기능 결함 0. 시스템 차원 발견은 **모델 라우팅 침묵 실패(OBS-001) 2회차 관찰** 1건이 핵심. 직전 차수에서 보류했던 전역 승격 검토 단계 진입.

## 목차

- [1. gaps.md + agent-observations.md 기반 패치 도출](#1-gapsmd--agent-observationsmd-기반-패치-도출)
- [2. 재작업 패턴 분석](#2-재작업-패턴-분석)
- [3. 설계 워크플로우 준수 점검](#3-설계-워크플로우-준수-점검)
- [4. 구조 개선 필요성](#4-구조-개선-필요성)
- [5. 작업 기록 분석](#5-작업-기록-분석)
- [6. 전역 규칙·참조 문서·스킬 개선 검토](#6-전역-규칙참조-문서스킬-개선-검토)
- [7. 우선 개선 항목](#7-우선-개선-항목)
- [8. memory 저장 후보 (사용자 검토 필요)](#8-memory-저장-후보-사용자-검토-필요)

---

## 1. gaps.md + agent-observations.md 기반 패치 도출

### 1a. gaps.md 역추적

**GAP-001 (Docs Agent 등록 — 문서 갱신 필요)**

| 역추적 질문 | 답 |
|---|---|
| ① 어느 단계에서 발견? | 6단계 Docs Agent (X3 — context.md 부정합 cross-check) |
| ② 어느 단계의 누락? | 누락 아님 — 신규 기능(예약어 런타임 동사 허용 + DEC-001 cwd=$PWD)이 context.md 현재상태 묘사에 아직 미반영된 정상적 후속 갱신 항목. 3단계 Design 이 "신규 기능 반영이지 부정합 아님 → 6단계 Docs 가 검토" 로 정확히 라우팅(gaps.md 23행). |
| ③ 어떤 질문이 사전 방지? | 해당 없음 — 설계 누락이 아니라 코드→문서 동기화 항목. |
| ④ 어느 Agent 카테고리 추가? | 해당 없음(Agent 정의 미흡 아님). |
| ⑤ 전역 규칙 보완? | 불요. Docs Agent 가 gaps.md 에 기록하고 Retrospective 가 PATCH-CXT 로 처리하는 기존 흐름이 정상 동작. |
| ⑥ 선행 spec GAP 연속성 | 본 GAP-001 은 v0.5.0/001 신규 기능 고유. 선행 spec(v0.4.0/001)의 미해결 GAP 후속 아님. |
| ⑦ 선행 spec 영향 추적(PROC-013) | spec.md 에 "선행 spec 영향 추적" 구조 필드 없음(본 spec 은 v0.4.0 의 보정 patch 아님). 자가 점검 불요. |

→ **처리**: `context-infra-updates.md` PATCH-CXT-001(§5)·PATCH-CXT-002(§6) 로 도출. 코드 검증 동반.

### 1b. agent-observations.md 기반 패치 도출

**OBS-001 — Phase Agent spawn 의 세션 기본 모델(Fable 5) 라우팅으로 인한 침묵 실패**

- main session 발췌(agent-observations.md): 3단계 Design Agent 를 named teammate 로 2회 spawn → 둘 다 산출물·로그 없이 즉시 idle("available"). 3번째 no-name blocking spawn 에서야 `Claude Fable 5 is currently unavailable`(subagent_tokens=0, tool_uses=0, duration_ms=18) 명시 오류. 사용자 승인(§11 모델 오버라이드) 후 `model` 명시 고정으로 Fable 라우팅 우회 → design3 정상 COMPLETE.
- **대응 패치**: main session 이 제시한 process-patch 후보 2건을 process-patches.md PROC-R7-01·PROC-R7-02 로 구체화. Agent **정의** 결함이 아닌 **흐름 제어(spawn 절차)** 차원 문제이므로 agent-patches 가 아닌 process-patches 로 라우팅.
- **반복 검증(핵심원칙 §8c)**: 직전 차수 v0.4.0/001 의 PROC-002 가 동일 패턴(fable-5 unavailable → 0-token 실패 → model=opus 재spawn)을 이미 1회 관찰하고 "범용 단정 보류·전역 승격 보류(관찰 1회)" 로 process-patch 에 보수적 등재했다. 본 OBS-001 이 **2회차 관찰** → 반복 검증 충족 → PROC-R7-01 에서 전역 승격(`pipeline-recovery.md`) 검토를 명시.

---

## 2. 재작업 패턴 분석

### 단계별 재작업·서킷 브레이커

- 서킷 브레이커: **미발동**. 동일 단계 3회 초과 재작업 0건.
- 재작업 발생: **DEC-001 1건** — 2→3 승인 게이트에서 사용자가 예약어 전역봇 cwd 를 `$HOME`(ASM-001)→`$PWD` 로 변경 결정. main 이 `spec 수정` 이벤트 발생 → plan.md STALE 처리 → Spec(재작업)→Planning(재작업) 순으로 정정.
- **재작업 흐름 평가(매끄러움)**: 매끄러웠음.
  - STALE 처리 정상: plan.md 를 STALE 표기 후 Spec 먼저 정정(ASM-001 resolved·spec.md FR-006/009 cwd 서술·SC-025 신규)→ Planning 이 §6.2 단축 적용으로 재작업(STALE 해소·v1.1). 하류 영향(up_reserved/status_reserved 좌표·ADR-006·$PWD 부재 ERR_NO_CWD 가드 추가)까지 일관 정정.
  - 정합성 영향 0: 재작업 후 3단계 Design 이 spec v1.1·plan v1.1 입력으로 정상 진행, 5b 에서 cwd=$PWD·bash -lc·printf .env 설계 정합 전수 확인. DEC-001 변경이 후속 단계로 누락 없이 전파됨.
  - DEC-001 이 decisions.md 에 영향 산출물·근거 일시까지 정확 기록되어 추적성 확보.

### PROC-008 직전 N=3 차수 적용 완료 패치 효과 측정 (표준 출력 형식)

> 측정 대상: 직전 N=3 차수의 적용 완료 패치. 가용 직전 차수는 v0.4.0/001(1개) — 그 이전 차수는 본 SPEC_ROOT 트리에 retrospective 산출물 부재(측정 대상 자동 축소).

| 패치 | 의도 | 본 차수 효과 | 효과 발휘 여부 |
|---|---|---|---|
| v0.4.0/001 PROC-001 (PPG 동일 turn 2-spawn 강제 self-check) | main 이 PPG 직렬 spawn 하지 않고 동일 turn 2-spawn | 본 차수 PPG-1(4단계 Dev ∥ 5a Test) 이 pipeline-log 22:52 동일 시각 2개 "단계 시작" 으로 동시 spawn(병렬그룹 PPG-1) → 직렬 spawn 규약 위반 0건 | **O** |
| v0.4.0/001 PROC-002 (Phase Agent spawn 모델 unavailable fallback — 전역 승격 **보류**) | 0-token/모델 unavailable 시 기본모델 재spawn + 로그 기록 절차 | 본 차수 3단계에서 **동일 패턴 재발**(Fable 5 unavailable). main 이 ad-hoc 으로 model=opus 명시 고정 재spawn 하여 자동 복구했으나, 사전 명문화된 방어 절차 부재로 시행착오 반복(2회 idle spawn 후 3회차에서야 표면화) | **X (부분 미발휘 — 절차 미명문화로 재발)** |
| v0.4.0/001 PROC-003 (PROC-014 사후 운영 검증 점검) | 사후 운영 결함 피드백 사이클 점검 | 본 차수도 동일하게 spec.md "사후 운영 검증 피드백 사이클" 절에 시나리오 4건 + 재진입 경로 합의 기재(spec.md 325~333행) | **O** |

**효과 미발휘(X) 후속 처리 (PROC-003 규정)**: PROC-002 의 미발휘는 main session 이 이미 OBS-001 로 기록함(case a). OBS-001 ↔ 본 차수 PROC-R7-01/02 cross-reference 후 PATCH 도출 완료. 안전망 신규 등록 불요(이미 OBS 기록됨). 단 **2회차 재발은 PROC-002 의 "1회 관찰 보수 보류" 근거가 소멸했음을 의미** → PROC-R7-01 에서 전역 승격 검토로 격상.

---

## 3. 설계 워크플로우 준수 점검

| # | 항목 | 준수 | 근거 |
|---|---|---|---|
| ① | CHANGES.md 확인 | O | 6단계 Docs 가 CHANGES.md 작성, 후속 주의사항 3건(context §5·DEC-001·NFR-003 한계) 기재 |
| ② | constitution.md 확인 | O | Planning P2 에서 P-001~005+기본 Gates 검증(예외 0), Design 시작절차 필수읽기 포함 |
| ③ | context.md 확인 | O | Design 시작절차 — context.md §2·§5·§6 필수 읽기 명시 |
| ④ | infra.md 확인 | O | Planning selection-phases 판정에서 infra.md §8 인용(컨테이너/서버 부재) |
| ⑤ | spec [NEEDS CLARIFICATION] 해소 | O | spec v1.1 clarification 0건, Planning P1 매트릭스 연결 확인 |
| ⑥ | plan Constitution Gates 통과 | O | P-001~005+기본 Gates 통과(예외 0) |
| ⑦ | research 코드베이스 분석 포함 | O | research.md D1 에서 commands.sh/session.sh/registry.sh/channels.sh/config.sh/completions/messages 실제 코드 대조 |
| ⑧ | tasks 전제 조건 체크 | O | Dev 시작절차 B-1/B-2 전제 통과, tasks 35개 SC-001~025 전수 Contract 매핑 |

→ 8개 항목 전수 준수. 워크플로우 위반 0건.

---

## 4. 구조 개선 필요성

- **Agent 역할 경계 모호 지점**: 없음. GAP-001 처리에서 "Design = 부정합 아님 판단 → Docs = gaps 기록 → Retrospective = PATCH-CXT" 경계가 명확하게 작동.
- **누락 Agent 필요성**: 없음. 코드 변경 spec 으로 선택 4단계 전부 비활성(selection-phases 근거 충실 — 특히 Security 비활성을 신중 판단으로 명시).
- **선택 단계 활성화 기준 적절성**: 적절. Security 비활성 판단에 토큰 비노출·access.json 비접근·주입 표면 부재를 P-002/P-003 흡수로 명시(no-silent-caps 준수). Performance 면제도 constitution §3 SLA 부재 선언 인용.

---

## 5. 작업 기록 분석 (runs/)

- 각 Agent 가 필수 읽기 문서를 실제 읽음(pipeline-log 시작절차 이벤트에 필수읽기 목록 명시 — Design 은 context §2·§5·§6 좁혀 읽기 §6.1 budget 준수).
- constitution/context/infra 참조 적절(§3 점검 결과 전수 준수).
- Agent 간 Context 전달 충분: DEC-001 변경이 decisions.md → spec v1.1 → plan v1.1 → research/tasks → 5b 검증까지 누락 없이 전파.
- 비효율 반복 패턴: **모델 라우팅 침묵 실패만이 유일한 비효율**(3단계 idle spawn 2회). OBS-001 = §2 PROC-008 측정의 X 항목과 동일 사안. 그 외 단계는 1회 COMPLETE.

---

## 6. 전역 규칙·참조 문서·스킬 개선 검토

- 본 차수 관찰 결함(모델 라우팅 침묵 실패)은 전역 **Agent 정의** 결함이 아니라 **흐름 제어(main session spawn 절차)** 차원. → agent-patches 신규 전역 패치 0건, process-patches 로 라우팅.
- **잔존 참조 grep 점검**: 본 차수 전역 문서 재구성·파일 이동·삭제 이력 없음 → grep 점검 불요.
- **PROC-R02(이력/changelog 섹션 행 추가 금지) 자가 점검**: context.md §1 "현재 버전" 은 단일 스냅샷 필드(이력표 아님) → 갱신 허용 대상. PATCH-CXT-003 은 행 추가가 아닌 단일 필드 값 갱신(v0.3.0→v0.5.0)이므로 PROC-R02 위반 아님. context.md 에 버저닝 이력표 섹션 부재(레거시 없음) → 제거 패치 불요.
- 환경 구분 태깅: 본 차수 패치는 macOS/Bash 전제이나 전역 문서 대상 패치가 0건이므로 태깅 대상 없음(프로젝트 context.md/infra.md 는 이미 프로젝트 한정).

→ **전역 패치(agents/rules/docs/skills) 신규: 없음**. process 차원 개선만 도출(§7).

---

## 7. 우선 개선 항목

> 심각도 기준: Critical 전체 + High 상위 3개. 본 차수 Critical 0건.

| 우선순위 | 항목 | 위치 | 근거 |
|---|---|---|---|
| **High** | PROC-R7-01 — Phase Agent spawn 시 model 명시 고정 + 전역 승격 검토 | process-patches.md | OBS-001 **2회차 관찰**(직전 PROC-002 와 동일). 반복 검증 충족 → 보류 근거 소멸. 사용자 매 차수 수동 개입 비용 발생 중. |
| **High** | PROC-R7-02 — 0토큰 idle 침묵 실패 감지 방어로직 | process-patches.md → `pipeline-recovery.md §4.2` | idle="available" + 산출물 0 + 로그 0 + duration<수십ms 패턴을 모델 라우팅 실패 신호로 분류. 현재는 3회차 blocking spawn 에서야 표면화(2회 침묵). |
| Medium | PATCH-CXT-001/002 — context.md §5/§6 갱신(GAP-001) | context-infra-updates.md | 예약어 런타임 동사 허용 + DEC-001 cwd=$PWD 가 현재상태 묘사에 미반영. |

> PROC-R7-03(PROC-014 사후검증)은 점검 결과 결함 없음 — 우선 개선 항목 아님(정보 항목).

---

## 8. memory 저장 후보 (사용자 검토 필요)

> 핵심 원칙 §8 의 4기준(범용성·최우선 중요도·반복 검증·글로벌 흡수 불가능)을 **모두** 충족하는 항목만 등재. Retrospective 는 표만 작성하며 실제 memory 파일 작성은 main session 이 사용자 승인 후 수행한다.

| ID | 후보 학습 (한 줄) | 적용 가능 범위 | 4기준 충족 근거 (a/b/c/d) | 제안 memory type |
|---|---|---|---|---|
| MEM-001 | "Phase Agent spawn 시 세션 기본 모델이 unavailable 이면 frontmatter model 을 무시하고 0-token idle('available') 로 **침묵 실패**한다 — spawn 시 model 을 명시 고정하고, idle+산출물0+로그0 패턴을 라우팅 실패 신호로 감지하라" | 모든 SDD 파이프라인 세션(프로젝트·언어 불문) | a:범용(모델 라우팅은 cctg 무관 harness 동작) / b:최우선(침묵 실패는 진행 멈춤·디버깅 비용 큼) / c:**반복(v0.4.0/001 PROC-002 1회 + 본 차수 OBS-001 = 2회 관찰)** / d:글로벌 흡수 **가능** → PROC-R7-01/02 로 `pipeline-recovery.md` 승격이 더 적합 | feedback |

> **MEM-001 등재 판단**: 4기준 중 (d) "글로벌 규칙·Agent 정의로 흡수 불가능" 을 **충족하지 못한다** — 본 학습은 process-patch(PROC-R7-01/02)로 `pipeline-recovery.md`/orchestration 절차에 흡수하는 것이 memory 보다 적합하다(memory 는 마지막 수단, 핵심원칙 §8d). 따라서 **memory 저장보다 전역 process-patch 적용을 우선 권고**한다. main session 이 PROC-R7-01/02 를 전역 적용하면 MEM-001 은 등재 불요. 두 경로 중복 등재를 피하기 위해 본 항목은 "조건부 후보(전역 패치 미채택 시에만)" 로 표시한다.

> 결론: 4기준 동시 충족 항목 **사실상 없음**(MEM-001 은 d 미충족 → 전역 패치로 대체 권고). 무조건 등재 항목: 없음.
</content>
