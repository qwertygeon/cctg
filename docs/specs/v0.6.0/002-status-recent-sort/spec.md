# Spec — v0.6.0/002 status 최근 실행순 정렬

작성: 2026-06-20 10:27
버전: v0.6.0/002-status-recent-sort
최종 수정: 2026-06-20 10:27
상태: 구현중 (direct 모드)

## 목차

- [배경](#배경)
- [요구사항 (FR)](#요구사항-fr)
- [성공 기준 (SC)](#성공-기준-sc)
- [범위 밖 (scope.md 참조)](#범위-밖-scopemd-참조)

## 배경

`cctg status` 의 사람용 출력은 봇을 상태 버킷(RUNNING → DEAD → BROKEN → stopped)으로
분류해 표시하며, 각 버킷 내부는 레지스트리 등록 순서를 유지한다. 사용자는 상태 버킷 분류는
유지하되, 버킷 내부를 "최근 실행한 봇이 위" 로 보고 싶어 한다. 실행 시각의 신뢰 가능한 소스는
tmux `#{session_created}` 이며, 이는 세션이 살아있는 RUNNING·DEAD 버킷에서만 확정 조회된다.

## 요구사항 (FR)

- **FR-001**: `cctg status` 의 RUNNING 버킷 내부를 세션 생성시각(`session_created`) 내림차순
  (최근 실행이 위)으로 정렬한다.
- **FR-002**: DEAD 버킷 내부도 동일하게 `session_created` 내림차순으로 정렬한다.
- **FR-003**: BROKEN·stopped 버킷은 기존 동작(레지스트리 등록 순서)을 유지한다.
- **FR-004**: 생성시각이 동률이거나 미상(tmux 조회 실패·비숫자)인 경우 레지스트리 등록 순서를
  tiebreak 으로 유지한다(안정 정렬). 미상은 해당 버킷 최하위로 둔다.
- **FR-005**: 프로젝트 봇과 예약어 전역 봇 status 양쪽에 동일하게 적용한다.
- **FR-006**: 상태 버킷 간 순서(RUNNING → DEAD → BROKEN → stopped)는 변경하지 않는다.

## 성공 기준 (SC)

- **SC-001**: 두 RUNNING 봇 중 `session_created` 가 더 큰(최근) 봇이 위에 표시된다.
- **SC-002**: 두 DEAD 봇 중 `session_created` 가 더 큰 봇이 위에 표시된다.
- **SC-003**: 같은 버킷에서 `session_created` 가 동일하면 레지스트리 등록 순서가 유지된다
  (기존 회귀 테스트 불변).
- **SC-004**: 상태 버킷 간 순서(RUNNING → DEAD → BROKEN → stopped)가 유지된다(기존 회귀 불변).
- **SC-005**: 예약어 전역 봇 RUNNING/DEAD 버킷에도 최근순 정렬이 적용된다.

## 범위 밖 (scope.md 참조)

- `status --json` 출력 배열 순서 변경 (CUT-001) — 본 요구는 사람용 display 한정.
