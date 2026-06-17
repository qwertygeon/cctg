---
작성: Test Agent (EXECUTION)
버전: v1.0
최종 수정: 2026-06-17 15:54
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
- [GAP 처리 검증](#gap-처리-검증)

---

## 실행 요약

- 실행 명령: `bats tests/`
- TAP 플랜: `1..119`
- 전체: **119** / 통과: **119** / 실패: **0** / 스킵: **0**
- 검증 전략: `tdd`(신규 행위 — discord 활성화·`--group`·id_required 분기·status 표시) + 기존 89 테스트 `characterization` 회귀(SC-024)
- 환경: macOS Bash 3.2 / bats 1.13.0 / jq 1.7.1 / SC-020 은 jq-less PATH 시뮬레이션
- 본 spec SC-매핑 테스트 32건(SC-001~032) + 기존 회귀 89건. 실행 범위는 `bats tests/` 전체(프로젝트 규모상 SC 매핑 + 회귀가 동일 디렉토리, smoke 분리 없음).

---

## 실패 목록

없음 (0건).

---

## SC 미커버 항목

없음 (0건). SC-001~032 전수가 통과 테스트로 커버됨. 스켈레톤 작성 불필요.

---

## plan.md 매핑표 검증

SC-001~032 전수가 plan.md 테스트 전략 / tasks.md Test Authoring Contract 의 SC 매핑과 일치하며, 각 SC 가 1개 이상 통과 테스트로 검증됨.

**SC 매핑 테이블**:

| SC-ID | 관련 테스트 | 통과 여부 | 미커버 근본원인 |
|---|---|---|---|
| SC-001 | static.bats: `channels.sh: IMPLEMENTED_CHANNELS includes discord (SC-001)` | PASS | - |
| SC-002 | static.bats: `channels.sh: discord descriptor arms are active, not commented (SC-002)` | PASS | - |
| SC-003 | channel.bats: `add --channel discord: not refused as unsupported (SC-003)` + 미구현 fakechat refused | PASS | - |
| SC-004 | channel.bats: `channel_spec: telegram exposes all 8 fields (SC-004)` | PASS | - |
| SC-005 | channel.bats: `channel_spec: discord exposes all 8 fields (SC-005)` | PASS | - |
| SC-006 | channel.bats: `channel_spec: discord display/id_required/seed_policy values (SC-006)` | PASS | - |
| SC-007 | add.bats: `discord without --id proceeds (no ERR_ADD_NEED_ID) (SC-007)` | PASS | - |
| SC-008 | add.bats: `telegram without --id is still refused (SC-008)` | PASS | - |
| SC-009 | add.bats: `discord --id absent seeds pairing/[]/{}, no pending (SC-009)` | PASS | - |
| SC-010 | add.bats: `discord --id present seeds allowlist with id, no pending (SC-010)` | PASS | - |
| SC-011 | add.bats: `telegram seed has no pending field (SC-011)` | PASS | - |
| SC-012 | static.bats: `messages: ADD_PROMPT_TGID has no telegram-specific string (SC-012)` | PASS | - |
| SC-013 | static.bats: `messages: STATUS_GLOBAL has no /telegram hardcoding (SC-013)` | PASS | - |
| SC-014 | static.bats: `messages: STATUS_HINT_NO_TOKEN has no TELEGRAM_BOT_TOKEN hardcoding (SC-014)` | PASS | - |
| SC-015 | static.bats: `messages: DOCTOR_PLUGIN_HINT has no telegram-specific install path (SC-015)` | PASS | - |
| SC-016 | static.bats: `completions/_cctg: --channel is not a bare telegram literal (SC-016)` | PASS | - |
| SC-017 | static.bats: `completions/cctg.bash: --channel is not a bare telegram literal (SC-017)` | PASS | - |
| SC-018 | status_view.bats: `status: shows Telegram and Discord display names per bot (SC-018)` | PASS | - |
| SC-019 | status_view.bats: `status: with jq shows dmPolicy and group count for a discord bot (SC-019)` | PASS | - |
| SC-020 | status_view.bats: `status: without jq degrades to display name only, no error (SC-020)` | PASS | - |
| SC-021 | static.bats: `syntax: posix -n passes for channels.sh/en.sh/ko.sh/cctg.bash (SC-021)` + `bash -n passes for commands.sh (SC-021, GAP-002 non-posix)` | PASS | - |
| SC-022 | add.bats: `discord writes DISCORD_BOT_TOKEN into .env (SC-022)` | PASS | - |
| SC-023 | channel.bats: `legacy 3-column registry row is treated as telegram` | PASS | - |
| SC-024 | `bats tests/` 전체 119 PASS (회귀 89건 포함, 0 fail) | PASS | - |
| SC-025 | add.bats: `--group <id> once seeds that key (SC-025)` | PASS | - |
| SC-026 | add.bats: `--group twice seeds both keys (SC-026)` | PASS | - |
| SC-027 | add.bats: `non-numeric --group id errors and registers nothing (SC-027)` | PASS | - |
| SC-028 | SC-009/SC-010 의 `.groups == {}` 단언으로 갈음 | PASS | - |
| SC-029 | static.bats: `completions: add flag candidates include --group (SC-029)` | PASS | - |
| SC-030 | add.bats: `--group :nomention sets requireMention false (SC-030)` | PASS | - |
| SC-031 | add.bats: `--group :allow= seeds the listed members (SC-031)` | PASS | - |
| SC-032 | add.bats: `--group :allow= with non-numeric member errors, registers nothing (SC-032)` | PASS | - |

SC 없는 FR/NFR: 0건. 미커버 SC: 0건. deferred(→ Deploy): 0건.

---

## 설계 문서 정합성

- **요구사항 대조**: spec.md FR-001~008 / NFR-001~005 의 SC 가 모두 통과 테스트로 검증됨. 누락 요구사항 0건.
- **DEC-001 정합**: decisions.md DEC-001 컴파운드 토큰 문법(`--group <id>[:nomention][:allow=...]`)이 구현·테스트와 일치 — SC-030(`:nomention`), SC-031(`:allow=`), SC-032(에러) 단언이 DEC-001 예시와 1:1 대응.
- **소스 대조**: lib/channels.sh `IMPLEMENTED_CHANNELS="telegram discord"`(L11), discord descriptor 8필드 활성(L26~33, display=Discord/id_required=no/seed_policy=pairing)이 SC-001/002/006 단언과 정확히 일치.
- **불일치 발견: 0건.** 구현 코드 수정 불필요(본 Agent 는 코드 미수정).
- **잔여 권고(비차단)**: spec.md SC-021 Given 절이 commands.sh 를 `bash --posix -n` 대상에 포함하나, commands.sh 는 사전 존재 process substitution 으로 `--posix -n` 불가(GAP-002). 테스트는 `bash -n`(non-posix)으로 정합 검증함. 6단계 Docs/회고에서 SC-021 문구 정정 검토 권고.

---

## 회귀 탐지

- 기존 회귀 테스트(본 spec 신규 SC-매핑 32건 제외) 89건 전부 PASS — common/config/lang/misc/rename/rm/snapshot/status_json/up_down + add/channel 기존 케이스.
- SC-024(회귀 0) 충족: baseline 88(spec.md 기준) + legacy SC-023 포함 기존 동작 불변. 신규 추가로 총 119건. 신규 실패(회귀) 0건.
- GAP-001 의 의도된 동작 변경(discord refused → not refused)은 SC-003 으로 재정의되었으며 회귀가 아님.

---

## GAP 처리 검증

- **GAP-001** (RESOLVED): channel.bats 가 SC-003 양방향 검증으로 갱신됨(discord not-refused + 미구현 fakechat refused). 5b 실행 PASS 확인.
- **GAP-002** (RESOLVED): static.bats SC-021 분리(`--posix -n` 4파일 + `bash -n` commands.sh). 양 테스트 PASS. spec.md SC-021 문구 정정은 6단계/회고 비차단 권고로 이관.

---

## 책임 경계 밖 (통합 — 운영 검증)

실제 Discord API 연결(봇 토큰·Gateway·서버 필요)은 spec.md "범위 외"·플러그인 런타임 소유 영역으로 SC 가 아니다. coverage-gap.md "책임 경계 밖 — 운영 검증 위임 항목"(카테고리 (3)/(4)) 참조. **게이트 미커버가 아니며 Docs Agent 진행 가능 조건 충족.**
