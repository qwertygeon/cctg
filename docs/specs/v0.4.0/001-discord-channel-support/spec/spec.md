---
작성: Spec Agent
버전: v1.2
최종 수정: 2026-06-17
상태: 확정
---

# Spec: discord-channel-support

## 목차

- [배경 및 목적](#배경-및-목적)
- [사용자 스토리](#사용자-스토리)
- [기능 요구사항](#기능-요구사항)
- [비기능 요구사항](#비기능-요구사항)
- [수용 기준](#수용-기준)
- [요구사항 구조화 매트릭스](#요구사항-구조화-매트릭스)
- [범위 외](#범위-외)
- [미결 사항](#미결-사항)

> Branch: feature/v0.4.0-001-discord | Date: 2026-06-17 | Version: v0.4.0

---

## 배경 및 목적

v0.3.0(002-multi-gateway)에서 채널 추상화 골격(descriptor + 레지스트리 `channel` 컬럼 + `add --channel` 플래그)이 도입됐으나, 실제 구현·검증된 채널은 `telegram` 뿐이다. `IMPLEMENTED_CHANNELS="telegram"`으로 고정되어 있으며, 코드베이스 여러 곳에 telegram 특정 문자열이 하드코딩되어 있다.

본 spec의 목적:

1. **Discord 활성화**: `channels.sh`의 discord descriptor 주석을 해제하고 `IMPLEMENTED_CHANNELS`에 등록하여, 기존 배선(up/add/down/logs/status) 변경 없이 Discord 봇을 기동할 수 있도록 한다.
2. **descriptor SSOT화**: 사람 노출 메타(display, id_label), 채널별 add 분기(id_required, seed_policy) 필드를 descriptor에 추가하여, 채널 추가 = `channel_spec` case 블록 1개 + `IMPLEMENTED_CHANNELS` 1줄로 완결되는 구조를 실현한다.
3. **telegram 하드코딩 제거**: 메시지 카탈로그·자동완성의 telegram 특정 문자열을 descriptor 경유로 치환한다.
4. **status 채널 표시**: 사람용 `cctg status`에 봇별 채널(게이트웨이)과 연결 토폴로지를 표시한다.
5. **Discord DM/서버채널 접근 모델 대응**: Discord의 `dmPolicy=pairing` 기본값과 서버채널(groups) 구조를 `add` 흐름과 올바르게 연결하고, telegram 잔재(`"pending":{}`)를 제거한다.

---

## 사용자 스토리

US-001: macOS 개발자로서, Discord 채널 봇을 `cctg add --channel discord`로 등록하고 `cctg up`으로 기동하여 Discord DM 또는 서버채널(봇을 추가한 서버의 특정 채널)을 통해 Claude Code에 접근하고 싶다. 등록 시점에 `--group <채널snowflake>`로 서버채널을 사전 시드하여 별도 설정 없이 즉시 운영할 수 있어야 한다.

US-002: macOS 개발자로서, `cctg status`에서 각 봇이 어떤 채널(Telegram/Discord)에 연결돼 있는지 DM 정책과 함께 한눈에 확인하고 싶다.

US-003: macOS 개발자로서, 새 채널을 추가할 때 `channels.sh`의 case 블록 1개와 `IMPLEMENTED_CHANNELS` 1줄만 수정하면 모든 CLI 흐름(add/status/doctor/자동완성)이 자동으로 지원되는 구조를 원한다.

---

## 기능 요구사항

### FR-001: Discord descriptor 활성화

`lib/channels.sh`의 discord descriptor 주석을 해제하고 `IMPLEMENTED_CHANNELS`에 `discord`를 등재한다. 활성화 후 `add --channel discord`, `up`, `down`, `logs`, `status --json`이 기존 telegram과 동등하게 동작한다.

### FR-002: descriptor 확장 — 4필드 → 8필드

`channel_spec` case 블록에 4개 필드를 추가한다. 모든 구현 채널이 8개 필드를 제공해야 한다.

| 필드 | telegram 값 | discord 값 | 역할 |
|---|---|---|---|
| `display` | `Telegram` | `Discord` | 사람 노출 표시명 |
| `id_label` | `Telegram numeric ID` | `Discord user snowflake` | `add` 시 ID 입력 프롬프트 라벨 |
| `id_required` | `yes` | `no` | `--id` 필수/선택 여부 |
| `seed_policy` | `allowlist` | `pairing` | `add` 시 `access.json`의 `dmPolicy` 기본값 |

기존 4필드(plugin, statedir_env, token_key, token_required)는 변경 없이 유지한다.

### FR-003: `add` 흐름 채널 분기 — id_required

`cmd_add`가 채널의 `id_required` 필드를 읽어 `--id` 처리를 분기한다.

- `id_required=yes`(telegram): 기존 동작 유지 — 비대화형 시 `--id` 필수, 대화형 시 ID 프롬프트 표시.
- `id_required=no`(discord): `--id` 없이도 `add` 진행 가능. `--id` 제공 시 ID를 allowFrom에 포함시킨다.

ID 프롬프트 문구는 `id_label` 필드에서 가져온다.

### FR-004: `add` 흐름 채널 분기 — access.json 시드

`cmd_add`가 채널의 `seed_policy` 필드에 따라 `access.json` 시드를 생성한다. `--group`으로 전달된 채널 snowflake(FR-008)는 모든 채널에서 `groups` 필드에 포함된다.

- `seed_policy=allowlist`(telegram): `{dmPolicy:"allowlist", allowFrom:["<id>"], groups:<groups_map>}` — `--id` 없으면 진입 불가(FR-003에 의해 보장).
- `seed_policy=pairing`(discord, `--id` 미제공): `{dmPolicy:"pairing", allowFrom:[], groups:<groups_map>}` — 첫 DM 시 플러그인이 페어링 코드를 반환, 사용자가 `/discord:access pair <code>`로 승인.
- `seed_policy=pairing`(discord, `--id` 제공): `{dmPolicy:"allowlist", allowFrom:["<id>"], groups:<groups_map>}` — 즉시 허용.

`<groups_map>`은 `--group` 미지정 시 `{}`, 지정 시 각 채널별로 FR-008에서 지정한 requireMention과 allowFrom을 반영한 `{ "<snowflake>": { "requireMention": <bool>, "allowFrom": [...] }, ... }` 형태(세부 속성 및 문법은 FR-008 참조).

`"pending":{}` 필드는 어떤 채널 시드에도 포함하지 않는다. (telegram 기존 시드도 제거.)

`--group` 플래그는 채널 종류와 무관하게 동일한 `groups` 스키마로 시드한다. 본 spec의 1차 대상은 discord이며, telegram 등 다른 채널에 `--group`을 사용해도 동일하게 시드되고 에러를 반환하지 않는다.

### FR-008: `add --group <채널snowflake>` 플래그 — 서버채널 사전 시드 (채널별 세부 속성 포함)

`cmd_add`에 `--group <토큰>` 플래그를 추가한다. 반복 사용 가능하며, 지정한 채널 snowflake 각각을 `access.json`의 `groups`에 시드한다. 채널별로 `requireMention`과 `allowFrom` 두 속성을 시드 시점에 설정할 수 있다.

#### 동작 (WHAT — 확정)

- **requireMention**(bool, 기본 `true`): `false`로 지정 시 해당 채널의 모든 메시지를 @멘션 없이도 처리한다. `access.json`의 `groups["<id>"].requireMention`에 반영.
- **allowFrom**(멤버 snowflake 목록, 기본 `[]` = 전체 멤버 허용): 지정 시 그 멤버만 트리거 가능하다. `access.json`의 `groups["<id>"].allowFrom`에 반영. 멤버 ID는 `^[0-9]+$` 검증.
- **채널 ID 검증**: `^[0-9]+$` 정규식. 비숫자 시 에러 반환하고 등록하지 않는다.
- **복수 지정**: `--group A --group B` → `groups`에 A, B 두 키 모두 포함. 각각 독립적으로 속성 설정 가능.
- **미지정 시**: `groups:{}` (기존 동작 유지).
- **세부옵션 미지정 채널**: `{ "requireMention": true, "allowFrom": [] }` — Discord 기본값과 동일.

#### CLI 문법 — 권장안(DEC-001로 확정)

**권장안: 컴파운드 토큰** `--group <id>[:nomention][:allow=m1,m2,...]`

예시:
- `--group 846209781206941736` → requireMention=true, allowFrom=[]
- `--group 846209781206941736:nomention` → requireMention=false, allowFrom=[]
- `--group 846209781206941736:allow=184695080709324800,221773638772129792` → requireMention=true, allowFrom=[...둘]
- `--group 846209781206941736:nomention:allow=184695080709324800` → requireMention=false, allowFrom=[...]

**권장 근거(Bash 3.2 파싱 용이성)**: 컴파운드 토큰은 하나의 `$2` 인자를 `:` 구분자로 split하여 처리하므로 로컬 변수만으로 완결된다. 반면 동반 플래그(`--nomention`, `--allow`) 방식은 "어느 `--group`에 속하는가"를 추적하는 상태 변수가 필요하여 Bash 3.2에서 연관배열 없이 구현하기 복잡하다.

**확정 시점**: 정확한 문법(컴파운드 토큰 구분자·수식어 명칭)은 2단계 Planning/Design의 결정 체크포인트 DEC-001로 확정한다. 구현 전에 DEC-001이 반드시 기록되어야 한다.

### FR-005: 메시지 카탈로그 — telegram 하드코딩 제거

다음 메시지 키를 descriptor 경유 동적 값으로 치환한다. en.sh와 ko.sh 양쪽 모두 변경.

| 키 | 현재 하드코딩 | 치환 내용 |
|---|---|---|
| `ADD_PROMPT_TGID` | "Your numeric Telegram ID..." | `id_label` 필드값 사용(채널별 라벨) |
| `STATUS_GLOBAL` | "...%s/telegram" | 구현된 전역 채널 목록(`IMPLEMENTED_CHANNELS` 기반) 표시 |
| `STATUS_HINT_NO_TOKEN` | "TELEGRAM_BOT_TOKEN=" | `token_key` 필드값으로 치환 |
| `DOCTOR_PLUGIN_HINT` | "telegram 플러그인은 전역 설치 필요" | 구현 채널 전체 플러그인 안내 |

### FR-006: 자동완성 — `--channel` 후보 동적화

`completions/_cctg`(zsh)와 `completions/cctg.bash`(bash)의 `--channel` 후보가 `IMPLEMENTED_CHANNELS` 변수 기반으로 생성된다. 현재 `telegram` 하드코딩을 제거한다.

### FR-007: 사람용 `status`에 채널 + 연결 토폴로지 표시

`cmd_status`(비JSON)가 봇별로 채널 표시명(display)과 연결 토폴로지를 출력한다.

- **채널 표시명**: `channel_spec "$CH" display` 조회 결과(Telegram/Discord).
- **연결 토폴로지(jq 있을 때)**: `access.json`을 파싱하여 `dmPolicy` + `groups` 수를 표시. 예: `channel=Discord (pairing, 0 groups)` 또는 `channel=Discord (allowlist, 2 groups)`.
- **jq 없을 때**: 채널 표시명만 표시(graceful degradation).
- **access.json 없을 때**: 채널 표시명만 표시(파일 부재 시 별도 오류 미발생).

---

## 비기능 요구사항

### NFR-001: Bash 3.2 호환 유지

모든 변경사항은 macOS 기본 Bash 3.2에서 동작해야 한다. 연관배열, `[[ ]]` 확장 문법, Bash 4+ 전용 기능을 도입하지 않는다. descriptor 필드 추가는 기존 case 기반 구조를 유지한다.

### NFR-002: 시크릿 비노출

`DISCORD_BOT_TOKEN`은 `.env` 파일에만 저장되며 argv, 프로세스 목록, 로그에 노출되지 않는다. add 흐름은 기존 `--token-env`/`--token-stdin`/대화형 패턴을 그대로 사용한다.

### NFR-003: 하위호환 — 레거시 레지스트리

레지스트리(`projects.conf`) 기존 행(4번째 컬럼 없는 telegram 봇)은 `channel_of` 함수가 `DEFAULT_CHANNEL=telegram`으로 처리하여 기존 동작을 유지한다. 레지스트리 스키마 변경 없음.

### NFR-004: 최소 표면 — 새 옵션 최소화

본 spec에서 추가되는 새 CLI 플래그는 `--group`(FR-008) 1개이다. 세부 속성(requireMention, allowFrom)은 컴파운드 토큰 수식어(`--group <id>[:nomention][:allow=...]`)로 표현하므로 플래그 수는 1개를 유지한다(DEC-001로 확정 전이지만, 어떤 문법을 채택하더라도 플래그 1개 이내를 유지하는 것이 제약이다).

정당성: 사용자 핵심 시나리오인 "봇 생성 시 추가한 서버의 특정 채널 연동 및 응답 정책 설정"을 `add` 한 번에 구성하기 위해 필수적이며, 없을 경우 봇 기동 후 `/discord:access group add` 스킬을 별도로 실행해야 한다. `--channel`은 이미 존재. descriptor 필드 확장, 메시지 치환, 자동완성 동적화는 내부 구현 변경이다. `--group` 외 표면 증가는 없다.

### NFR-005: jq 없는 환경에서 degradation

FR-007의 access.json 파싱은 jq에 의존한다. jq 없는 환경에서 `cctg status`는 채널 표시명만 출력하고, 토폴로지 파싱을 시도하지 않는다. 기존 doctor 경고(`DOCTOR_WARN_JQ`)는 유지.

---

## 수용 기준

> **환경 태그 규약**: 모든 SC-XXX 끝에 검증 환경 태그를 명시한다.
> `[env:static]` = 코드·파일 존재·구조 검증 / `[env:unit]` = bats 테스트 / `[env:integration]` = 실제 봇 기동 필요

### SC-001 (FR-001 관련): IMPLEMENTED_CHANNELS에 discord 등재

**Given** `lib/channels.sh`를 읽었을 때,
**When** `IMPLEMENTED_CHANNELS` 변수 값을 확인하면,
**Then** 값에 `discord`가 포함되어 있다(예: `"telegram discord"`).

[env:static]

---

### SC-002 (FR-001 관련): discord descriptor case 블록 활성화

**Given** `lib/channels.sh`를 읽었을 때,
**When** `discord:plugin`, `discord:statedir_env`, `discord:token_key`, `discord:token_required` 패턴을 검색하면,
**Then** 주석 처리 없이 활성 case 블록으로 존재한다.

[env:static]

---

### SC-003 (FR-001 관련): `cctg add --channel discord`가 ERR_CHANNEL_UNSUPPORTED를 반환하지 않음

**Given** `cctg add mybot /tmp --channel discord --token-stdin < /dev/null`을 실행했을 때,
**When** 에러 코드를 확인하면,
**Then** `ERR_CHANNEL_UNSUPPORTED` 메시지가 출력되지 않는다(토큰 빈 값으로 인한 ERR_EMPTY_TOKEN 또는 다음 단계 진입은 허용).

[env:unit]

---

### SC-004 (FR-002 관련): 8개 필드 모두 telegram에 존재

**Given** `lib/channels.sh`를 읽었을 때,
**When** `channel_spec telegram <field>`를 각각 호출하면(`plugin`, `statedir_env`, `token_key`, `token_required`, `display`, `id_label`, `id_required`, `seed_policy`),
**Then** 8개 필드 모두 비-0 반환 코드로 값을 출력한다.

[env:unit]

---

### SC-005 (FR-002 관련): 8개 필드 모두 discord에 존재

**Given** `lib/channels.sh`를 읽었을 때,
**When** `channel_spec discord <field>`를 각각 호출하면(SC-004와 동일 8개 필드),
**Then** 8개 필드 모두 비-0 반환 코드로 값을 출력한다.

[env:unit]

---

### SC-006 (FR-002 관련): discord display = "Discord", id_required = "no", seed_policy = "pairing"

**Given** discord descriptor가 활성화된 상태에서,
**When** `channel_spec discord display`, `channel_spec discord id_required`, `channel_spec discord seed_policy`를 호출하면,
**Then** 각각 `Discord`, `no`, `pairing`을 출력한다.

[env:unit]

---

### SC-007 (FR-003 관련): discord add — `--id` 없이 비대화형 진행 가능

**Given** `cctg add mybot /tmp --channel discord --token-stdin`을 실행할 때 (stdin에 유효한 토큰 입력),
**When** `--id` 플래그 없이 실행하면,
**Then** `ERR_ADD_NEED_ID` 에러가 발생하지 않고 add 흐름이 다음 단계(access.json 생성)로 진행된다.

[env:unit]

---

### SC-008 (FR-003 관련): telegram add — `--id` 없이 비대화형 시 ERR_ADD_NEED_ID

**Given** `cctg add mybot /tmp --channel telegram --token-stdin`을 실행할 때 (stdin에 유효한 토큰 입력),
**When** `--id` 플래그 없이 실행하면,
**Then** `ERR_ADD_NEED_ID` 에러가 발생한다(기존 동작 회귀 없음).

[env:unit]

---

### SC-009 (FR-004 관련): discord add — `--id` 미제공 시 access.json에 dmPolicy=pairing, pending 없음

**Given** `cctg add mybot /tmp --channel discord --token-stdin`으로 봇을 등록할 때 (--id 미제공),
**When** 생성된 `access.json`을 읽으면,
**Then** `dmPolicy`는 `"pairing"`, `allowFrom`은 `[]`, `groups`는 `{}`, `"pending"` 키가 존재하지 않는다.

[env:unit]

---

### SC-010 (FR-004 관련): discord add — `--id 12345` 제공 시 access.json에 dmPolicy=allowlist, allowFrom에 ID 포함, pending 없음

**Given** `cctg add mybot /tmp --channel discord --token-stdin --id 12345`로 봇을 등록할 때,
**When** 생성된 `access.json`을 읽으면,
**Then** `dmPolicy`는 `"allowlist"`, `allowFrom`에 `"12345"` 포함, `"pending"` 키가 존재하지 않는다.

[env:unit]

---

### SC-011 (FR-004 관련): telegram add — 기존 access.json 시드에서 pending 필드 제거

**Given** `cctg add mybot /tmp --channel telegram --token-stdin --id 12345`로 봇을 등록할 때,
**When** 생성된 `access.json`을 읽으면,
**Then** `dmPolicy`는 `"allowlist"`, `allowFrom`에 `"12345"` 포함, `"pending"` 키가 존재하지 않는다.

[env:unit]

---

### SC-012 (FR-005 관련): ADD_PROMPT_TGID 메시지가 telegram 특정 문자열("Telegram", "@userinfobot")을 포함하지 않음

**Given** `messages/en.sh`와 `messages/ko.sh`를 읽었을 때,
**When** `ADD_PROMPT_TGID`(또는 대체 키) 값을 확인하면,
**Then** 메시지에 "Telegram" 또는 "@userinfobot" 등 telegram 특정 문자열이 하드코딩되어 있지 않다. (채널별 id_label을 런타임에 주입하는 구조로 변경되어 있어야 함.)

[env:static]

---

### SC-013 (FR-005 관련): STATUS_GLOBAL 메시지가 "/telegram" 하드코딩을 포함하지 않음

**Given** `messages/en.sh`와 `messages/ko.sh`를 읽었을 때,
**When** `STATUS_GLOBAL` 키 값을 확인하면,
**Then** 메시지에 `"/telegram"` 하드코딩이 없다.

[env:static]

---

### SC-014 (FR-005 관련): STATUS_HINT_NO_TOKEN 메시지가 "TELEGRAM_BOT_TOKEN" 하드코딩을 포함하지 않음

**Given** `messages/en.sh`와 `messages/ko.sh`를 읽었을 때,
**When** `STATUS_HINT_NO_TOKEN` 키 값을 확인하면,
**Then** 메시지에 `"TELEGRAM_BOT_TOKEN"` 하드코딩이 없다. (token_key 필드값을 런타임 인자로 받는 구조로 변경.)

[env:static]

---

### SC-015 (FR-005 관련): DOCTOR_PLUGIN_HINT 메시지가 telegram 특정 설치 경로를 포함하지 않음

**Given** `messages/en.sh`와 `messages/ko.sh`를 읽었을 때,
**When** `DOCTOR_PLUGIN_HINT` 키 값을 확인하면,
**Then** 메시지에 `"telegram@claude-plugins-official"` 또는 "telegram 플러그인" 등 telegram 특정 문자열이 하드코딩되어 있지 않다. (IMPLEMENTED_CHANNELS 기반으로 동적 생성되거나 일반화된 문구로 변경.)

[env:static]

---

### SC-016 (FR-006 관련): zsh 자동완성 `--channel` 후보에 discord 포함

**Given** `completions/_cctg`를 읽었을 때,
**When** `--channel` 분기의 `compadd` 인자를 확인하면,
**Then** `"telegram"` 하드코딩 대신 `IMPLEMENTED_CHANNELS` 변수 참조 또는 동적 목록을 사용한다.

[env:static]

---

### SC-017 (FR-006 관련): bash 자동완성 `--channel` 후보에 discord 포함

**Given** `completions/cctg.bash`를 읽었을 때,
**When** `--channel` 분기의 `COMPREPLY` 생성 코드를 확인하면,
**Then** `"telegram"` 하드코딩 대신 `IMPLEMENTED_CHANNELS` 변수 참조 또는 동적 목록을 사용한다.

[env:static]

---

### SC-018 (FR-007 관련): `cctg status` 출력에 각 봇의 채널 표시명 포함

**Given** telegram 봇 1개와 discord 봇 1개가 등록된 상태에서 `cctg status`를 실행하면,
**When** 출력을 확인하면,
**Then** telegram 봇 행에 `Telegram` 문자열이, discord 봇 행에 `Discord` 문자열이 포함된다.

[env:unit]

---

### SC-019 (FR-007 관련): jq 있고 access.json 있을 때 `cctg status`에 dmPolicy와 groups 수 표시

**Given** jq가 설치되어 있고, discord 봇의 access.json에 `{dmPolicy:"pairing", groups:{}}` 이 있을 때,
**When** `cctg status`를 실행하면,
**Then** 해당 봇 행에 `pairing`과 `0 groups`(또는 동등 정보)가 포함된다.

[env:unit]

---

### SC-020 (FR-007 관련): jq 없을 때 `cctg status`가 채널 표시명만 출력하고 실패하지 않음

**Given** jq가 설치되어 있지 않은 환경에서 discord 봇이 등록되어 있을 때,
**When** `cctg status`를 실행하면,
**Then** 오류 없이 완료되며, discord 봇 행에 채널 표시명(`Discord`)이 포함된다.

[env:unit]

---

### SC-021 (NFR-001 관련): 수정 파일이 bash --posix 또는 bash 3.2 문법 검사를 통과

**Given** 변경된 `lib/channels.sh`, `messages/en.sh`, `messages/ko.sh`, `completions/cctg.bash`를 대상으로,
**When** `bash --norc --noprofile --posix -n <파일>`을 실행하면,
**Then** 문법 오류가 없다(exit 0).
**And** `lib/commands.sh`는 사전 존재하는 process substitution(`done < <(...)`)으로 `--posix -n` 대상이 아니므로 `bash -n`(non-posix)으로 검증하여 문법 오류가 없다(exit 0). (REC-001 정정 — 코드·테스트는 처음부터 정합)

[env:static]

---

### SC-022 (NFR-002 관련): discord 봇 .env 파일에 DISCORD_BOT_TOKEN 키로 토큰 저장

**Given** `cctg add mybot /tmp --channel discord --token-stdin`으로 등록 시 stdin에 유효한 토큰을 입력하면,
**When** `~/.claude/channels/mybot/.env`를 읽으면,
**Then** `DISCORD_BOT_TOKEN=<토큰값>` 형식으로 저장되어 있다.

[env:unit]

---

### SC-023 (NFR-003 관련): 레거시 3컬럼 레지스트리 행의 봇이 telegram으로 처리됨

**Given** `projects.conf`에 `mybot | /path/to/cwd | /path/to/state` (4번째 컬럼 없음) 형식의 행이 있을 때,
**When** `channel_of mybot`을 호출하면,
**Then** `telegram`을 반환한다.

[env:unit]

---

### SC-024 (NFR-003 관련): 기존 bats 테스트 스위트가 회귀 없이 통과

**Given** 본 spec의 변경이 적용된 코드베이스에서,
**When** `bats tests/`를 실행하면,
**Then** 기존 88개 테스트가 모두 통과한다(새 테스트 추가로 총 수는 늘어남).

[env:unit]

---

### SC-025 (FR-008 관련): discord add `--group 846209781206941736` 1회 → access.json groups에 해당 id 키 존재

**Given** `cctg add mybot /tmp --channel discord --token-stdin --group 846209781206941736`으로 봇을 등록할 때 (stdin에 유효한 토큰 입력),
**When** 생성된 `access.json`을 읽으면,
**Then** `groups`에 키 `"846209781206941736"`이 존재하고, 그 값은 `{"requireMention": true, "allowFrom": []}`이다.

[env:unit]

---

### SC-026 (FR-008 관련): discord add `--group A --group B` → access.json groups에 A, B 두 키 모두 존재

**Given** `cctg add mybot /tmp --channel discord --token-stdin --group 111000111000111000 --group 222000222000222000`으로 봇을 등록할 때 (stdin에 유효한 토큰 입력),
**When** 생성된 `access.json`을 읽으면,
**Then** `groups`에 키 `"111000111000111000"`과 `"222000222000222000"` 두 개가 모두 존재한다.

[env:unit]

---

### SC-027 (FR-008 관련): `--group abc`(비숫자) → 에러 반환, 등록 안 됨

**Given** `cctg add mybot /tmp --channel discord --token-stdin --group abc`를 실행할 때 (stdin에 유효한 토큰 입력),
**When** 실행 결과를 확인하면,
**Then** 에러가 출력되고 비-0 exit code로 종료되며, 레지스트리에 `mybot`이 등록되어 있지 않다.

[env:unit]

---

### SC-028 (FR-008 관련): `--group` 미지정 시 access.json groups:{}

SC-009, SC-010에서 `--group` 미지정 시 `groups:{}`가 이미 단언되어 있으므로 별도 추가 불필요. (SC-009: pairing 경로, SC-010: allowlist 경로 각각 `"groups"는 "{}"` 포함.)

[env:unit] — SC-009, SC-010으로 갈음.

---

### SC-029 (FR-008 관련): 자동완성 add 흐름에 `--group` 플래그 후보 포함

**Given** `completions/_cctg`(zsh)와 `completions/cctg.bash`(bash)를 읽었을 때,
**When** `add` 서브커맨드의 플래그 후보 목록을 확인하면,
**Then** `--group`이 포함되어 있다.

[env:static]

---

### SC-030 (FR-008 관련): nomention 수식어 지정 `--group` → groups[id].requireMention == false

**Given** `cctg add mybot /tmp --channel discord --token-stdin --group 846209781206941736:nomention`으로 봇을 등록할 때 (stdin에 유효한 토큰 입력),
**When** 생성된 `access.json`을 읽으면,
**Then** `groups["846209781206941736"].requireMention`이 `false`이다.

[env:unit]

---

### SC-031 (FR-008 관련): allow 수식어 지정 `--group` → groups[id].allowFrom에 지정 멤버 포함

**Given** `cctg add mybot /tmp --channel discord --token-stdin --group 846209781206941736:allow=184695080709324800,221773638772129792`으로 봇을 등록할 때 (stdin에 유효한 토큰 입력),
**When** 생성된 `access.json`을 읽으면,
**Then** `groups["846209781206941736"].allowFrom`에 `"184695080709324800"`과 `"221773638772129792"`가 모두 포함된다.

[env:unit]

---

### SC-032 (FR-008 관련): allow에 비숫자 멤버 ID → 에러 반환, 등록 안 됨

**Given** `cctg add mybot /tmp --channel discord --token-stdin --group 846209781206941736:allow=abc`를 실행할 때 (stdin에 유효한 토큰 입력),
**When** 실행 결과를 확인하면,
**Then** 에러가 출력되고 비-0 exit code로 종료되며, 레지스트리에 `mybot`이 등록되어 있지 않다.

[env:unit]

---

## 요구사항 구조화 매트릭스

> 매핑 누락(SC 없는 FR/NFR, FR/NFR 없는 SC) 0건 완료 조건.

| US-ID | FR-ID | NFR-ID | SC-ID | [env:*] | MoSCoW |
|---|---|---|---|---|---|
| US-003 | FR-001 | — | SC-001 | static | Must |
| US-003 | FR-001 | — | SC-002 | static | Must |
| US-001 | FR-001 | — | SC-003 | unit | Must |
| US-003 | FR-002 | — | SC-004 | unit | Must |
| US-003 | FR-002 | — | SC-005 | unit | Must |
| US-003 | FR-002 | — | SC-006 | unit | Must |
| US-001 | FR-003 | — | SC-007 | unit | Must |
| US-001 | FR-003 | — | SC-008 | unit | Must |
| US-001 | FR-004 | — | SC-009 | unit | Must |
| US-001 | FR-004 | — | SC-010 | unit | Must |
| US-001 | FR-004 | — | SC-011 | unit | Must |
| US-003 | FR-005 | — | SC-012 | static | Must |
| US-002 | FR-005 | — | SC-013 | static | Must |
| US-002 | FR-005 | — | SC-014 | static | Must |
| US-003 | FR-005 | — | SC-015 | static | Must |
| US-003 | FR-006 | — | SC-016 | static | Should |
| US-003 | FR-006 | — | SC-017 | static | Should |
| US-002 | FR-007 | — | SC-018 | unit | Must |
| US-002 | FR-007 | — | SC-019 | unit | Should |
| US-002 | FR-007 | NFR-005 | SC-020 | unit | Must |
| — | — | NFR-001 | SC-021 | static | Must |
| — | — | NFR-002 | SC-022 | unit | Must |
| — | — | NFR-003 | SC-023 | unit | Must |
| — | — | NFR-003 | SC-024 | unit | Must |
| US-001 | FR-008 | — | SC-025 | unit | Must |
| US-001 | FR-008 | — | SC-026 | unit | Must |
| US-001 | FR-008 | — | SC-027 | unit | Must |
| US-001 | FR-004, FR-008 | — | SC-028 | unit | Must (SC-009/SC-010 갈음) |
| US-001 | FR-008 | NFR-004 | SC-029 | static | Should |
| US-001 | FR-008 | — | SC-030 | unit | Must |
| US-001 | FR-008 | — | SC-031 | unit | Must |
| US-001 | FR-008 | — | SC-032 | unit | Must |

NFR-004(최소 표면): `--group` 1개 플래그 추가. 세부 속성은 컴파운드 토큰으로 표현하여 플래그 수 유지. SC-025~SC-032로 명시 검증된다. `--group` 외 추가 표면 증가 없음은 FR-001~FR-007 기존 SC에서 암묵적으로 검증된다.

---

## 범위 외

- **imessage/fakechat 실제 구현**: descriptor 확장(id_required=no, token_required=no 대비)은 포함되지만 실제 채널 활성화는 범위 외.
- **Discord 봇 생성·Developer Portal 설정**: Discord 측 사전 작업. 플러그인 책임.
- **`/discord:access` 스킬 기능**: 런타임 접근 관리는 플러그인 소유. cctg는 초기 시드만 담당.
- **`/discord:access set` 키 — ackReaction, replyToMode, textChunkLimit, chunkMode, mentionPatterns**: 런타임 응답 동작 설정은 플러그인 스킬 소유. cctg add 시드 범위 외.
- **통합 테스트(실제 Discord API 연결)**: 실제 봇 토큰·서버 필요. 범위 외.

사후 운영 검증 피드백 사이클:

1. 파이프라인 완료 후 사용자가 실제 Discord 봇으로 점검할 시나리오: DM 첫 메시지(페어링 코드 반환 확인), `/discord:access pair <code>`로 승인 후 DM 응답 확인, 서버채널 `/discord:access group add`로 등록 후 @멘션 응답 확인, `cctg status` 출력에 Discord 게이트웨이와 토폴로지 표시 확인.
2. 결함 발견 시: 결함 정보를 본 spec.md "배경 및 목적"에 추가 → main session의 "spec 수정" 이벤트 → 1단계 재진입 또는 별도 patch spec.

---

## 미결 사항

없음. 모든 요구사항이 명확히 정의되었으며 `[NEEDS CLARIFICATION]` 항목 0건.
