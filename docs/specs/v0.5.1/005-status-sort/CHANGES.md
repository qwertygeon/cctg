# CHANGES — v0.5.1/005-status-sort

> 작성: 2026-06-18 17:25 | 버전: 1.0 | 최종 수정: 2026-06-18 17:25 | 상태: 완료(검증 통과)

## 목차

- [요약](#요약)
- [변경 내용](#변경-내용)
- [Before / After](#before--after)
- [변경 파일](#변경-파일)
- [검증 결과](#검증-결과)
- [영향 범위](#영향-범위)

## 요약

`cctg status` 가 봇을 등록 순서로만 출력해 RUNNING/stopped 가 섞여 한눈에 안 들어왔다. 이제 **RUNNING(위) → BROKEN(주의) → stopped(아래)** 순으로 정렬한다(사용자 결정: BROKEN 은 RUNNING 바로 아래 = 옵션 a). 각 상태 그룹 안은 등록 순서를 유지한다(안정 정렬).

## 변경 내용

- `cmd_status` 의 봇 1건 렌더 블록을 헬퍼로 추출: `_status_render_project_bot`(프로젝트 봇), `_status_render_reserved_bot`(전역 채널 봇).
- 상태 분류 헬퍼 추가: `_status_class`(running/broken/stopped — 실행여부 + cwd/.env 존재), `_status_class_reserved`(전역 봇은 cwd 없으므로 .env 유무로만 broken).
- 두 섹션 모두 1차 분류로 running/broken/stopped 버킷(개행 구분 문자열)에 담고 그 순서로 렌더. 버킷 안은 등록(또는 RESERVED_NAMES) 순서 유지 → 안정 정렬.
- Bash 3.2 호환: 연관배열 미사용. 렌더는 here-string(`<<<`)으로 현재 셸에서 실행해 예약 섹션 헤더-once(`ch_found`) 상태가 보존된다.

## Before / After

등록 순서가 alpha, bravo, charlie 이고 bravo=RUNNING, charlie=BROKEN(토큰 없음), alpha=stopped 일 때:

```
# Before (등록 순서)
  [stopped] alpha
  [RUNNING] bravo
  [BROKEN ] charlie

# After (running → broken → stopped)
  [RUNNING] bravo
  [BROKEN ] charlie
  [stopped] alpha
```

## 변경 파일

- `lib/commands.sh` — `_status_class`/`_status_class_reserved`/`_status_render_project_bot`/`_status_render_reserved_bot` 추가, `cmd_status` 의 두 루프를 분류+버킷 렌더로 교체.
- `tests/status_view.bats` — +2(정렬 순서 running>broken>stopped, 동일 상태 내 안정성).

## 검증 결과

- `bats tests/*.bats`: **187/187 PASS**(신규 2, 회귀 0)
- `scripts/check-i18n-keys.sh`: PASS (167 키 — 신규 메시지 키 없음, 로직만 변경)
- `bash -n`·`shellcheck -S warning`(CI 동일): **EXIT 0**
- 격리 env 렌더로 정렬 시각 확인.

## 영향 범위

- **텍스트 `status` 전용**. `status --json` 은 등록 순서 유지(소비자가 정렬) — 불변.
- 메시지 카탈로그 불변(키 수 167) — 순수 렌더 로직 리팩터.
- 기존 status 테스트(부분 문자열 단언)는 정렬과 무관하게 통과.
- 분류 단계에서 `is_running` 이 봇당 1회(분류) + 렌더에서 1회 = 2회 호출되나 봇 수가 적어 무의미.
