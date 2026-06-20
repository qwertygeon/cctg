# CHANGES — v0.6.0

## [002-status-recent-sort] 구현 완료

작성: 2026-06-20 10:34
모드: direct

### 무엇을

`cctg status`(사람용 출력)의 상태 버킷 내부 정렬을 추가했다. 상태 버킷 순서
(RUNNING → DEAD → BROKEN → stopped)는 그대로 두고, **RUNNING·DEAD 버킷 내부를 세션
생성시각(`session_created`) 내림차순(최근 실행이 위)** 으로 정렬한다. BROKEN·stopped 는
기존 등록 순서를 유지한다. 프로젝트 봇과 예약어 전역 봇 양쪽에 적용한다.

### 왜

상태별 분류는 유지하되 같은 상태 안에서는 최근에 띄운 봇을 위에서 바로 보고 싶다는 요청
(v0.6.0/002 spec FR-001~006).

### 어떻게

- `lib/commands.sh`: 헬퍼 `_sort_bucket_by_created()` 추가 — 버킷(개행 구분 봇 이름)을
  `tmux #{session_created}` 기준 안정 내림차순 정렬(`sort -k1,1nr -s`). 동률·미상(tmux 조회
  실패·비숫자)은 등록 순서 유지, 미상(created=0)은 버킷 최하위. `sess_pt` 공용이라 프로젝트·
  예약어 봇 모두 같은 헬퍼 사용. `cmd_status` 의 `p_running`/`p_dead`·`r_running`/`r_dead` 만
  재정렬(broken/stopped 는 세션이 없어 호출하지 않음).
- `tests/stubs/tmux`: `display-message` 의 `#{session_created}` 를 `FAKE_TMUX_CREATED_FILE`
  (`<session>\t<epoch>`)로 봇별 매핑하도록 보강(STUB-QUIRK — 실제 tmux는 세션별 created 반환).
  미매핑 세션·기타 포맷은 기존 `FAKE_TMUX_CREATED` 기본값으로 폴백 → 기존 테스트 불변.
- `tests/status_view.bats`: SC-001(RUNNING 최근순)·SC-002(DEAD 최근순)·SC-005(예약어 봇
  최근순) 테스트 추가.

### 변경 파일

- `lib/commands.sh` (+22)
- `tests/status_view.bats` (+63)
- `tests/stubs/tmux` (+14 −3)

### 테스트 결과

- `bats tests/`: **217 passed, 0 failed** (신규 3건 포함, 기존 회귀 불변).
- `shellcheck -S warning cc-tg.sh install.sh uninstall.sh scripts/*.sh`: rc=0
  (external-sources 로 `lib/` 추종, 클린).

### 범위 밖

- `status --json` 배열 순서는 미변경 (CUT-001, scope.md). 사람용 display 한정 요청.
