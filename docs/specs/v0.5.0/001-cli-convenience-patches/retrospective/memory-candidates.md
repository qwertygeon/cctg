---
작성: Retrospective Agent
버전: v1.0
최종 수정: 2026-06-17 23:50
상태: 작성중
---

# memory 저장 후보 (사용자 검토 필요)

> [MUST NOT] Retrospective Agent 는 memory 시스템(`~/.claude/projects/*/memory/`)에 직접 파일을 작성·수정·삭제하지 않는다.
> 아래는 **후보 표**이며, 실제 memory 파일 작성은 main session 이 사용자 승인 후 수행한다.
> 등재 기준(보수적 — 핵심원칙 §8): (a) 범용성 · (b) 최우선 중요도 · (c) 반복 검증 · (d) 글로벌 규칙·Agent 정의로 흡수 **불가능** — **4기준 모두 충족** 시에만 등재. 모호하면 등재하지 않는다.

## 목차

- [후보 표](#후보-표)
- [등재 판단 결론](#등재-판단-결론)

---

## 후보 표

| ID | 후보 학습 (한 줄) | 적용 가능 범위 | 4기준 충족 근거 (a/b/c/d) | 제안 memory type |
|---|---|---|---|---|
| MEM-001 (조건부) | "Phase Agent spawn 시 세션 기본 모델이 unavailable 이면 frontmatter model 을 무시하고 0-token idle('available')로 **침묵 실패**한다 — spawn 시 model 을 명시 고정하고, idle+산출물0+로그0+duration 수십ms 패턴을 라우팅 실패 신호로 감지하라" | 모든 SDD 파이프라인 세션(프로젝트·언어 불문) | a:범용 O / b:최우선 O(침묵 실패 → 진행 정지·디버깅 비용) / c:반복 O(v0.4.0/001 PROC-002 1회 + 본 차수 OBS-001 = **2회 관찰**) / **d:흡수 가능 → 미충족** (PROC-R7-01/02 로 `pipeline-recovery.md`/`pipeline/SKILL.md` 전역 흡수가 더 적합 — memory 는 마지막 수단) | feedback |

> memory type: `user` / `feedback` / `project` / `reference` 중 하나 (글로벌 CLAUDE.md Memory 섹션 참조).

---

## 등재 판단 결론

- **무조건 등재 항목: 없음.**
- MEM-001 은 (a)(b)(c) 3기준을 충족하나 **(d) "글로벌 규칙·Agent 정의로 흡수 불가능" 을 충족하지 못한다**. 본 학습은 process-patch(PROC-R7-01: spawn 시 model 명시 고정 / PROC-R7-02: 0-token idle 감지)로 `~/.claude/skills/pipeline/SKILL.md` · `~/.claude/docs/pipeline-recovery.md §4.2` 에 흡수하는 것이 memory 보다 적합하다(핵심원칙 §8d — memory 는 마지막 수단).
- **권고**: main session 이 PROC-R7-01/02 를 전역 적용하면 MEM-001 은 **등재 불요**(중복 회피). 만약 전역 패치를 채택하지 않기로 결정한 경우에 한해, MEM-001 을 `feedback` type 으로 등재 검토한다(조건부).
- 따라서 본 차수는 **memory 직접 등재 권고 0건**, 전역 process-patch 적용을 우선 경로로 권고한다.
</content>
