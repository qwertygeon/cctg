---
작성: Pipeline Orchestration (main session)
버전: v1.0
최종 수정: 2026-06-17 21:43
상태: 확정
---

# Decisions: cli-convenience-patches

| ID | 결정 | 근거 | 영향 | 일시 |
|---|---|---|---|---|
| DEC-001 | 예약어(telegram/discord) 전역 봇 런타임 기동 시 cwd 는 **cctg 호출 시점의 터미널 현재 작업 디렉터리(`$PWD`)** 를 사용한다. 기존 ASM-001 의 `$HOME` 가정을 **대체**한다. | 사용자가 2→3 승인 게이트에서 명시적으로 "예약어를 사용하는 전역 봇은 터미널의 현재 경로를 cwd로 한다" 고 지시 (Discord, 2026-06-17 21:41). | spec/assumptions.md ASM-001 갱신(→ resolved by DEC-001), spec.md FR-006/FR-009 cwd 서술(line 85·95) 갱신, planning/plan.md 그룹 C up_reserved/status_reserved 의 `cwd=$HOME` → `cwd=$PWD` 갱신. plan.md STALE 처리 후 Spec→Planning 재작업. | 2026-06-17 21:43 |
