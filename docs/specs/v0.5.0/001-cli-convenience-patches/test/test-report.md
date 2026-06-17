---
작성: Test Agent (EXECUTION)
버전: v1.0
최종 수정: 2026-06-17 23:16
상태: 확정
---

# 테스트 실행 결과

## 목차

- [실행 요약](#실행-요약)
- [실패 목록](#실패-목록)
- [SC 미커버 항목](#sc-미커버-항목)
- [plan.md 매핑표 검증](#planmd-매핑표-검증)
- [설계 문서 정합성](#설계-문서-정합성)
- [회귀 탐지](#회귀-탐지)

---

## 실행 요약

| 항목 | 값 |
|---|---|
| 실행 도구 | bats 1.13.0 |
| 실행 명령 | `bats tests/` (프로젝트 루트) |
| 총 테스트 수 | 151 |
| 통과 | 151 |
| 실패 | 0 |
| 스킵 | 0 |
| 신규 SC 매핑 테스트 | 32 (@test 단위) |
| 기존 테스트 (회귀) | 119 |

### 정적 검증

| 검증 | 결과 | 비고 |
|---|---|---|
| `bash -n` (cc-tg.sh + lib/*.sh 8개) | OK | 모두 구문 오류 없음 |
| `shellcheck -S warning` (변경 파일 8개) | OK | 신규 경고 0건. SC2148(shebang 부재) pre-existing — 소스 전용 lib 파일 의도적 패턴 |
| `scripts/check-i18n-keys.sh` | OK | 154키 en/ko 패리티 정상 |

---

## 실패 목록

없음. 151/151 PASS.

---

## SC 미커버 항목

| SC-ID | 미커버 유형 | 처리 |
|---|---|---|
| SC-025 error-path | $PWD 삭제 디렉터리 Error Case | coverage-gap.md 카테고리 (3) — 운영 환경 수동 검증 위임. gate에 영향 없음. |

---

## plan.md 매핑표 검증

**SC 매핑 테이블**:

| SC-ID | 관련 테스트 | 통과 여부 | 미커버 근본원인 |
|---|---|---|---|
| SC-001 | config.bats::"config cwd: updates registry column 2 (SC-001)" | PASS | — |
| SC-002 | config.bats::"config cwd: rejects non-existent dir (SC-002)" | PASS | — |
| SC-003 | config.bats::"config cwd: hints restart when running (SC-003)" | PASS | — |
| SC-004 | config.bats::"config token: rewrites .env with telegram key, mode 600 (SC-004)" | PASS | — |
| SC-005 | config.bats::"config token: rejects empty token (SC-005)" | PASS | — |
| SC-006 | config.bats::"config token: uses DISCORD_BOT_TOKEN for discord (SC-006)" | PASS | — |
| SC-007 | static.bats::"completions/_cctg: config mode offers 6 modes (SC-007)" | PASS | — |
| SC-008 | static.bats::"completions/cctg.bash: config mode offers 6 modes (SC-008)" | PASS | — |
| SC-009 | static.bats::"completions: config actions include cwd and token (SC-009)" | PASS | — |
| SC-010 | help.bats::"add --help: prints usage, exit 0 (SC-010)" | PASS | — |
| SC-011 | help.bats::"config --help: prints usage, exit 0 (SC-011)" | PASS | — |
| SC-012 | static.bats::"completions: subcommand flags include --help (SC-012)" | PASS | — |
| SC-013 | static.bats::"i18n: en/ko key parity (SC-013)" | PASS | — |
| SC-014 | reserved.bats::"up telegram: starts cctg-telegram session (SC-014)" | PASS | — |
| SC-015 | reserved.bats::"up telegram: refuses when session exists (SC-015)" | PASS | — |
| SC-016 | reserved.bats::"up telegram: refuses when bot.pid alive (SC-016)" | PASS | — |
| SC-017 | reserved.bats::"up telegram: refuses when .env missing (SC-017)" | PASS | — |
| SC-018 | reserved.bats::"down telegram: kills cctg-telegram session (SC-018)" | PASS | — |
| SC-019 | reserved.bats::"down telegram: reports none + bot.pid limit note (SC-019)" | PASS | — |
| SC-020 | reserved.bats::"status: includes reserved bot state (SC-020)" | PASS | — |
| SC-021 | reserved.bats::"logs telegram: prints capture-pane (SC-021)" | PASS | — |
| SC-022 | static.bats::"reserved: add telegram still rejected (SC-022)" | PASS | — |
| SC-023 | static.bats::"syntax: no associative arrays / Bash4+ in new code (SC-023)" + 3개 bash -n 테스트 | PASS | — |
| SC-024 | reserved.bats::"down telegram: leaves .env/access.json untouched (SC-024)" | PASS | — |
| SC-025 | reserved.bats::"up telegram: session launch uses $PWD as cwd (SC-025)" | PASS | error-path → coverage-gap (3) |

---

## 설계 문서 정합성

### plan.md 핵심 설계 대조

- **SC-025 up_reserved cwd 처리**: plan.md DEC-001 설계 — `cwd="$PWD"` 캡처 후 `cd $(printf '%q' "$cwd")` launch 문자열 삽입. session.sh:137, 152 확인 — 정합.
- **up_reserved tmux 호출 형식**: plan.md 설계 → `bash -lc "$launch"` (분리 인자). session.sh:161 확인 — 분리 인자 형식으로 정확히 구현됨. SC-025 stub `FAKE_TMUX_LASTCMD` 캡처가 이 형식에서 정상 동작 확인.
- **SC-019 RESERVED_DOWN_NONE 메시지**: NFR-003 bot.pid 한계 명시 요건. `CCTG_MSG_RESERVED_DOWN_NONE` 메시지에 `bot.pid`·`NFR-003 limit` 문구 확인 — 정합.
- **config token .env 형식**: plan.md 설계 → `printf '%s=%s\n' "$key" "$token"` 직접 쓰기 (set_env_kv 미사용). lib/config.sh 확인 — 정합.
- **i18n 154키**: messages/en.sh · messages/ko.sh 패리티 스크립트 확인 — 정합.

### 불일치 항목

없음. production 코드 수정 불필요.

---

## 회귀 탐지

기존 119개 테스트 (baseline 908eb5c) 전부 PASS. 신규 실패 0건.

주요 회귀 안전 확인:
- add.bats (25): 예약어 가드 등 기존 동작 불변
- channel.bats (12): discord descriptor 기존 동작 불변
- up_down.bats (9): 프로젝트 봇 up/down 불변
- static.bats 기존 11: discord 하드코딩 제거 등 기존 검증 불변
