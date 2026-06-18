# CHANGES — v0.5.0/002-multi-target-lifecycle

> 작성: 2026-06-18 13:46 / 상태: ACTIVE (direct 모드)

## 무엇을 / 왜

`up` / `down` / `restart` 가 **여러 타겟을 한 번에** 받아 좌→우 순차 처리하도록 확장했다. 여러 봇을 한 번에 기동/정지하려고 명령을 반복 입력하던 불편을 없앤다.

- 타겟은 등록된 봇 이름·예약 채널명(`telegram`/`discord`)·`all` 을 혼합할 수 있고 인자별로 라우팅된다.
- **continue-on-error**: 한 타겟이 실패해도 나머지를 계속 처리한다.
- 2개 이상 처리 시 **성공/실패 요약 1줄**을 출력하고, 하나라도 실패하면 **비0 종료**한다.
- 단일 타겟·`all` 의 동작·출력은 불변(단일은 요약 없음). `logs`/`attach` 는 단일 타겟 유지(범위 밖, DEC-002).

## 변경 파일

| 파일 | 변경 |
|---|---|
| `lib/commands.sh` | `_lifecycle_apply`/`_lifecycle_run` 헬퍼 추출, `cmd_up/down/restart` 가 `"$@"` 순회 |
| `messages/en.sh`·`ko.sh` | `ERR_NEED_TARGET`·`MULTI_SUMMARY_OK/FAIL` 추가, `USAGE_{UP,DOWN,RESTART}` → `<name...|all>` |
| `completions/cctg.bash`·`_cctg` | up/down/restart 모든 인자 위치에서 이름·`all` 보완 |
| `docs/commands.md`·`commands.ko.md` | 시놉시스 `<name...|all>` + 다중 타겟 단락·예시 |
| `README.md`·`README.ko.md` | 명령 시놉시스 + "자주 쓰는 명령" 표 |
| `docs/TODO.md` | bats 테스트 수 81→167 갱신 |
| `CHANGELOG.md` | `[Unreleased] Added` 항목 |
| `tests/up_down.bats` | 다중 타겟 회귀 +7 (SC-001~006·FR-007·단일 무요약) |

## 검증 결과

- `bats tests/` **167/167 PASS** (신규 7건 포함)
- i18n 키 패리티(en/ko) 158키 OK
- `shellcheck -S warning`(core) + `completions/cctg.bash` PASS
- 스모크(en/ko): 요약·종료코드·continue-on-error 실측 확인

> DIFF 산출물은 git diff 가 SoT 이므로 별도 미생성 (orchestration.md §12.2, no-silent-caps).
