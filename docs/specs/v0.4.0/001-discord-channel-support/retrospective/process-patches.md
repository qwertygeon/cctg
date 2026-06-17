---
작성: Retrospective Agent
버전: v1.0
최종 수정: 2026-06-17 18:14
상태: 작성중
---

# Process Patches: discord-channel-support (v0.4.0/001)

## 목차

- [PROC-001 — PPG 동시 spawn 누락 재발 방지](#proc-001--ppg-동시-spawn-누락-재발-방지)
- [PROC-002 — Phase Agent spawn 모델 unavailable 시 fallback](#proc-002--phase-agent-spawn-모델-unavailable-시-fallback)
- [PROC-003 — 사후 운영 검증 피드백 사이클 점검 (PROC-014)](#proc-003--사후-운영-검증-피드백-사이클-점검-proc-014)

---

## PROC-001 — PPG 동시 spawn 누락 재발 방지

- **현재 프로세스**: `agent-rules.md §0 PPG 운용규칙 1` 은 "독립집합 내 능력들을 **동일 응답 turn 내 복수 Agent 도구 호출**로 spawn" 을 요구한다(직렬 호출 = 병렬 정의 위반).
- **문제점**: 본 차수 PPG-1(4단계 Development ∥ 5a Test AUTHORING) 에서 main session 이 Development 만 먼저 spawn 하고 보고 수신 후 5a 를 직렬 spawn 했다(pipeline-log 15:46 "규약 위반(SHOULD)"). 규칙은 명문화돼 있으나 **실행 시점 체크포인트가 없어** 누락. 정합성 영향은 0(Development 완료본을 5a 입력으로 활용)이나 wall-clock 손해 + 규약 위반 이벤트 발생.
- **개선 방향**: main session 의 PPG 진입 시점 self-check 1줄 추가 — "PPG-N 진입: 동일 turn 에 N개 Agent 도구 호출을 했는가? (직렬 spawn 이면 §0 위반)". `~/.claude/skills/pipeline/SKILL.md` 또는 orchestration 흐름 문서의 PPG 진입 절차에 체크 항목으로 추가하면 실행 차원 누락 차단.
- **영향 범위**: main session(Pipeline Orchestration) 실행 절차. `~/.claude/skills/pipeline/SKILL.md` PPG spawn 단계. Agent 정의 변경 불요(규칙은 이미 §0 에 존재 — 정의 미흡 아님).
- **우선순위**: Medium (정합성 영향 0, 효율·규약 준수 차원).

---

## PROC-002 — Phase Agent spawn 모델 unavailable 시 fallback

- **현재 프로세스**: main session 이 Agent 도구로 Phase Agent 를 spawn 할 때 모델 지정(예: fable-5)이 가용하지 않으면 명시적 fallback 절차가 문서화돼 있지 않다.
- **문제점**: 본 차수 3단계 Design Agent 1차 spawn 이 `fable-5 unavailable` 로 **0-token 실패**했고, main 이 `model=opus` 로 재spawn 하여 성공(pipeline-log 15:24 비고). 자동 복구됐으나 절차가 ad-hoc — 재발 시 동일 시행착오 반복 가능.
- **개선 방향**: "Phase Agent spawn 이 0-token / 모델 unavailable 로 실패하면 (1) 기본 모델로 즉시 재spawn, (2) pipeline-log 에 'spawn 재시도(모델 fallback)' 이벤트 기록" 절차를 명문화. **단, 0-token 실패는 cctg 실행 환경 특정(특정 모델 미가용)일 수 있어 범용 단정 보류** — 본 1회 관찰만으로 전역 `pipeline-recovery.md` 승격은 핵심원칙 §8(c) 반복검증 미충족. process-patch 후보로만 등재하고 동일 패턴 재관찰 시 전역 승격 판단.
- **영향 범위**: main session spawn 절차. 후보 전역 대상 = `~/.claude/docs/pipeline-recovery.md`(승격 시).
- **우선순위**: Low (관찰 1회 · 자동 복구됨 · 환경 특정 가능성).

---

## PROC-003 — 사후 운영 검증 피드백 사이클 점검 (PROC-014)

- **현재 프로세스**: 본 spec 은 selection-phases 전부 N(통합 테스트 없음), 실제 Discord API 연결 검증은 spec "범위 외"·플러그인 런타임 소유. spec.md "사후 운영 검증 피드백 사이클" 절에 사용자 점검 시나리오(DM 페어링 코드, `/discord:access pair`, 서버채널 @멘션, status 토폴로지)와 결함 발견 시 재진입 절차(spec.md 추가 → "spec 수정" 이벤트 → 1단계 재진입 또는 patch spec)가 합의 기재됨.
- **문제점(점검 결과)**: 본 PROC-014 점검 시점(파이프라인 종료 직전)에는 (a) 사후 운영 결함 피드백 미발생(파이프라인 완료 직후), (c) 차후 점검 계획은 spec "사후 운영 검증 피드백 사이클" 에 시나리오로 합의 기재됨(모니터링 계획 존재). → **결함 없음.** 단 옵션 C 류(파이프라인 내 통합검증 스킵)에 해당하므로 사후 결함 노출 위험이 구조적으로 존재.
- **개선 방향**: 추가 패치 불요. spec 에 사후 검증 시나리오가 명시돼 있고 결함 발견 시 재진입 경로가 합의됐다(절차 정상). 사용자 운영 검증 결과를 다음 cycle 진입 시점에 확인할 것을 권고(별도 패치 아님 — 정보 항목).
- **영향 범위**: 없음(점검 통과). 정보 기록 목적.
- **우선순위**: N/A (점검 결과 정상).
