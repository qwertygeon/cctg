---
작성: Retrospective Agent
버전: v1.0
최종 수정: 2026-06-17 18:14
상태: 작성중
---

# memory 저장 후보 (사용자 검토 필요)

> [MUST NOT] Retrospective Agent 는 memory 시스템에 직접 작성하지 않는다.
> 아래는 후보만 제시하며, 실제 memory 저장은 main session 이 사용자 승인 후 수행한다.
> 등재 기준(핵심원칙 §8, 보수적): (a)범용성 (b)최우선 중요도 (c)반복 검증(1회 관찰 불충분) (d)글로벌 규칙·Agent 정의로 흡수 불가능 — **4개 모두 충족** 시에만 등재.

## 목차

- [후보 평가](#후보-평가)

---

## 후보 평가

**등재 후보: 없음.**

본 차수에서 관찰된 학습 후보를 4기준으로 평가한 결과, 모두 기준 미충족으로 미등재한다(보수성 우선).

| 평가 대상 학습 | a 범용 | b 중요 | c 반복검증 | d 글로벌흡수불가 | 판정 |
|---|---|---|---|---|---|
| PPG 동시 spawn 누락(직렬 spawn) | O | △ | X (본 차수 1회) | X (`agent-rules §0` 이미 명문 — 흡수 가능) | 미등재 → process-patches PROC-001 |
| Phase Agent spawn 모델 unavailable fallback | △ (환경 특정 가능) | △ | X (1회) | X (pipeline-recovery 흡수 가능) | 미등재 → process-patches PROC-002 |
| descriptor SSOT화로 채널 추가 비용 최소화(case 1블록+1줄) | X (cctg 도메인 특정 사실) | — | — | — | 미등재 → context.md §5/§6 갱신이 적합(범용성 X) |
| 완성 파일 채널 미러 수동 동기화 함정 | X (cctg 코드 특정) | — | — | — | 미등재 → context.md §6 제약 행(범용성 X) |
| Bash 3.2 컴파운드 토큰 파싱(연관배열 불가 회피) | △ (Bash 3.2 한정) | — | X (1회) | — | 미등재 → 환경 한정 + 1회. 재관찰 시 `rules/on-demand/` 검토 |

근거 요약:
- 본 spec 은 cctg 프로젝트 코드 변경 중심으로, 도출된 학습 대부분이 **프로젝트 특정 사실**(범용성 미충족) → context.md/infra.md 갱신이 적합한 처리 경로다.
- 프로세스 관찰(PPG 직렬화·모델 fallback)은 **1회 관찰**(반복 검증 미충족)이며 기존 글로벌 규칙/recovery 문서로 흡수 가능(d 미충족) → process-patches 후보로만 등재.
- memory 는 마지막 수단(원칙 §8d)이며, 본 차수에 4기준 전부 충족 항목이 없으므로 후보 0건이 정확하다.
