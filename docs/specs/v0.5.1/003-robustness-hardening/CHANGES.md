# CHANGES — v0.5.1/003-robustness-hardening

> 작성: 2026-06-18 16:30 | 버전: 1.0 | 최종 수정: 2026-06-18 16:30 | 상태: 완료(검증 통과)

## 목차

- [요약](#요약)
- [감사 결과 (TODO 정확성 + 구조)](#감사-결과-todo-정확성--구조)
- [구현 (견고성 P1·P2 + 값싼 P3)](#구현-견고성-p1p2--값싼-p3)
- [TODO 재정리](#todo-재정리)
- [변경 파일](#변경-파일)
- [검증 결과](#검증-결과)
- [의도적 비변경 / 잔여](#의도적-비변경--잔여)

## 요약

TODO 문서를 현재 코드와 대조 감사한 결과 **~80% 가 이미 해결됨(stale)**, **구조 개선은 불필요**(lib/ 이미 8 모듈)로 판정했다. 진짜 열린 항목인 **게이트웨이 신뢰성 견고성**의 P1·P2 핵심을 구현하고(거짓 UP 제거·tmux/claude 가드·down/logs 검증), TODO.md 를 전면 재정리했다.

## 감사 결과 (TODO 정확성 + 구조)

- **TODO 정확성**: 2026-06-16 감사 항목 다수가 v0.1~v0.5.1 에서 이미 해결됨 → 제거 대상. 해결 확인: 0.2.0 발행(VERSION=0.5.0)·README 버전 하드코딩·CONTRIBUTING 브랜치 정책·.shellcheckrc·.editorconfig·.gitignore(.env/RELEASE_NOTES)·rm/rename 자동완성·remove/mv 별칭 제거·lib/ 런타임 분리(8 모듈)·discord 게이트웨이·release.yml VERSION 하드닝·uninstall 잔여물/bindir·텍스트 status 테스트.
- **구조 개선 필요성**: **불필요.** `cc-tg.sh`→`lib/*.sh` 분리 완료(env/output/channels/config/util/registry/session/commands). 최대 파일 commands.sh ~770줄로 관리 가능하며, 도메인 추가 분할은 현 규모에서 단일 파일이 더 단순(TODO 자체 권고와 일치) → 보류.

## 구현 (견고성 P1·P2 + 값싼 P3)

- **R1 (P1) 거짓 UP 제거** — `up_one`·`up_reserved` 가 `tmux new-session` 종료 코드를 확인하고 실패 시 `ERR_UP_FAILED`(비0)로 보고. 실패 시 `UP_OK` 미출력·snapshotter 미기동. 미확인 시 "UP 보고했는데 실제 미기동" 신뢰성 위반이 있었다.
- **R2 (P1) 런타임 가드** — `need_tmux`/`need_claude`(lib/util.sh). lifecycle(`up`/`down`/`restart`)는 `_lifecycle_run` 진입에서 `need_tmux`, `attach` 도 동형. `up` 은 기동 전 `need_claude` 로 거부(claude 부재 시 세션이 `exec bash` 로 살아남아 거짓 UP).
- **R3 (P2) 거짓 DOWN 제거** — `down_one`·`down_reserved` 가 `tmux kill-session` 종료 코드를 확인하고 실패 시 `ERR_DOWN_FAILED`(비0).
- **R4 (P2) logs N 검증** — `cmd_logs` 가 줄 수 인자를 `^[0-9]+$` 로 검증, 비숫자는 `ERR_BAD_LOG_N` 로 거부(tail cryptic 에러 대신).
- **R5 (P3, 값쌈) snapshotter 기동 확인** — `start_snapshotter` 가 `kill -0` 로 watcher 기동을 확인하고 실패 시 비0 반환 → `up_one` 이 `WARN_SNAPSHOT_FAILED` 경고(스냅샷은 옵트인 부가기능이라 up 자체는 성공 유지).

테스트 인프라: fake tmux stub 에 `FAKE_TMUX_FAIL_NEWSESSION`/`FAKE_TMUX_FAIL_KILL` 실패 주입 추가, `need_claude` 가드를 위한 `tests/stubs/claude`(no-op) 신설.

## TODO 재정리

`docs/TODO.md` 전면 재작성 — 해결된 ~80% 제거, 잔여 유효 항목만 정돈: imessage 게이트웨이(대형), (선택)commands.sh 도메인 분할, main 브랜치 보호(외부 repo 설정), 잔여 P3(access.json/launch.env 초기 작성 원자화·TOCTOU), 테스트 커버리지 잔여(attach/update·launch 문자열·install/uninstall).

## 변경 파일

- `lib/util.sh` — `need_tmux`/`need_claude` 헬퍼.
- `lib/session.sh` — `up_one`/`up_reserved` new-session 가드 + need_claude, `down_one`/`down_reserved` kill-session 가드, `start_snapshotter` 기동 확인.
- `lib/commands.sh` — `_lifecycle_run` need_tmux, `cmd_attach` need_tmux, `cmd_logs` N 검증.
- `messages/en.sh`·`ko.sh` — 신규 6키(ERR_NO_TMUX/ERR_NO_CLAUDE/ERR_UP_FAILED/ERR_DOWN_FAILED/ERR_BAD_LOG_N/WARN_SNAPSHOT_FAILED), 패리티 167.
- `tests/stubs/tmux`(실패 주입)·`tests/stubs/claude`(신설)·`tests/up_down.bats`(+5).
- `docs/TODO.md`(전면 재정리)·`CHANGELOG.md`([Unreleased] 2건).

## 검증 결과

- `bats tests/*.bats`: **182/182 PASS**(신규 5건: R1·R2×2·R3·R4, 회귀 0)
- `scripts/check-i18n-keys.sh`: PASS (en/ko 패리티 + 참조 키, **167 키**)
- `bash -n`(util/session/commands)·`shellcheck -S warning cc-tg.sh install.sh uninstall.sh scripts/*.sh`(CI 동일): **EXIT 0**

## 의도적 비변경 / 잔여 (no-silent-caps)

- **imessage 게이트웨이**: 대형 별도 기능 → 재정리된 TODO 잔존.
- **main 브랜치 보호**: GitHub repo Settings 수동 설정(코드 불가) → TODO + 사용자 안내.
- **access.json/launch.env 초기 작성 원자화·TOCTOU**: P3-낮음(비밀 아님 + 가드/EXIT trap 존재) → TODO 잔존.
- **DIFF 산출물**: `git diff` 가 SoT.
