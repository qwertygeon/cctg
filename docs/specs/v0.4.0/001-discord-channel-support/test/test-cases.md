---
작성: Test Agent (AUTHORING)
버전: v1.0
최종 수정: 2026-06-17 15:51
상태: 확정
---

# Test Cases: discord-channel-support

## 목차

- [개요](#개요)
- [SC × 시나리오 매트릭스](#sc--시나리오-매트릭스)
- [GAP 처리 내역](#gap-처리-내역)
- [외부 의존성 명시](#외부-의존성-명시)
- [미커버 항목 (사전 분류 — 4-카테고리)](#미커버-항목-사전-분류--4-카테고리)

---

## 개요

본 spec 의 D 레이어(tasks.md T008) 산출물. SC-001~032 를 unit(bats)·static(grep/`bash -n`) 으로 커버한다.
통합(실제 Discord API 연결)은 spec "범위 외" 이므로 작성하지 않는다.

검증 전략: `tdd`(신규 행위 — discord 활성화·`--group`·id 분기·status 표시) + 기존 88 테스트 `characterization` 회귀(SC-024).

테스트 파일 구성:

| 파일 | 역할 | env |
|---|---|---|
| `tests/static.bats` (신규) | 소스 grep + `bash -n`/`--posix -n` | static |
| `tests/channel.bats` (확장) | descriptor·UNSUPPORTED 게이트·legacy | unit |
| `tests/add.bats` (확장) | id 분기·시드(pending 부재)·`--group` | unit |
| `tests/status_view.bats` (신규) | 비JSON status 표시명·토폴로지·jq degradation | unit |
| `tests/status_json.bats`·`tests/misc.bats` 등 (불변) | 기존 회귀 (SC-024) | unit |

---

## SC × 시나리오 매트릭스

| SC-ID | 수용 기준 | 유형 | 테스트 파일·함수 | env |
|---|---|---|---|---|
| SC-001 | IMPLEMENTED_CHANNELS 에 discord | Happy | static.bats: `channels.sh: IMPLEMENTED_CHANNELS includes discord (SC-001)` | static |
| SC-002 | discord descriptor 활성 case | Happy | static.bats: `discord descriptor arms are active (SC-002)` | static |
| SC-003 | add --channel discord ≠ UNSUPPORTED | Error→Happy | channel.bats: `add --channel discord: not refused as unsupported (SC-003)` + `<unimplemented>: refused (fakechat)` | unit |
| SC-004 | telegram 8필드 | Happy | channel.bats: `channel_spec: telegram exposes all 8 fields (SC-004)` | unit |
| SC-005 | discord 8필드 | Happy | channel.bats: `channel_spec: discord exposes all 8 fields (SC-005)` | unit |
| SC-006 | discord display/id_required/seed_policy 값 | Happy | channel.bats: `discord display/id_required/seed_policy values (SC-006)` | unit |
| SC-007 | discord --id 없이 진행 | Edge | add.bats: `discord without --id proceeds (SC-007)` | unit |
| SC-008 | telegram --id 없이 → ERR_ADD_NEED_ID | Error | add.bats: `telegram without --id is still refused (SC-008)` | unit |
| SC-009 | discord --id 미제공 시드 pairing/[]/{}/no-pending | Happy | add.bats: `discord --id absent seeds pairing/[]/{}, no pending (SC-009)` | unit |
| SC-010 | discord --id 제공 시드 allowlist/no-pending | Happy | add.bats: `discord --id present seeds allowlist (SC-010)` | unit |
| SC-011 | telegram 시드 pending 제거 | Happy | add.bats: `telegram seed has no pending field (SC-011)` | unit |
| SC-012 | ADD_PROMPT_TGID telegram 문자열 없음 | Happy | static.bats: `ADD_PROMPT_TGID has no telegram-specific string (SC-012)` | static |
| SC-013 | STATUS_GLOBAL /telegram 없음 | Happy | static.bats: `STATUS_GLOBAL has no /telegram (SC-013)` | static |
| SC-014 | STATUS_HINT_NO_TOKEN 하드코딩 없음 | Happy | static.bats: `STATUS_HINT_NO_TOKEN has no TELEGRAM_BOT_TOKEN (SC-014)` | static |
| SC-015 | DOCTOR_PLUGIN_HINT telegram 특정 없음 | Happy | static.bats: `DOCTOR_PLUGIN_HINT has no telegram-specific install path (SC-015)` | static |
| SC-016 | zsh --channel 동적 | Happy | static.bats: `_cctg: --channel is not a bare telegram literal (SC-016)` | static |
| SC-017 | bash --channel 동적 | Happy | static.bats: `cctg.bash: --channel is not a bare telegram literal (SC-017)` | static |
| SC-018 | status 채널 표시명 | Happy | status_view.bats: `shows Telegram and Discord display names (SC-018)` | unit |
| SC-019 | jq 있을 때 토폴로지 | Happy | status_view.bats: `with jq shows dmPolicy and group count (SC-019)` | unit |
| SC-020 | jq 없을 때 degradation | Edge | status_view.bats: `without jq degrades to display name only (SC-020)` | unit |
| SC-021 | bash -n 통과 | Happy | static.bats: `posix -n passes for ...4파일 (SC-021)` + `bash -n passes for commands.sh (GAP-002)` | static |
| SC-022 | DISCORD_BOT_TOKEN 저장 | Happy | add.bats: `discord writes DISCORD_BOT_TOKEN into .env (SC-022)` | unit |
| SC-023 | 레거시 3컬럼 → telegram | Edge | channel.bats: `legacy 3-column registry row is treated as telegram` (기존) | unit |
| SC-024 | 기존 테스트 회귀 0 | Happy(회귀) | `bats tests/` 전체 119 PASS (baseline 88 + 신규, 0 fail) | unit |
| SC-025 | --group 1회 groups 키 | Happy | add.bats: `--group <id> once seeds that key (SC-025)` | unit |
| SC-026 | --group 2회 두 키 | Happy | add.bats: `--group twice seeds both keys (SC-026)` | unit |
| SC-027 | 비숫자 group id 에러·미등록 | Error | add.bats: `non-numeric --group id errors and registers nothing (SC-027)` | unit |
| SC-028 | --group 미지정 groups{} | (갈음) | SC-009/010 (`.groups == {}` 단언) 로 갈음 | unit |
| SC-029 | 완성에 --group | Happy | static.bats: `add flag candidates include --group (SC-029)` | static |
| SC-030 | nomention → requireMention false | Edge | add.bats: `--group :nomention sets requireMention false (SC-030)` | unit |
| SC-031 | allow → allowFrom 멤버 포함 | Happy | add.bats: `--group :allow= seeds the listed members (SC-031)` | unit |
| SC-032 | allow 비숫자 멤버 에러·미등록 | Error | add.bats: `--group :allow= with non-numeric member errors (SC-032)` | unit |

> SC-001~032 전수 매핑(SC 없는 FR 0). 5a 책임은 작성이나, 직렬 실행 이점으로 작성 후 `bats tests/` 실행 — 전수 PASS 확인(상세는 5b EXECUTION 최종 검증).

---

## GAP 처리 내역

- **GAP-001**: 기존 `channel.bats` "add --channel <unsupported>: refused"(discord 거부) 단언은 SC-003 의도된 동작변경으로 obsolete. discord 는 이제 지원 채널 → (1) `add --channel discord: not refused as unsupported (SC-003)`(UNSUPPORTED 메시지 미출력 단언) + (2) `add --channel <unimplemented>: refused`(미구현 채널 `fakechat` 이 여전히 UNSUPPORTED·미등록·미scaffold)로 갱신. UNSUPPORTED 게이트가 제거된 게 아니라 discord 만 통과함을 양방향 검증.
- **GAP-002**: `lib/commands.sh` 는 baseCommit 시점부터 process substitution(`done < <(...)`, L340)을 포함 — `bash --posix -n` 불가(본 변경 무관·사전 존재). static.bats 의 SC-021 검증을 분리: `--posix -n` 대상은 channels.sh·en.sh·ko.sh·cctg.bash 4파일, commands.sh 는 `bash -n`(non-posix)으로 검증.

---

## 외부 의존성 명시

- **jq**: SC-009~011/019/025~027/030~032 의 access.json 단언에 필요(테스트 머신에 설치 전제). SC-020 은 jq 를 의도적으로 PATH 에서 가린 jq-less 환경에서 실행.
- **bats**: 테스트 러너(bats-core).
- **test_helper.bash 격리**: HOME/XDG/CC_CHANNELS_DIR 를 `$BATS_TEST_TMPDIR` 하위로 격리, `tests/stubs/tmux` fake tmux 를 PATH 선두에 둔다. 실제 ~/.claude/channels 비접촉.
- **jq-less PATH 헬퍼(status_view.bats `make_jqless_path`)**: 필요 도구(awk/sed/grep/cut/tr/stat/date 등)를 임시 bin 에 symlink 하고 `/usr/bin`(jq 위치)을 PATH 에서 제외하여 jq 부재 시뮬레이션. discord 봇 시드는 jq 가 있는 상태에서 수행(heredoc 경로 — jq 불요).
- **토큰 비노출**: 모든 add 호출은 `--token-env`/`--token-stdin`(argv 미노출, NFR-002).
- **discord no-id 케이스**: `seed_bot` 헬퍼(`--id 555` 주입)를 쓸 수 없어 `add ... --channel discord --token-env`/`--token-stdin` 직접 호출.

---

## 미커버 항목 (사전 분류 — 4-카테고리)

> 5b coverage-gap.md 작성 참조용. 본 spec 의 SC-001~032 는 모두 unit/static 으로 커버됨(미커버 SC 0건).
> 아래는 spec "범위 외"·"사후 운영 검증 피드백 사이클" 항목으로, SC 가 아니므로 게이트 미커버가 아니다.

| 항목 | 미커버 사유 | 카테고리 | 권장 검증 방법 |
|---|---|---|---|
| Discord DM 첫 메시지 페어링 코드 발급 | 실제 Discord Gateway·봇 토큰·서버 필요 | (3) 운영 환경 권장 | 사용자 운영 시나리오 수동 검증 (spec 사후 피드백 사이클) |
| `/discord:access pair <code>` 승인 후 DM 응답 | 동일 — 플러그인 런타임 소유 | (3) 운영 환경 권장 | 운영 수동 검증 |
| 서버채널 @멘션 트리거(requireMention 실효성) | 실제 서버·멤버 필요 | (3) 운영 환경 권장 | 운영 수동 검증 |
| imessage/fakechat 실제 채널 활성화 | descriptor 확장만 — 활성화는 범위 외 | (4) 차후 점검 | 별도 후속 spec |

- 카테고리 (1) 단위테스트 가능·미작성: **0건** (모든 unit-검증 가능 SC 작성 완료).
- 카테고리 (2)(3)(4) 만 존재 → Docs Agent 진행 가능 조건 충족(5b 에서 확정).
