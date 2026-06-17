---
작성: Design Agent
버전: v1.0
최종 수정: 2026-06-17 15:26
상태: 확정
---

# Research: discord-channel-support

## 목차

- [기존 코드베이스 분석](#기존-코드베이스-분석)
  - [클래스·모듈 계층 구조](#클래스모듈-계층-구조)
  - [영향 범위 분석 (호출 측 전수 목록)](#영향-범위-분석-호출-측-전수-목록)
  - [공유 상태·동시성 분석](#공유-상태동시성-분석)
- [외부 라이브러리 API 실제 동작 확인](#외부-라이브러리-api-실제-동작-확인)
- [ADR-003~006 코드 근거 확정](#adr-003006-코드-근거-확정)
- [인정되는 한계 및 안전망 (PATCH-A07)](#인정되는-한계-및-안전망-patch-a07)
- [배포 환경 영향 추정 (PATCH-A10)](#배포-환경-영향-추정-patch-a10)
- [context.md 부정합 사전 점검 (PATCH-A11)](#contextmd-부정합-사전-점검-patch-a11)
- [doctrine·제약 대조 (pipeline-quality §7.1)](#doctrine제약-대조-pipeline-quality-71)
- [completeness critic (pipeline-quality §7.2)](#completeness-critic-pipeline-quality-72)
- [최적 설계 재검토 (PATCH-A15)](#최적-설계-재검토-patch-a15)
- [DEC-001 문법 확정 반영](#dec-001-문법-확정-반영)
- [기술 선택 조사](#기술-선택-조사)
- [엣지 케이스 및 한계](#엣지-케이스-및-한계)

> 전체 프로젝트 구조는 context.md §2 참조. 본 문서는 변경 대상 모듈에 한정한다.

---

## 기존 코드베이스 분석

### 클래스·모듈 계층 구조

셸 프로젝트(Bash 3.2)이므로 클래스 계층이 아닌 **모듈(`lib/*.sh`) + 진입점(`cc-tg.sh`) source 구조**다. 변경 대상 모듈:

| 모듈 | 변경 함수/변수 | 비고 |
|---|---|---|
| `lib/channels.sh` | `IMPLEMENTED_CHANNELS`(변수), `channel_spec()`(case) | descriptor SSOT. `channel_of`/`valid_channel`/`DEFAULT_CHANNEL` 은 불변 |
| `lib/commands.sh` | `cmd_add()`, `cmd_status()` | `status_json()` 는 이미 `channel` 필드 출력(L365·L371) — 본 spec 변경 불요 |
| `messages/en.sh`·`messages/ko.sh` | 4개 키 치환 + 신규 키 | 키 패리티(scripts/check-i18n-keys.sh) |
| `completions/_cctg`·`completions/cctg.bash` | `--channel` 후보·`--group` 후보 | lib 미source(자체 awk 만) |

`channel_spec()` 는 `case "$1:$2"` 단일 디스패치(channels.sh L15~28). 신규 필드 추가 = case arm 추가만으로 완결(ADR-001) — 호출 계약 불변, 상속/오버라이드 개념 없음.

### 영향 범위 분석 (호출 측 전수 목록)

`channel_spec` 호출 측 grep 결과 — 신규 4필드를 호출하는 곳과 기존 4필드만 쓰는 곳 구분:

| 파일:라인 | 호출 | 본 spec 변경 |
|---|---|---|
| `lib/session.sh:83` | `channel_spec "$ch" statedir_env` | 불변(기존 필드, up_one) |
| `lib/session.sh:84` | `channel_spec "$ch" plugin` | 불변(기존 필드, up_one) |
| `lib/commands.sh:61` | `channel_spec "$CH" token_key` | 불변(기존 필드, .env 키) |
| `lib/commands.sh`(신규) | `channel_spec "$CH" id_required` | **신규** — cmd_add id 분기(FR-003) |
| `lib/commands.sh`(신규) | `channel_spec "$CH" id_label` | **신규** — ADD_PROMPT_TGID 인자(FR-005) |
| `lib/commands.sh`(신규) | `channel_spec "$CH" seed_policy` | **신규** — access.json 시드(FR-004) |
| `lib/commands.sh`(신규, cmd_status) | `channel_spec "$(channel_of "$n")" display` | **신규** — 채널 표시명(FR-007) |

- `channel_of` 호출 측: `cmd_config`(L194, `CFG_SHOW_CHANNEL`)·`status_json`(L365). cmd_status 비JSON 은 현재 channel 미표시 → FR-007 로 추가.
- `status_json()` 는 이미 `ch="$(channel_of "$n")"`(L365) 로 `channel` JSON 필드를 출력 중. discord 활성화 시 자동으로 `"channel":"discord"` 출력 → **추가 변경 불요**. (SC-031 관련 status_json 무영향.)
- `cmd_add` 신규 플래그 `--group`: 기존 파싱 루프(L12~21)에 arm 1개 추가. 미지 플래그는 `ERR_ADD_UNKNOWN_FLAG`(L19) → 메시지에 `--group` 추가(en/ko).
- `IMPLEMENTED_CHANNELS` 참조 측: `valid_channel`(channels.sh L31), `cmd_add` UNSUPPORTED 메시지 인자(L23). 값 변경(`"telegram discord"`)은 두 곳에 자동 반영.

**"현재 호출 안 됨" vs "컴파일/검증 대상" 구분**: 셸은 컴파일 단위 없음. 변경 5파일은 `bash -n`(SC-021)·`bats`(SC-024) 대상에 모두 포함. discord descriptor 활성화는 imessage/fakechat(여전히 비활성·`*) return 1`)에 영향 없음(ASM-006).

**기존 88 bats 회귀(SC-024) 영향 점검**:
- `tests/channel.bats` — `add`/`status --json`/`config show`/legacy 행 검증. discord 활성화·8필드 추가는 telegram 경로 불변이므로 회귀 없음.
- `tests/add.bats` "access.json is valid JSON seeding the given id into the allowlist"(L25) — 현재 시드에 `"pending":{}` 포함. 본 spec 이 pending 제거(SC-011) → **이 기존 테스트의 단언이 `pending` 존재를 확인하지 않는지 확인 필요**. (아래 점검.)
- `tests/add.bats` "non-interactive without --id is refused"(L77) — telegram(`id_required=yes`) 경로 → SC-008 과 동일, 회귀 없음(분기로 감싸도 telegram 은 die 유지).

> **add.bats L25 단언 점검(PROC-001 representation)**: 해당 테스트가 access.json 의 어떤 속성을 read 하는지 — `jq -r '.allowFrom[0]'` 류로 allowFrom 만 단언하고 `pending` 부재를 단언하지 않으면 pending 제거 후에도 PASS 유지. 단언이 `.pending` 또는 전체 객체 동등 비교를 한다면 회귀. **Test Agent(5b) 가 실행 시 확인**하되, 시드 구조상 allowFrom·dmPolicy 중심 단언이면 회귀 없음으로 예측. 회귀 시 production 불변·테스트 단언 정정으로 처리(SC-011 이 pending 부재를 명시 단언하므로 신규 테스트가 SoT).

### 공유 상태·동시성 분석

- `cmd_add` 는 단일 프로세스·순차 실행. 동시성 공유 자원 없음. 레지스트리 append(`>> "$REGISTRY"`, L105)·파일 쓰기는 동일 프로세스 내 순차.
- ThreadPool/병렬 처리 없음 — §C 동시성 설계 비해당.
- **검증 시점 게이트(ADR-006)**: `--group` 토큰 검증을 레지스트리 등록(L105)·파일 생성(.env L61, access.json) **전**에 전부 수행 → 검증 실패 시 부분 등록 방지(SC-027·SC-032 "등록 안 됨"). 현행 `mkdir -p "$SD/inbox"`(L35) 는 검증 전 실행되나, 기존 add 도 후속 `die`(ERR_EMPTY_TOKEN L47 등) 시 SD 디렉터리가 잔존하는 동작과 정합. 레지스트리 행은 미append 되므로 "등록 안 됨" 단언 충족.

---

## 외부 라이브러리 API 실제 동작 확인

> spec/plan 가정이 discord 플러그인 동작에 의존하는 부분을 venv(plugin cache) 소스로 확인. Planning §외부 라이브러리 동작 검증과 cross-check.

**소스**: `~/.claude/plugins/cache/claude-plugins-official/discord/0.0.4/server.ts`

| 가정(spec/plan) | 실제 동작(소스 인용) | 일치 |
|---|---|---|
| ASM-003: 시드에서 `pending` 제거해도 무방 | `readAccessFile()` L156~159: `pending: parsed.pending ?? {}` — 부재 시 `{}` 보정. `defaultAccess()` L125·L128: `dmPolicy:'pairing'`, `pending:{}`. ENOENT 시 L167 `defaultAccess()` 반환 | O |
| FR-002 discord statedir_env=`DISCORD_STATE_DIR` | L37 `process.env.DISCORD_STATE_DIR ?? .../channels/discord` | O |
| FR-002 discord token_key=`DISCORD_BOT_TOKEN` | L53 `process.env.DISCORD_BOT_TOKEN` (부재 시 L58 에러) | O |
| FR-002 discord seed_policy=`pairing`(dmPolicy 기본) | L125 `defaultAccess().dmPolicy:'pairing'` | O |
| FR-008 `groups["<id>"]={requireMention,allowFrom}` 스키마 | L100~103 `GroupPolicy={requireMention:boolean; allowFrom:string[]}`, L109 `groups:Record<string,GroupPolicy>` | O |
| FR-008 requireMention 기본 true·allowFrom 기본 [] | L285~286 `groupAllowFrom = policy.allowFrom ?? []`, `requireMention = policy.requireMention ?? true` (게이트 평가 시점) | O — 시드에 명시 설정해도 동일, 미설정 시 플러그인 기본과 일치 |

- **dmPolicy=allowlist + DM**: L248 `if (access.dmPolicy === 'allowlist') return { action: 'drop' }` (allowFrom 미포함 발신자) — `--id` 제공 시 allowlist+allowFrom 시드(SC-010)가 정확.
- **결론**: spec/plan 의 모든 access.json 시드 가정이 플러그인 실제 로드 경로와 일치. BLOCKED 사유 없음.

> public API 우선(PATCH-A14)/private API lifecycle(PROC-013): 본 spec 은 외부 라이브러리의 **함수 API 호출이 아니라 파일 포맷(access.json) 계약**에 의존. private `_` API 사용 없음 → PROC-013 4시나리오 비해당.

---

## ADR-003~006 코드 근거 확정

> plan.md ADR 중 "Design 확정" 또는 코드 근거 필요 항목을 실제 소스로 확정.

### ADR-003 — 완성 스크립트 `--channel` 동적화 방식 (확정)

**코드 근거**: `completions/cctg.bash` 와 `completions/_cctg` 는 **lib 를 source 하지 않는다**. 두 파일 모두 레지스트리만 awk 로 직접 읽는다(`reg="${CC_TG_REGISTRY:-...projects.conf}"` — cctg.bash L10, _cctg L27). `IMPLEMENTED_CHANNELS` 변수는 `lib/channels.sh` L11 에만 존재하며 완성 파일 런타임 스코프에 없다.

- 후보 a(설치된 lib 경로에서 값 추출): 완성 파일이 cctg 바이너리/libexec 경로를 역추적해 `channels.sh` 를 source — 설치 모드(copy/link)·`BINDIR` 변동으로 경로 불안정, 완성 로드마다 source 비용. **기각**.
- 후보 b(완성 파일 자체 목록 + 동기화): 완성 파일 내 로컬 변수 `channels="telegram discord"` 선언 후 후보 생성. SSOT 는 channels.sh 이나 완성은 정적 미러. **채택**.

**확정 결정**: 후보 b — 각 완성 파일 상단에 로컬 변수로 채널 목록을 두고 `--channel` 후보 생성에 사용한다. SC-016/017 문구("`telegram` 하드코딩 대신 `IMPLEMENTED_CHANNELS` 변수 참조 또는 **동적 목록**")는 변수 미러를 허용. 정적 목록도 SC 통과 가능하나, "telegram 하드코딩 단일 리터럴 제거 + 명시적 채널 목록 변수화" 로 의도(채널 추가 시 한 곳 수정)를 반영한다.

```sh
# completions/cctg.bash — --channel arm (개념)
--channel) COMPREPLY=( $(compgen -W "$CCTG_COMPLETION_CHANNELS" -- "$cur") ) ;;
# 파일 상단: CCTG_COMPLETION_CHANNELS="telegram discord"  (channels.sh IMPLEMENTED_CHANNELS 미러)
```

```zsh
# completions/_cctg — --channel arm (개념)
--channel)   compadd -- ${=CCTG_COMPLETION_CHANNELS} ;;
# 파일 상단(함수 내): local CCTG_COMPLETION_CHANNELS="telegram discord"
```

> 동기화 주석: 완성 파일에 "channels.sh IMPLEMENTED_CHANNELS 미러 — 채널 추가 시 함께 갱신" 비자명 이유 주석 1줄(부재-공지 아님). SC-016/017 단언은 `telegram` 단독 리터럴이 `--channel` 후보로 직접 쓰이지 않음을 검증.

### ADR-004 — discord pairing 경로 완료 메시지 (확정)

**코드 근거**: 현행 `cmd_add` L108 `t ADD_DONE_ALLOWLIST "$TGID"` → 메시지 `"seeded %s into the allowlist (no pairing needed)"`(en.sh L53). discord `--id` 미제공(pairing) 경로는 allowFrom 이 비고 페어링이 필요하므로 이 문구가 **부정확**(no pairing needed 가 거짓).

**확정 결정**: 완료 안내를 시드 정책(`policy` 변수 = 최종 dmPolicy)으로 분기.
- `policy=allowlist`(telegram 항상 / discord --id 제공): 기존 `ADD_DONE_ALLOWLIST "$TGID"` 유지.
- `policy=pairing`(discord --id 미제공): 신규 키 `ADD_DONE_PAIRING`(예: "DM the bot to get a pairing code, then approve with /discord:access pair <code>") 출력. `$TGID` 인자 없음.

```sh
if [ "$policy" = allowlist ]; then t ADD_DONE_ALLOWLIST "$TGID"; else t ADD_DONE_PAIRING; fi
```

신규 키 `ADD_DONE_PAIRING` en/ko 동시 추가(키 패리티). FR-004 정확성 보강(SC 직접 없으나 ADD_DONE_NEXT "DM하면 바로 응답" 도 pairing 시 부정확 → 단순화 위해 ADD_DONE_NEXT 는 유지하되 pairing 안내가 선행). `ADD_DONE_NEXT` 변경 여부는 최소 표면 위해 본 spec 에서 미변경(범위 외 — pairing 안내는 ADD_DONE_PAIRING 한 줄로 충분).

### ADR-005 — access.json 시드 구성 도구 (jq 경계, 확정)

**코드 근거**: 현행 `cmd_add` L66~68 은 heredoc 으로 access.json 작성 — **jq 불요**. `need_jq`(util.sh L42)·`jq_inplace`(util.sh L49) 헬퍼는 `cmd_common`(L253~265)·`status_json`(L342) 에서만 사용. `--group` 시드는 가변 키 개수의 JSON 객체 구성이 필요하여 heredoc 안전 구성이 어렵다(키별 중첩 객체·콤마 처리).

**확정 결정**: groups 미지정 경로 = heredoc(jq 불요 보존), `--group` 지정 경로 = jq.
- `--group` 미지정(opt_groups 빈 문자열): heredoc 으로 `{dmPolicy, allowFrom, groups:{}}` 작성. jq 의존 안 함 — 기존 add 의 jq-free 보존(jq 없는 환경에서 일반 add 동작 유지).
- `--group` 지정: `need_jq || exit 1` 가드 후 jq 로 groups 객체 누적·전체 access.json 구성. jq 부재 시 안내 후 exit(기존 `cmd_common` 패턴과 정합). 단, **검증(group/member 숫자)·jq 가드는 레지스트리 등록·파일 생성 전**(ADR-006).

```sh
sp="$(channel_spec "$CH" seed_policy)"
if [ -n "$TGID" ]; then policy=allowlist; else policy="$sp"; fi
# allowFrom: allowlist → ["<id>"], pairing → []
if [ -z "$opt_groups" ]; then
  # heredoc (jq 불요) — allowFrom 은 TGID 숫자 검증분만
  if [ -n "$TGID" ]; then af='["'"$TGID"'"]'; else af='[]'; fi
  printf '{ "dmPolicy": "%s", "allowFrom": %s, "groups": {} }\n' "$policy" "$af" > "$SD/access.json"
else
  need_jq || exit 1   # (실제 가드는 group 파싱 전 — ADR-006)
  # jq 로 groups_json 누적 후 최종 구성
  jq -n --arg dm "$policy" --argjson af "$af" --argjson gr "$groups_json" \
    '{dmPolicy:$dm, allowFrom:$af, groups:$gr}' > "$SD/access.json"
fi
```

> JSON 주입 방어(P-003): heredoc 경로의 `$TGID`·jq 경로의 group id·member id 는 모두 `^[0-9]+$` 검증 통과분만 사용. heredoc 의 숫자 삽입은 주입 위험 없음(현 telegram 시드 L67 과 동일 패턴).

### ADR-006 — group 검증 실패 시 부분 생성 정리 (확정)

**코드 근거**: 현행 `cmd_add` 는 `mkdir -p "$SD/inbox"`(L35) 이후 여러 `die` 경로(ERR_EMPTY_TOKEN L47, ERR_NOT_NUMERIC_ID L58)에서 SD 디렉터리를 정리하지 않고 종료 — 즉 **부분 생성된 SD 잔존은 기존 동작**. 레지스트리 등록(L105)은 함수 말미라 die 시 미append.

**확정 결정**: group 토큰 검증(id·member `^[0-9]+$`)·jq 가드를 **레지스트리 등록 전, 그리고 가능한 한 파일 생성 전 단계**에 배치하여 실패 시 abort. SD 디렉터리 rollback(rm)은 하지 않음 — 기존 add die 동작과 정합(회귀 방지). SC-027/032 단언은 "레지스트리에 mybot 미등록"(`lookup` 실패) 이므로 레지스트리 미append 만으로 충족. SD 디렉터리 잔존은 단언 대상 아님.

- **검증 배치 권장 위치**: 플래그 파싱 직후~`mkdir` 전이 이상적이나, 토큰 입력(stdin)과의 순서상 token 처리 후 access.json 시드 직전에 group 파싱·검증을 모아 수행. 어느 쪽이든 레지스트리 등록(L105) 전이면 SC 충족. tasks.md 는 "access.json 시드 직전 일괄 검증" 으로 시퀀싱(동작보존 increment).

---

## 인정되는 한계 및 안전망 (PATCH-A07)

- **한계**: 위 검증은 access.json **정적 스키마·로드 경로** 한정. 실제 페어링 코드 발급·DM 수신·서버채널 @멘션 트리거는 Discord Gateway 실연결 필요(spec "범위 외" — 통합 테스트 제외). cctg 책임은 시드 JSON 생성까지.
- **안전망**: 모든 시드 경로를 unit 테스트(jq 로 키·값 단언 — SC-009~011, 025~032)로 보장. 런타임 결함은 spec "사후 운영 검증 피드백 사이클"(PROC-014)로 처리. doctor 의 동적 `DOCTOR_PLUGIN_HINT`(FR-005)·status BROKEN(토큰 부재 표면화)이 운영 안내 흡수 — 신규 안전망 불요(기존 메커니즘 충분).

---

## 배포 환경 영향 추정 (PATCH-A10)

- 본 spec 은 로컬 macOS CLI 셸 스크립트 변경. infra.md §1("dev/staging/prod 구분 없음 · 사용자 로컬 macOS 단일 환경")·§8("컨테이너/서버 부재").
- 컨테이너 NAT·docker-proxy·L4 LB·kernel keepalive 등 운영 토폴로지 영향 점검 대상 — **전부 비해당**(서버·컨테이너 부재). discord 플러그인의 Discord Gateway 연결은 플러그인 소유(cctg 비관여).
- 배포 = `install.sh` 재실행(셸 스크립트 복사) + GitHub Release(서버측 자동). 본 변경은 신규 파일 0·스키마 불변 → 설치 영향 없음(완성 파일 갱신은 `cctg update` 재복사로 반영, infra.md §3).
- **critical 영향 없음.** infra.md 갱신 필요 항목: §8 "단일 게이트웨이(Telegram 하드코딩)" 제약이 본 spec 으로 부분 해소 → 6단계 Docs Agent 가 갱신 판단(아래 §context.md 부정합 점검과 동일 위임).

---

## context.md 부정합 사전 점검 (PATCH-A11)

변경 대상(IMPLEMENTED_CHANNELS / channel descriptor / access.json 스키마)을 context.md 에서 grep:

| context.md 항목 | 현재 정의 | 본 spec 변경 후 | 부정합 |
|---|---|---|---|
| §1 주요 기술 스택 | "Telegram 채널 플러그인" | Telegram + Discord 플러그인 | 갱신 권장 |
| §2 (채널 모듈 비고) | — | discord 활성화 | 영향 미미 |
| §3.4 외부 시스템 연동 | "Claude Code CLI: `--channels plugin:telegram@...`", "Telegram 채널 플러그인" | discord 채널도 동일 배선 | 갱신 권장 |
| §5 channel descriptor | "plugin/statedir_env/token_key/..." | 8필드(+display/id_label/id_required/seed_policy) | **부정합** — 4필드→8필드 |
| §5 registry | "name\|cwd\|state_dir\|channel; 3컬럼 레거시=telegram" | 불변 | 정합 |
| §6 알려진 제약 "구현 채널 telegram 한정" | "실제 구현·검증된 채널은 telegram 뿐" | discord 추가 | **부정합** — 제약 해소 |

- **부정합 항목**: §5 channel descriptor(4→8필드), §6 "구현 채널 telegram 한정"(discord 활성화로 부분 해소).
- 본 절은 6단계 Docs Agent 가 PATCH-A10 컨텍스트 검토로 context.md §5·§6·§1·§3.4 갱신하도록 가시화. (Design Agent 는 context.md 직접 갱신 금지 — gaps.md 대신 본 절로 위임 표시. 신규 GAP 등록은 미해결 공백이 아니라 "문서 갱신 예상"이므로 gaps.md GAP 미등록, 본 절이 트래킹.)

---

## doctrine·제약 대조 (pipeline-quality §7.1)

- **doctrine 문서 대조**: constitution.md P-001(Bash 3.2·연관배열 금지)·P-002(예약 이름 보호)·P-003(시크릿 비노출)·P-005(최소 표면·하위호환) — 설계 전반 준수. CONTRIBUTING.md "churn-only/미문서화 별칭 지양" — `--group` 1개 추가는 핵심 시나리오 필수(NFR-004 정당화).
- **런타임/환경 제약**: 언어=Bash 3.2(macOS 기본), 도구=jq(선택). 연관배열 미사용 — `opt_groups` 스칼라 누적(구분자 split), group 파싱 로컬 변수 완결. jq 부재 시 graceful(status) / 안내 후 exit(--group). `bash --posix -n`(SC-021) 통과 설계. 빌드/패키징 = 순수 셸 복사(install.sh) — 빌드 단계 없음.
- 대조 결과: 제약 위반 없음.

## completeness critic (pipeline-quality §7.2)

- **backlog/TODO 상호작용**: docs/TODO 의 "다중 게이트웨이" 항목과 정합(discord 활성화는 그 계열). 충돌 없음.
- **decisions.md 모순**: DEC-001(컴파운드 토큰) — 설계 전면 반영, 모순 없음.
- **미검증 가정(ASM)**: ASM-001/002(플러그인 설치·토큰 발급)는 런타임 의존(add 시점 불요) — 안전망(PATCH-A07)으로 흡수. ASM-003/004(pending 제거)·ASM-005(id 분기)·ASM-006(미구현 채널 return 1)는 코드/소스로 확정.
- **doctrine 일관성**: 일관.
- **누락 점검**: status_json 이 이미 channel 출력(추가 변경 불요) 식별 → tasks 에서 status_json 제외 명시. 신규 에러 키(ERR_ADD_BAD_GROUP_ID/MEMBER)·완료 키(ADD_DONE_PAIRING) 키 패리티 누락 위험 → tasks B/D 에 i18n 동시 변경·check-i18n-keys 게이트 명시. 의도적 컷 없음(scope.md 불요).

---

## 최적 설계 재검토 (PATCH-A15)

D2 tasks 분해 후 구조·로직 차원 재검토:

- **효율성/§E 동일 가드 통합**: dmPolicy·allowFrom 결정을 단일 분기(`if [ -n "$TGID" ]`)에서 함께 산출(policy·af 동시 결정) — 동일 가드 중복 평가 제거. seed_policy 조회는 1회(`sp` 캐시).
- **성능**: cmd_add 는 1회성 명령(hot path 아님). 루프는 `--group` 토큰 수(소수)·IMPLEMENTED_CHANNELS 순회(2개). 비용 무시 가능. constitution §3: 성능 측정 NFR 없음.
- **안정성**: 검증 게이트를 등록 전 일괄(ADR-006) — 부분 생성 방지. jq 가드 명시(--group). 자원 정리는 기존 add 동작 정합.
- **구조**: cmd_add 책임이 늘지만(id 분기·seed 분기·group 파싱) 모두 add 의 단일 책임(봇 등록) 내. group 토큰 파싱을 보조 함수(`parse_group_token`)로 분리하면 가독성↑ — tasks 에서 선택 권장(필수 아님, cmd_add 인라인도 SC 충족).
- **로직**: 분기 흐름 단순(id 유무 → policy/af, group 유무 → heredoc/jq).

**결론**: spec 범위 확장·개발 방향 변경 불요. tasks.md 확정 진행. (BLOCKED 사유 없음.)

---

## DEC-001 문법 확정 반영

`decisions.md` DEC-001 — **컴파운드 토큰** `--group <id>[:nomention][:allow=m1,m2,...]` 확정. 본 research·tasks 전체가 이 문법을 SoT 로 한다.

**Bash 3.2 파싱 설계(연관배열 불요)**:
- `--group` arm: `opt_groups="$opt_groups${opt_groups:+$GROUP_SEP}$2"` — 단일 스칼라에 구분자 누적(`GROUP_SEP` = 개행 또는 특수 비숫자 문자). 복수 `--group` 도 스칼라 누적.
- 토큰 split: 각 토큰을 `IFS` 또는 파라미터 확장으로 `:` 분해. 첫 필드=id, 나머지 필드 중 `nomention`·`allow=...` 매칭.
  - id: `${token%%:*}` → `^[0-9]+$` 검증, 비숫자 → `die ERR_ADD_BAD_GROUP_ID`.
  - 수식어 루프: `:` split 후 각 조각이 `nomention`(→ requireMention=false) / `allow=...`(→ `${mod#allow=}` 콤마 split, 각 멤버 `^[0-9]+$` 검증, 비숫자 → `die ERR_ADD_BAD_GROUP_MEMBER`).
- 누적: jq `--argjson` 으로 `{requireMention,allowFrom}` 객체를 groups 맵에 키(snowflake)로 reduce/병합.

```sh
# 개념 — group_json 누적(jq)
groups_json='{}'
OLDIFS="$IFS"; IFS="$GROUP_SEP"
for tok in $opt_groups; do
  gid="${tok%%:*}"; rest="${tok#"$gid"}"
  printf '%s' "$gid" | grep -qE '^[0-9]+$' || die ERR_ADD_BAD_GROUP_ID "$gid"
  rm_flag=true; allow_csv=""
  IFS=':'; for mod in $rest; do
    [ -z "$mod" ] && continue
    case "$mod" in
      nomention) rm_flag=false ;;
      allow=*)   allow_csv="${mod#allow=}" ;;
    esac
  done; IFS="$GROUP_SEP"
  # allow_csv 멤버 검증 → allow_json 배열 구성(각 ^[0-9]+$, 실패 시 die ERR_ADD_BAD_GROUP_MEMBER)
  groups_json="$(printf '%s' "$groups_json" | jq --arg id "$gid" --argjson rm "$rm_flag" --argjson af "$allow_json" '. + {($id): {requireMention:$rm, allowFrom:$af}}')"
done
IFS="$OLDIFS"
```

- 위는 설계 개념(정확한 구현은 4단계). NFR-001(연관배열 미사용)·P-003(숫자 검증분만 jq 주입) 준수.

---

## 기술 선택 조사

- **descriptor 8필드 저장(ADR-001)**: 기존 `case "$1:$2"` 확장. 연관배열 대안 기각(Bash 3.2). telegram·discord 각 8 arm = 16 arm.
- **`--group` 문법(ADR-002=DEC-001)**: 컴파운드 토큰. 동반 플래그 대안은 상태추적 필요(연관배열 부재 복잡)·표면 3배 → 기각.
- **시드 도구(ADR-005)**: heredoc/jq 하이브리드. 전체 jq(단순하나 jq-free add 회귀)·전체 heredoc(가변 키 주입 위험) 모두 기각.

---

## 엣지 케이스 및 한계

- **discord `--id` 미제공 + `--group`**: dmPolicy=pairing, groups=지정값. (SC-009 + SC-025 조합 — 독립적으로 충족.)
- **`--group` 미지정**: heredoc 경로, groups={} (SC-028, SC-009/010 갈음).
- **jq 부재 + `--group`**: `need_jq` 안내 후 exit, 미등록(기존 common 패턴). (spec 미명시 엣지 — ADR-005 결정으로 일관 처리.)
- **레거시 3컬럼 행**: `channel_of` → telegram(registry.sh awk $4 빈값→DEFAULT_CHANNEL via channels.sh L41). status 표시명도 Telegram (SC-023, SC-018).
- **한계**: 실제 Discord 런타임 동작은 통합 테스트 범위 외(PATCH-A07). id_label 영문 고정(런타임 언어 무관 — 한국어 라벨은 후속 spec).
