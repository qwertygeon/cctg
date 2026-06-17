---
작성: Test Agent (AUTHORING)
버전: v1.0
최종 수정: 2026-06-17 22:55
상태: 확정
---

# Test Cases: cli-convenience-patches

## 목차

- [SC × 시나리오 매트릭스](#sc--시나리오-매트릭스)
- [외부 의존성 명시](#외부-의존성-명시)
- [미커버 항목 (사전 분류)](#미커버-항목-사전-분류)

---

## SC × 시나리오 매트릭스

| SC-ID | 수용 기준 | Happy Path | Edge Case | Error Case | 테스트 파일·함수 | env 태그 |
|---|---|---|---|---|---|---|
| SC-001 | config cwd → 레지스트리 2컬럼 갱신 | "config cwd: updates registry column 2 (SC-001)" | — | — | tests/config.bats::"config cwd: updates registry column 2 (SC-001)" | [env:unit] |
| SC-002 | 부재 경로 거부 | — | — | "config cwd: rejects non-existent dir (SC-002)" | tests/config.bats::"config cwd: rejects non-existent dir (SC-002)" | [env:unit] |
| SC-003 | running 시 restart 안내 | — | "config cwd: hints restart when running (SC-003)" | — | tests/config.bats::"config cwd: hints restart when running (SC-003)" | [env:unit] |
| SC-004 | token → .env telegram 키 600 | "config token: rewrites .env with telegram key, mode 600 (SC-004)" | — | — | tests/config.bats::"config token: rewrites .env with telegram key, mode 600 (SC-004)" | [env:unit] |
| SC-005 | 빈 토큰 거부 | — | — | "config token: rejects empty token (SC-005)" | tests/config.bats::"config token: rejects empty token (SC-005)" | [env:unit] |
| SC-006 | discord token → DISCORD 키 | "config token: uses DISCORD_BOT_TOKEN for discord (SC-006)" | — | — | tests/config.bats::"config token: uses DISCORD_BOT_TOKEN for discord (SC-006)" | [env:unit] |
| SC-007 | zsh mode 완성 6종 | "completions/_cctg: config mode offers 6 modes (SC-007)" | — | — | tests/static.bats::"completions/_cctg: config mode offers 6 modes (SC-007)" | [env:static] |
| SC-008 | bash mode 완성 6종 | "completions/cctg.bash: config mode offers 6 modes (SC-008)" | — | — | tests/static.bats::"completions/cctg.bash: config mode offers 6 modes (SC-008)" | [env:static] |
| SC-009 | config 액션에 cwd·token | "completions: config actions include cwd and token (SC-009)" | — | — | tests/static.bats::"completions: config actions include cwd and token (SC-009)" | [env:static] |
| SC-010 | add --help 사용법 | "add --help: prints usage, exit 0 (SC-010)" | — | — | tests/help.bats::"add --help: prints usage, exit 0 (SC-010)" | [env:unit] |
| SC-011 | config --help 사용법 | "config --help: prints usage, exit 0 (SC-011)" | — | — | tests/help.bats::"config --help: prints usage, exit 0 (SC-011)" | [env:unit] |
| SC-012 | 완성에 --help 포함 | "completions: subcommand flags include --help (SC-012)" | — | — | tests/static.bats::"completions: subcommand flags include --help (SC-012)" | [env:static] |
| SC-013 | en/ko 키 패리티 | — | "i18n: en/ko key parity (SC-013)" | — | tests/static.bats::"i18n: en/ko key parity (SC-013)" | [env:unit] |
| SC-014 | up telegram 세션 기동 | "up telegram: starts cctg-telegram session (SC-014)" | — | — | tests/reserved.bats::"up telegram: starts cctg-telegram session (SC-014)" | [env:unit] |
| SC-015 | 세션 점유 거부 | — | — | "up telegram: refuses when session exists (SC-015)" | tests/reserved.bats::"up telegram: refuses when session exists (SC-015)" | [env:unit] |
| SC-016 | bot.pid 생존 거부 | — | — | "up telegram: refuses when bot.pid alive (SC-016)" | tests/reserved.bats::"up telegram: refuses when bot.pid alive (SC-016)" | [env:unit] |
| SC-017 | .env 부재 거부 | — | — | "up telegram: refuses when .env missing (SC-017)" | tests/reserved.bats::"up telegram: refuses when .env missing (SC-017)" | [env:unit] |
| SC-018 | down telegram 세션 종료 | "down telegram: kills cctg-telegram session (SC-018)" | — | — | tests/reserved.bats::"down telegram: kills cctg-telegram session (SC-018)" | [env:unit] |
| SC-019 | 세션 없음 한계 안내 | — | "down telegram: reports none + bot.pid limit note (SC-019)" | — | tests/reserved.bats::"down telegram: reports none + bot.pid limit note (SC-019)" | [env:unit] |
| SC-020 | status 예약어 표시 | "status: includes reserved bot state (SC-020)" | — | — | tests/reserved.bats::"status: includes reserved bot state (SC-020)" | [env:unit] |
| SC-021 | logs telegram 출력 | "logs telegram: prints capture-pane (SC-021)" | — | — | tests/reserved.bats::"logs telegram: prints capture-pane (SC-021)" | [env:unit] |
| SC-022 | 예약어 add/rm/rename 차단 | — | — | "reserved: add telegram still rejected (SC-022)" | tests/static.bats::"reserved: add telegram still rejected (SC-022)" | [env:unit] |
| SC-023 | Bash 3.2 구문 | — | "syntax: no associative arrays / Bash4+ in new code (SC-023)" | — | tests/static.bats::"syntax: no associative arrays / Bash4+ in new code (SC-023)" | [env:static] |
| SC-024 | down 이 .env/access.json 불변 | — | "down telegram: leaves .env/access.json untouched (SC-024)" | — | tests/reserved.bats::"down telegram: leaves .env/access.json untouched (SC-024)" | [env:unit] |
| SC-025 | up cwd=$PWD 기동 | "up telegram: session launch uses $PWD as cwd (SC-025)" | — | — | tests/reserved.bats::"up telegram: session launch uses \$PWD as cwd (SC-025)" | [env:unit] |

---

## 외부 의존성 명시

- fixture: test_helper.bash — seed_global() helper (reserved.bats 내부 정의), seed_bot(), mark_running(), registry_raw(), file_mode()
- stub: tests/stubs/tmux — fake tmux; new-session 이 FAKE_TMUX_STATE 에 세션 기록 + FAKE_TMUX_LASTCMD 에 인자 캡처(SC-025 용)
- 환경 변수: FAKE_TMUX_STATE(상태 파일), FAKE_TMUX_LASTCMD(SC-025 launch 인자 캡처), CC_CHANNELS_DIR(격리 채널 디렉터리), CCTG_LANG=en(안정적 영어 출력)
- 외부 서비스: 없음 — fake tmux stub 이 실제 tmux 세션 없이 동작

---

## 미커버 항목 (사전 분류 — 4-카테고리)

| SC-ID | 미커버 사유 | 카테고리 | 권장 검증 방법 |
|---|---|---|---|
| SC-025 error-path | $PWD 삭제 디렉터리에서의 ERR_NO_CWD 경로 — bats 내에서 cd를 삭제된 디렉터리로 이동하는 것이 셸에 따라 비결정적 | (3) 운영 환경 권장 | 운영 환경에서 삭제된 디렉터리 상태에서 up telegram 실행 |
| SC-019 (bot.pid 한계) | RESERVED_DOWN_NONE 메시지에 NFR-003 bot.pid 한계 명시 여부는 메시지 키 내용에 의존 — 메시지 문자열 구현 전 정확한 토큰 불명 | (1) 단위테스트 가능 | 5b에서 실제 메시지 키 내용 확인 후 단언 보강 |

> 카테고리 (1) SC-019 bot.pid 한계 단언: 5b EXECUTION 에서 실제 메시지 키 내용 확인 후 test 단언 보강 권장.
> 카테고리 (3) SC-025 error-path: 운영 환경 수동 검증으로 위임.
