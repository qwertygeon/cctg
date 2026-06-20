# DIFF — v0.6.0/003-defensive-hardening

> **SoT 는 `git diff develop`** (이 브랜치 `feature/defensive-hardening` 의 base 는 develop). 본 문서는 요약본이다.
> 재생성: `git diff develop` (추적 파일) + `git status --short`(미추적: 신규 파일·SPEC_ROOT 산출물).
> 작성: 2026-06-20 19:34 / 모드: direct.

## 추적 파일 변경 (`git diff develop --stat`)

```
 CHANGELOG.md           |  11 +++
 cc-tg.sh               |   5 +-
 docs/TODO.md           | 194 +++++++++++++++++++--------------------
 lib/commands.sh        |  94 ++++++++++++++++++----
 lib/config.sh          |  43 +++++++++--
 lib/session.sh         |  21 +++++-
 lib/util.sh            |  11 +++
 messages/en.sh         |  18 ++++-
 messages/ko.sh         |  18 ++++-
 tests/add.bats         |  38 ++++++++--
 tests/config.bats      |  77 ++++++++++++++++++--
 tests/misc.bats        |  64 ++++++++++++++++
 tests/reserved.bats    |  16 +++-
 tests/snapshot.bats    |   4 +-
 tests/status_json.bats |  24 ++++++
 tests/status_view.bats |  25 +++++++
 tests/stubs/tmux       |   2 +
 tests/up_down.bats     |   4 +
 18 files changed, 533 insertions(+), 136 deletions(-)
```

## 미추적(신규) — `git diff develop` 미포함

- `tests/launch.bats` — launch 문자열 wiring 검증 테스트(6 케이스).
- `docs/specs/v0.6.0/003-defensive-hardening/` — 본 차수 산출물(pipeline-log·decisions·scope).

## 영역별 요약

| 영역 | 핵심 |
|---|---|
| `lib/config.sh` | `shq()`(단일따옴표 이스케이프)·`write_atomic()`(tmp→mv) 신설; `write_token_env`/`set_env_kv` 가 shq 경유; no-slash dir 폴백. |
| `lib/commands.sh` | doctor `install integrity` 점검; `status` last-activity(text+json)+음수 클램프; access.json/launch.env/registry 원자 쓰기; `--group` 미지 수식어 거부; `config args` 개행 거부; status/logs tmux 경고. |
| `lib/session.sh` | `last_activity_epoch()`; 액션 에러 복구 힌트(ERR_NO_CWD/NOT_REGISTERED). |
| `lib/util.sh` | `file_perm`/`file_mtime`/`warn_no_tmux_readonly`. |
| `messages/{en,ko}.sh` | 신규 키(en/ko 패리티 194키): GROUP_MOD·NO_TMUX·NO_CWD_HINT·DOCTOR_*·LAST_ACTIVITY·CONFIG_ARGS_NEWLINE 등. |
| `cc-tg.sh` | 시작 시 `mkdir`/registry 초기화 가드. |
| `tests/*` | +launch.bats, doctor/last-activity/원자화/인젝션-안전/에러힌트 회귀; 스텁 `#{window_activity}`. |

## 검증

- `bats tests/`: 242 passed / 0 failed.
- `scripts/check-i18n-keys.sh`: OK (194 키).
- `shellcheck -S warning cc-tg.sh install.sh uninstall.sh scripts/*.sh`: rc=0.
