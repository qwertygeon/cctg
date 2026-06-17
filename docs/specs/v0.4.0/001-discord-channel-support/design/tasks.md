---
작성: Design Agent
버전: v1.0
최종 수정: 2026-06-17 15:29
상태: 확정
---

# Tasks: discord-channel-support

> Branch: feature/v0.4.0-001-discord | Date: 2026-06-17 | Plan: [plan.md](../planning/plan.md)

## 목차

- [전제 조건](#전제-조건)
- [태스크 분해 레이어](#태스크-분해-레이어)
- [태스크 목록](#태스크-목록)
- [Test Authoring Contract](#test-authoring-contract)
- [SC → Task 매핑 검증](#sc--task-매핑-검증)
- [태스크 입도 가이드](#태스크-입도-가이드)
- [구현 완료 기준](#구현-완료-기준)

---

## 전제 조건

- [x] spec.md 의 모든 [NEEDS CLARIFICATION] 항목이 해소되었는가? — 0건(spec "미결 사항: 없음").
- [x] plan.md 의 Constitution Gates 가 모두 통과(또는 예외 기재)되었는가? — P-001~P-005 전부 PASS, 예외 0.
- [x] DEC-001(`--group` 컴파운드 토큰 문법)이 decisions.md 에 확정되었는가? — 확정(2026-06-17 15:24).
- [x] CHANGES.md "후속 작업 시 주의사항" 확인 — 버전 폴더 루트에 CHANGES.md 부재(신규 버전 v0.4.0 최초 spec). 해당 없음.

---

## 태스크 분해 레이어

> [P] = 이전 태스크와 병렬 실행 가능. 기본 의존 순서 A → B → C → D.
> 본 프로젝트는 레이어드 아키텍처가 아닌 셸 모듈 구조이므로 레이어를 아래로 재정의한다.

| 레이어 | 본 spec 대상 (재정의) | 의존 방향·근거 |
|---|---|---|
| A. descriptor(데이터 계층) | `lib/channels.sh` — IMPLEMENTED_CHANNELS + 8필드 descriptor | 최하위 SSOT. B/C 가 의존 |
| B. 로직(도메인 계층) | `lib/commands.sh`(cmd_add/cmd_status) + `messages/en.sh`·`messages/ko.sh` | A 의 descriptor 조회. 메시지는 로직 호출부와 동시 변경(인자 시그니처) |
| C. 인터페이스(자동완성) | `completions/_cctg`·`completions/cctg.bash` | A 와 독립(lib 미source, 정적 미러) → A 와 [P] 가능 |
| D. 테스트 계층 | `tests/*.bats` 신규/확장 + 정적 검증(`bash -n`/grep) | A·B·C 산출물 검증. **5a Test Agent(AUTHORING) 책임** |

> A·B·C 레이어 = **4단계 Development Agent** 책임. D 레이어 = **5a Test Agent(AUTHORING)** 책임. 양 Agent 는 PPG-1 으로 동일 turn 병렬 spawn. D 의 테스트는 A/B/C 구현 전 작성(TDD Red) — Test Authoring Contract 가 입력.
> 통합 테스트(실제 Discord API)는 spec "범위 외" — D 레이어는 unit(bats)·static 만. 책임 경계 밖.

---

## 태스크 목록

### Step 1. descriptor 기반 작업 (레이어 A)

- [x] **T001 — IMPLEMENTED_CHANNELS 에 discord 등재 + discord descriptor 8필드 활성화 + telegram 4필드 추가**
  - 레이어: A
  - 구현 파일: `lib/channels.sh`
  - 관련 요구사항: FR-001, FR-002
  - 상세:
    - `IMPLEMENTED_CHANNELS="telegram"` → `"telegram discord"` (L11).
    - `channel_spec()` case 에 telegram 신규 4 arm: `telegram:display)`→`Telegram`, `telegram:id_label)`→`Telegram numeric ID`, `telegram:id_required)`→`yes`, `telegram:seed_policy)`→`allowlist`.
    - discord 주석 해제 + 활성 8 arm: `discord:plugin)`→`plugin:discord@claude-plugins-official`, `discord:statedir_env)`→`DISCORD_STATE_DIR`, `discord:token_key)`→`DISCORD_BOT_TOKEN`, `discord:token_required)`→`yes`, `discord:display)`→`Discord`, `discord:id_label)`→`Discord user snowflake`, `discord:id_required)`→`no`, `discord:seed_policy)`→`pairing`.
    - `*) return 1` 분기 유지(미구현 채널 — ASM-006). 함수 상단 주석의 field 목록 8개로 갱신.
  - 완료 기준: telegram·discord 각 8필드 `channel_spec` 호출 시 rc 0·값 출력. `bash --posix -n lib/channels.sh` 통과. (SC-001/002/004/005/006)

### Step 2. add/status 로직 + 메시지 (레이어 B)

- [x] **T002 — cmd_add: id_required 분기 (FR-003)** [P] (T001 후)
  - 레이어: B
  - 구현 파일: `lib/commands.sh`(cmd_add L50~58 영역)
  - 관련 요구사항: FR-003
  - 상세: 현행 `noninteractive=1 && --id 미제공 → die ERR_ADD_NEED_ID`(L52~53) 를 채널 분기로 감쌈. `id_required=yes`(telegram) → 기존 die 유지. `id_required=no`(discord) → `TGID=""` 로 진행. 숫자 검증(L58)은 `[ -n "$TGID" ]` 일 때만. 대화형 프롬프트는 `t ADD_PROMPT_TGID "$(channel_spec "$CH" id_label)"` 로 라벨 주입(T004 메시지 시그니처와 동기).
  - 완료 기준: discord `--id` 미제공 비대화형 시 ERR_ADD_NEED_ID 미발생·진행. telegram 동일 조건 ERR_ADD_NEED_ID 발생(회귀 없음). (SC-007, SC-008)

- [x] **T003 — cmd_add: --group 플래그 파싱 + 컴파운드 토큰(DEC-001) + seed_policy/dmPolicy 분기 + access.json 시드(pending 제거) (FR-004, FR-008)**
  - 레이어: B
  - 구현 파일: `lib/commands.sh`(cmd_add 파싱 루프 L12~21, access.json 시드 L66~68 영역)
  - 관련 요구사항: FR-004, FR-008, NFR-001, NFR-002(token 불변), P-003
  - 상세:
    - 파싱 루프에 `--group) [ $# -ge 2 ] || die ERR_ADD_FLAG_VALUE "--group"; opt_groups 스칼라 누적(GROUP_SEP); shift 2 ;;`. (research §DEC-001)
    - dmPolicy/allowFrom 결정(§E 통합 분기): `sp=$(channel_spec "$CH" seed_policy)`; `[ -n "$TGID" ]` → `policy=allowlist, af=["<id>"]`; else → `policy=$sp, af=[]`. (telegram 은 T002 로 TGID 항상 존재 → allowlist; discord --id 미제공 → pairing.)
    - 컴파운드 토큰 파싱: 각 토큰 `:` split — id(`^[0-9]+$`, 비숫자→`die ERR_ADD_BAD_GROUP_ID`), `nomention`(requireMention=false, 기본 true), `allow=m1,m2`(각 멤버 `^[0-9]+$`, 비숫자→`die ERR_ADD_BAD_GROUP_MEMBER`, 기본 []). 복수 `--group` 키 누적.
    - **검증 시점(ADR-006)**: group/member 숫자 검증·jq 가드를 레지스트리 등록(L105) 전 수행 → 실패 시 abort, mybot 미등록.
    - access.json 시드(ADR-005): `--group` 미지정 → heredoc `{dmPolicy,allowFrom,groups:{}}`(jq 불요). 지정 → `need_jq || exit 1` 후 jq 로 groups 객체 누적·전체 구성. **모든 경로에서 `"pending"` 키 미포함**(SC-009/010/011, ASM-003).
    - JSON 주입 방어(P-003): 숫자 검증 통과분만 JSON 주입.
  - 완료 기준: 각 시드 경로 access.json 이 jq 로 단언 가능한 구조(pending 부재). group 비숫자 id/member 시 비0 exit·미등록. (SC-009/010/011/025/026/027/030/031/032)

- [x] **T004 — messages: telegram 하드코딩 제거 + 신규 키 (FR-005, ADR-004) + ERR_ADD_UNKNOWN_FLAG/신규 에러 키** [P] (T002/T003 호출부와 동기)
  - 레이어: B
  - 구현 파일: `messages/en.sh`, `messages/ko.sh`
  - 관련 요구사항: FR-005, FR-004(ADR-004), FR-008(에러 키)
  - 상세:
    - `ADD_PROMPT_TGID`: `"Your numeric Telegram ID (DM @userinfobot...)"` → `"Your %s: "`(id_label 주입). telegram/userinfobot 제거. (SC-012)
    - `STATUS_GLOBAL`: `"...%s/telegram..."` → `/telegram` 제거(채널 일반화 문구). (SC-013)
    - `STATUS_HINT_NO_TOKEN`: `"...TELEGRAM_BOT_TOKEN= ..."` → token_key 인자(%s) 추가. `TELEGRAM_BOT_TOKEN` 리터럴 제거. (SC-014) — 호출부(cmd_status L329)에 `$(channel_spec ... token_key)` 인자 추가(T005 동기).
    - `DOCTOR_PLUGIN_HINT`: `"telegram 플러그인...telegram@claude-plugins-official"` → IMPLEMENTED_CHANNELS 기반 동적 또는 일반화 문구. telegram 특정 제거. (SC-015) — 호출부(cmd_doctor L509) 인자/일반화.
    - 신규 키: `ADD_DONE_PAIRING`(ADR-004 — pairing 경로 완료 안내), `ERR_ADD_BAD_GROUP_ID`, `ERR_ADD_BAD_GROUP_MEMBER`. `ERR_ADD_UNKNOWN_FLAG` 메시지에 `--group` 추가.
    - 신규 status 채널 키(T005 와 공유): `STATUS_CHANNEL`, `STATUS_CHANNEL_TOPO`.
    - en.sh ↔ ko.sh 키 패리티 유지(`scripts/check-i18n-keys.sh` 통과).
  - 완료 기준: 4개 키에 telegram 특정 리터럴 부재. 신규 키 en/ko 동시 존재. check-i18n-keys.sh 통과. (SC-012/013/014/015)

- [x] **T005 — cmd_status(비JSON): 채널 표시명 + 토폴로지 (FR-007)**
  - 레이어: B
  - 구현 파일: `lib/commands.sh`(cmd_status L302~338), 메시지 키는 T004
  - 관련 요구사항: FR-007, NFR-005
  - 상세: 각 봇 출력에 `channel_spec "$(channel_of "$n")" display` 표시(`t STATUS_CHANNEL`). jq 있고 access.json 있을 때 `dmPolicy` + `groups` 키 수 파싱하여 `STATUS_CHANNEL_TOPO`(예: `Discord (pairing, 0 groups)`). jq 없거나 access.json 없으면 표시명만(파싱 시도 안 함, 오류 없음 — NFR-005). `STATUS_HINT_NO_TOKEN` 호출에 token_key 인자 추가(T004 동기). status_json 은 이미 channel 출력(변경 불요).
  - 완료 기준: telegram 봇 행 `Telegram`·discord 봇 행 `Discord`. jq 있을 때 `pairing`+`0 groups`. jq 없을 때 오류 없이 표시명만. (SC-018/019/020)

### Step 3. 자동완성 동적화 (레이어 C) — A 와 [P]

- [x] **T006 — completions/cctg.bash: --channel 동적화(ADR-003) + --group 후보 (FR-006, FR-008)** [P] (A 와 독립)
  - 레이어: C
  - 구현 파일: `completions/cctg.bash`
  - 관련 요구사항: FR-006, FR-008(SC-029)
  - 상세: `--channel)` arm 의 `compgen -W "telegram"`(L54) → 파일 상단 로컬 변수 `CCTG_COMPLETION_CHANNELS="telegram discord"`(channels.sh IMPLEMENTED_CHANNELS 미러 — 채널 추가 시 함께 갱신) 참조. add 플래그 후보(L56)에 `--group` 추가. `--group)` prev arm 은 자유 입력(보완 안 함, 컴파운드 토큰).
  - 완료 기준: `--channel` 후보가 telegram 단독 리터럴 아님. add 플래그에 `--group` 포함. `bash --posix -n completions/cctg.bash` 통과. (SC-016, SC-029)

- [x] **T007 — completions/_cctg(zsh): --channel 동적화(ADR-003) + --group 후보 (FR-006, FR-008)** [P]
  - 레이어: C
  - 구현 파일: `completions/_cctg`
  - 관련 요구사항: FR-006, FR-008(SC-029)
  - 상세: `--channel)   compadd -- telegram`(L78) → 로컬 변수 `CCTG_COMPLETION_CHANNELS="telegram discord"` 참조(`compadd -- ${=CCTG_COMPLETION_CHANNELS}`). add 플래그 후보(L80)에 `--group` 추가.
  - 완료 기준: `--channel` 후보가 telegram 단독 리터럴 아님. add 플래그에 `--group` 포함. (SC-017, SC-029)
  - 비고: `_cctg` 는 zsh 전용이라 `bash --posix -n` 검사 대상 아님(SC-021 은 cctg.bash 만). zsh 문법 유지.

### Step 4. 테스트 (레이어 D) — 5a Test Agent(AUTHORING) 책임

- [ ] **T008 — descriptor·add·status·completions·회귀 테스트 작성/확장 (전 SC unit/static)**
  - 레이어: D
  - 테스트 파일: `tests/channel.bats`(8필드·id 분기·시드·status 표시명 확장), `tests/add.bats`(pending 제거·group), 신규 또는 기존 확장 `tests/status_json.bats`(불변 회귀), 정적 검증(`bash -n`/grep — 기존 misc.bats 또는 신규 static.bats)
  - 검증 대상: SC-001~032 전수 (아래 Test Authoring Contract).
  - 상세: 5a Test Agent 가 Test Authoring Contract 표에 따라 작성. unit=bats, static=파일 grep/`bash --posix -n`. 통합(실제 Discord)은 작성 안 함(범위 외). 기존 88 테스트 회귀(SC-024)는 전체 `bats tests/` 실행으로 검증.
  - 완료 기준: SC-001~032 각각에 대응 테스트 존재. TDD Red(A/B/C 미구현 상태에서 신규 테스트 FAIL 확인). 5b 에서 Green.

---

## Test Authoring Contract

> **PPG-1 의 5a 단계 Test Agent (AUTHORING) 입력 contract**. 외부 contract 공급 시 본 표를 충족시킨 산출물 존재를 main 이 확인 후 5b 진입.

| SC-ID | 수용 기준 | 시나리오 유형 | 테스트 파일 경로 | 함수명 후보 / 검증 방법 | env |
|---|---|---|---|---|---|
| SC-001 | IMPLEMENTED_CHANNELS 에 discord | Happy | tests/channel.bats | grep `IMPLEMENTED_CHANNELS=.*discord` lib/channels.sh | static |
| SC-002 | discord descriptor 활성 case | Happy | tests/channel.bats | grep 비주석 `discord:plugin)` 등 | static |
| SC-003 | add --channel discord ≠ UNSUPPORTED | Error→Happy | tests/channel.bats | `add ... --channel discord --token-stdin </dev/null` → ERR_CHANNEL_UNSUPPORTED 미출력 | unit |
| SC-004 | telegram 8필드 존재 | Happy | tests/channel.bats | source channels.sh; `channel_spec telegram <8필드>` rc 0 | unit |
| SC-005 | discord 8필드 존재 | Happy | tests/channel.bats | `channel_spec discord <8필드>` rc 0 | unit |
| SC-006 | discord display/id_required/seed_policy 값 | Happy | tests/channel.bats | `Discord`/`no`/`pairing` 단언 | unit |
| SC-007 | discord --id 없이 비대화형 진행 | Edge | tests/add.bats | `add ... discord --token-env`(유효토큰) `--id` 없이 → ERR_ADD_NEED_ID 미발생, access.json 생성 | unit |
| SC-008 | telegram --id 없이 → ERR_ADD_NEED_ID | Error | tests/add.bats | `add ... telegram --token-env` `--id` 없이 → ERR_ADD_NEED_ID | unit |
| SC-009 | discord --id 미제공 시드 pairing/[]/{}/no-pending | Happy | tests/add.bats | jq `.dmPolicy=="pairing"`,`.allowFrom==[]`,`.groups=={}`,`has("pending")==false` | unit |
| SC-010 | discord --id 제공 시드 allowlist/no-pending | Happy | tests/add.bats | jq `.dmPolicy=="allowlist"`, allowFrom 에 id, `has("pending")==false` | unit |
| SC-011 | telegram 시드 pending 제거 | Happy | tests/add.bats | jq `.dmPolicy=="allowlist"`, allowFrom 에 id, `has("pending")==false` | unit |
| SC-012 | ADD_PROMPT_TGID telegram 문자열 없음 | Happy | (static) misc.bats/static | grep en/ko.sh ADD_PROMPT_TGID 에 "Telegram"/"@userinfobot" 부재 | static |
| SC-013 | STATUS_GLOBAL /telegram 없음 | Happy | (static) | grep en/ko.sh STATUS_GLOBAL 에 `/telegram` 부재 | static |
| SC-014 | STATUS_HINT_NO_TOKEN 하드코딩 없음 | Happy | (static) | grep en/ko.sh STATUS_HINT_NO_TOKEN 에 `TELEGRAM_BOT_TOKEN` 부재 | static |
| SC-015 | DOCTOR_PLUGIN_HINT telegram 특정 없음 | Happy | (static) | grep en/ko.sh 에 `telegram@claude-plugins-official`/"telegram 플러그인" 부재 | static |
| SC-016 | zsh --channel 동적 | Happy | (static) | grep _cctg `--channel` arm 이 telegram 단독 리터럴 아님 | static |
| SC-017 | bash --channel 동적 | Happy | (static) | grep cctg.bash `--channel` arm 이 telegram 단독 리터럴 아님 | static |
| SC-018 | status 채널 표시명 | Happy | tests/channel.bats 또는 status | tg봇+dc봇 등록 후 `status` 출력에 `Telegram`·`Discord` | unit |
| SC-019 | jq 있을 때 토폴로지 | Happy | tests/channel.bats/status | dc봇 access.json pairing/{} → `status` 에 `pairing`+`0 groups` | unit |
| SC-020 | jq 없을 때 degradation | Edge | tests/channel.bats/status | jq 미존재(PATH 격리) + dc봇 → `status` 오류 없음·`Discord` 표시 | unit |
| SC-021 | bash --posix -n 통과 | Happy | (static) | `bash --norc --noprofile --posix -n` on channels.sh/commands.sh/en.sh/ko.sh/cctg.bash | static |
| SC-022 | DISCORD_BOT_TOKEN 저장 | Happy | tests/channel.bats/add | `add ... discord --token-env`(유효) → .env 에 `DISCORD_BOT_TOKEN=` | unit |
| SC-023 | 레거시 3컬럼 → telegram | Edge | tests/channel.bats | registry_raw 3컬럼 행 + `channel_of mybot`==telegram | unit |
| SC-024 | 기존 88 테스트 회귀 0 | Happy(회귀) | (전체) | `bats tests/` 88 PASS(신규로 총수 증가) | unit |
| SC-025 | --group 1회 groups 키 | Happy | tests/add.bats | `--group 846...` → jq `.groups["846..."]=={requireMention:true,allowFrom:[]}` | unit |
| SC-026 | --group 2회 두 키 | Happy | tests/add.bats | `--group A --group B` → groups 에 A·B 키 | unit |
| SC-027 | 비숫자 group id 에러·미등록 | Error | tests/add.bats | `--group abc` → 비0 exit, `lookup mybot` 실패 | unit |
| SC-028 | --group 미지정 groups{} | (갈음) | — | SC-009/010 으로 갈음 | unit |
| SC-029 | 완성에 --group | Happy | (static) | grep _cctg/cctg.bash add 플래그 후보에 `--group` | static |
| SC-030 | nomention → requireMention false | Edge | tests/add.bats | `--group 846...:nomention` → jq `.groups["846..."].requireMention==false` | unit |
| SC-031 | allow → allowFrom 멤버 포함 | Happy | tests/add.bats | `--group 846...:allow=184...,221...` → jq allowFrom 에 둘 | unit |
| SC-032 | allow 비숫자 멤버 에러·미등록 | Error | tests/add.bats | `--group 846...:allow=abc` → 비0 exit, `lookup mybot` 실패 | unit |

> **AUTHORING 사전 점검(PROC-001/PROC-002)**: 기존 add.bats access.json 단언이 pending 부재를 단언하지 않는지 확인(research §회귀 점검). SC-020 jq 부재 시뮬레이션은 PATH 에서 jq 가리기(test_helper 의 stubs 패턴 활용 — fake jq 없는 디렉터리 PATH 구성). seed_bot 헬퍼는 `--token-env BOT_TOKEN --id 555` 사용 — discord `--id` 없는 케이스는 별도 add 호출 필요(seed_bot 미사용).

---

## SC → Task 매핑 검증

> 매핑 누락(Task 없는 SC, SC 없는 Task) 0건.

| SC | Task | | SC | Task |
|---|---|---|---|---|
| SC-001 | T001, T008 | | SC-017 | T007, T008 |
| SC-002 | T001, T008 | | SC-018 | T005, T008 |
| SC-003 | T001, T008 | | SC-019 | T005, T008 |
| SC-004 | T001, T008 | | SC-020 | T005, T008 |
| SC-005 | T001, T008 | | SC-021 | T001/T003/T004/T006, T008 |
| SC-006 | T001, T008 | | SC-022 | T001(token_key), T003, T008 |
| SC-007 | T002, T008 | | SC-023 | (불변 channel_of), T008 |
| SC-008 | T002, T008 | | SC-024 | 전 Task 회귀, T008 |
| SC-009 | T003, T008 | | SC-025 | T003, T008 |
| SC-010 | T003, T008 | | SC-026 | T003, T008 |
| SC-011 | T003, T008 | | SC-027 | T003, T008 |
| SC-012 | T004, T008 | | SC-028 | (SC-009/010 갈음), T008 |
| SC-013 | T004, T008 | | SC-029 | T006, T007, T008 |
| SC-014 | T004, T005, T008 | | SC-030 | T003, T008 |
| SC-015 | T004, T008 | | SC-031 | T003, T008 |
| SC-016 | T006, T008 | | SC-032 | T003, T008 |

- 모든 SC-001~032 가 1개 이상 Task 에 매핑. Task 없는 SC 0.
- 모든 Task(T001~T008)가 1개 이상 SC 에 매핑. SC 없는 Task 0.
- FR-001(T001)·FR-002(T001)·FR-003(T002)·FR-004(T003)·FR-005(T004)·FR-006(T006/T007)·FR-007(T005)·FR-008(T003/T006/T007) 전수 매핑. NFR-001~005 는 해당 SC(SC-021/022/023/024/020)·설계 제약으로 흡수.

---

## 태스크 입도 가이드

- T001~T007 은 각 1~2 파일·동작보존 increment. T003 이 가장 큼(파싱+분기+시드) — 단일 함수(cmd_add) 내 응집이라 분할하지 않음(group 토큰 파싱을 보조 함수로 추출은 선택, research §최적성).
- T004(messages)는 T002/T003/T005 호출부 시그니처와 동기 — 같은 4단계 turn 내 일관 적용.
- 동작보존: 각 Task 후 `bats tests/`(기존 88) 회귀 0 유지 권장(SC-024).

## 구현 완료 기준

- [ ] T001~T007 체크박스 완료(4단계 Development), T008 완료(5a Test AUTHORING → 5b EXECUTION Green).
- [ ] 변경 셸 파일 `bash --norc --noprofile --posix -n` 통과(SC-021): channels.sh, commands.sh, en.sh, ko.sh, cctg.bash. (_cctg 는 zsh 전용 — 제외.)
- [ ] `scripts/check-i18n-keys.sh` 통과(키 패리티 + 참조 키).
- [ ] `bats tests/` 전체 PASS(기존 88 + 신규 — SC-024 회귀 0).
- [ ] `git status` 의도치 않은 파일 없음(신규 파일 0 — 기존 파일 수정만).
