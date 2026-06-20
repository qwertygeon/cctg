---
작성: Retrospective Agent
버전: v1.0
최종 수정: 2026-06-20 10:46
상태: 검토중
---

# Agent Patches: v0.6.0/002-status-recent-sort

## 전역 Agent·규칙·참조 문서·스킬 패치

**없음.**

이번 차수는 결함·재작업·BLOCKED 0건의 매끄러운 direct 차수이며, 핵심 학습(STUB-QUIRK 적용,
미상값 폴백·안정정렬)은 모두 기존 전역 규칙(`~/.claude/rules/on-demand/tmux.md`·`shell.md`·
`error-handling.md`, `~/.claude/agents/05-test.md` STUB-QUIRK)으로 **이미 커버됨**. 신규 전역
패치를 도출하지 않는다 (retrospective-report.md §6 참조). 패치 대상 적합성 2단계 게이트 적용
대상도 없다.

## context.md / infra.md 갱신 제안 (R5)

### PATCH-CXT-001: context.md — 상태 흐름에 "버킷 내부 최근 실행순 정렬" 반영

- 대상 파일: `/Users/sgeon_pro/Documents/Study/cctg/cctg/.claude/docs/context.md`
- 대상 섹션: §3.3 상태 흐름 (state machine) — L67 `status 정렬·표시:` 행
- 변경 내용: 현재 행은 버킷 **간** 순서만 기술한다.
  - 현재: `- status 정렬·표시: RUNNING → DEAD → BROKEN → stopped`
  - 변경 후(예): `- status 정렬·표시: 버킷 간 순서 RUNNING → DEAD → BROKEN → stopped 유지. RUNNING·DEAD 버킷 내부는 tmux #{session_created} 내림차순(최근 실행이 위)으로 재정렬(_sort_bucket_by_created), 동률·미상(tmux 조회 실패·비숫자)은 등록순 tiebreak(안정정렬)·미상은 버킷 최하위. broken/stopped 는 세션 부재로 등록순 유지. 사람용 display 한정 — status --json 배열 순서는 미변경(CUT-001). (v0.6.0/002)`
- 변경 근거: 산출물 분석 결과 — 본 차수가 `cctg status` 사람용 출력의 핵심 관찰 가능 동작
  (버킷 내부 정렬 기준)을 변경했으나 context.md §3.3 이 미반영. context.md "현재 코드베이스 사실
  묘사" 역할상 차기 spec 설계자가 정렬 동작을 오인하지 않도록 현행화 필요. gaps.md 부재이나
  CHANGES.md 후속 관리 항목으로 R5 갱신 기준("기존 모듈의 역할·데이터 흐름 변경")에 해당.
- 코드 검증 (PROC-002): `lib/commands.sh` L604 `_sort_bucket_by_created()` 정의 — `''|*[!0-9]*`
  → `created=0` 정규화 후 `sort -t<tab> -k1,1nr -s | cut -f2-`(내림차순 안정정렬). L635-636
  (p_running/p_dead, 프로젝트 봇)·L668-669(r_running/r_dead, 예약어 봇) 호출 확인. broken/stopped
  버킷에는 미호출 확인. 변경 후 텍스트가 코드 사실과 **일치**. status --json 미변경은 scope.md
  CUT-001 + DIFF(status_json 미포함)으로 교차 확인.
- status: 적용 완료 (2026-06-20, 사용자 승인. `(v0.6.0/002)` 버전 마커는 사용자 요청으로 생략 — context.md 는 현재 상태 묘사 문서. 변경 로그: `.claude/docs-change-logs/2026-06-20-001.md`)

### infra.md 갱신

해당 없음 — 본 차수는 코드 수준 display 변경. 배포 방식·컨테이너 구성·CI/CD·인프라 제약 무변경.
infra.md 패치 미작성.
