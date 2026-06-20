# CHANGES — v0.6.0

## [003-defensive-hardening] 구현 완료

작성: 2026-06-20 19:34
모드: direct

### 무엇을

게이트웨이 완성도/방어 코드 보강 묶음 + 다중에이전트 검토분석 확정 17건 반영.

- **방어(이전 배치, 커밋 4a04b7b)**: `.env`/`launch.env` 를 `source` 할 때 안전하도록 `shq()` 단일따옴표
  이스케이프 도입(토큰/`CLAUDE_EXTRA_ARGS` 인젝션·파싱깨짐 차단), `--group` 미지 수식어 거부,
  시작/`config` 쓰기 가드, `status`/`logs` tmux 부재 경고.
- **완성도 5건**: doctor `install integrity`(.env 600·매니페스트 경로·bindir 쓰기), 액션 에러 복구 힌트
  (`ERR_NO_CWD`/`ERR_NOT_REGISTERED`/reserved-runner), 초기 파일 쓰기 원자화(`write_atomic`),
  `status` last-activity(text+json, tmux `#{window_activity}`+mtime 폴백), launch 문자열 wiring 테스트.
- **검토분석 반영**: `config args` 개행 거부(DEC-001 — 멀티라인 값 재설정 시 `launch.env` source 손상 방지),
  doctor `.env`-perm 빈값 가드, last-activity 음수 클램프, `write_atomic`/`write_token_env` no-slash dir 폴백,
  그리고 미테스트 코드경로 보강(doctor manifest 분기·shq 작은따옴표 e2e·reserved last-activity·write_atomic
  residue·set_env_kv 치환 라운드트립·DEAD-state·json 결정적 값).

### 왜

"저장소에 장기 실행 어시스턴트를 붙여 둔다" 시나리오의 완성도/방어 갭(`docs/TODO.md`)을 옵트인·비파괴
원칙으로 닫고, 자체 검토분석에서 확정된 결함/커버리지 갭을 반영했다.

### 어떻게

`lib/config.sh`(shq/write_atomic/no-slash), `lib/commands.sh`(doctor·last-activity·원자화·개행거부),
`lib/session.sh`(last_activity_epoch·에러힌트·클램프), `lib/util.sh`(file_perm/file_mtime/warn),
`messages/*.sh`(en/ko 키 패리티), `cc-tg.sh`(init 가드), 테스트 다수 + 신규 `tests/launch.bats`.

### 검증

- `bats tests/`: **242 passed, 0 failed**.
- `scripts/check-i18n-keys.sh`: OK (194 키 패리티).
- `shellcheck -S warning cc-tg.sh install.sh uninstall.sh scripts/*.sh`: rc=0 (external-sources, 클린).

### 범위 밖 (scope.md)

- doctor 채널 플러그인 탐지·도구 최소버전 강제 (CUT-001 — 안정적 탐지/기준선 부재).
- tmux-absent 경고 테스트 결정성 강화 (CUT-002 — 현 테스트 CI 정상, 우선순위 낮음).

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
