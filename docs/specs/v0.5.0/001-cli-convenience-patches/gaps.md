---
작성: Design Agent
버전: v1.0
최종 수정: 2026-06-17 22:45
상태: 진행중
---

# Gaps: cli-convenience-patches

> 3단계 Design Agent 가 최초 생성. 이후 모든 Agent 가 발견한 기획/설계 공백을 누적 기록한다.
> 형식: `pipeline-conventions.md §6`. 해결 시 상태를 `RESOLVED by [Agent 공식명]` 으로 갱신.

## 목차

- [공백 목록](#공백-목록)

---

## 공백 목록

(없음 — 3단계 Design 시점 발견 공백 0건.)

> Design Agent 검토 결과: spec.md(v1.1)·plan.md(v1.1) 의 모든 FR/SC/NFR 가 코드 사실과 정합하며, ASM-001~005 전부 해소/확정(DEC-001 포함), [NEEDS CLARIFICATION] 0건, context.md 부정합 0건(reserved name 런타임 동사 허용은 부정합이 아닌 신규 기능 반영 — 6단계 Docs Agent 가 context.md §5/§6 갱신 검토; research.md "context.md 부정합 사전 점검" 절 가시화). 신규 GAP 등록 사유 없음.

---

## GAP-001 (Docs Agent 등록)

- 유형: 문서-갱신-필요
- 상태: 미해결
- 출처: Docs Agent
- 컨텍스트: `{project}/.claude/docs/context.md`
- 등록일: 2026-06-17
- 내용: context.md §5 "예약 이름" 절에 현재 "add/rm/rename 은 ERR_RESERVED 로 거부" 설명만 있다. v0.5.0/001 구현으로 `telegram`·`discord` 에 대해 `up`, `down`, `restart`, `status`, `logs` 가 허용되었다. §5 설명에 이 동작 변화(런타임 동사는 허용, 레지스트리 동사만 거부)를 추가해야 한다. 또한 DEC-001(전역 봇 cwd = $PWD)도 §5 또는 §6 알려진 제약에 기록이 필요하다.
