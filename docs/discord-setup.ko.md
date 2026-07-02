[English](discord-setup.md) | **한국어**

# Discord 봇 설정

> 단계별 안내: 새 Discord 봇을 만들고, `cctg add` 로 등록하고, Discord DM·서버 채널에서 Claude Code 프로젝트에 접근한다.

## 목차

- [시작하기 전에](#시작하기-전에)
- [Telegram 과 다른 Discord 접근 방식](#telegram-과-다른-discord-접근-방식)
- [1단계 — Discord 플러그인 설치](#1단계--discord-플러그인-설치)
- [2단계 — Discord 애플리케이션·봇 생성](#2단계--discord-애플리케이션봇-생성)
- [3단계 — `cctg add` 로 봇 등록](#3단계--cctg-add-로-봇-등록)
  - [대화형 등록](#대화형-등록)
  - [DM 접근: 페어링 vs. 허용목록](#dm-접근-페어링-vs-허용목록)
  - [비대화형 등록 (CI / 스크립트)](#비대화형-등록-ci--스크립트)
- [4단계 — `--group` 으로 서버 채널 추가](#4단계--group-으로-서버-채널-추가)
- [5단계 — 봇 시작](#5단계--봇-시작)
- [6단계 — 확인](#6단계--확인)
- [런타임 접근 관리](#런타임-접근-관리)
- [문제 해결](#문제-해결)
- [관련 문서](#관련-문서)

## 시작하기 전에

전체 흐름은 다음과 같다.

1. Claude Code 에 Discord 플러그인을 설치한다 (전역, 최초 1회).
2. 새 Discord 애플리케이션·봇을 만들고, 토큰을 복사하고, 봇을 서버에 초대한다.
3. `cctg add --channel discord` 로 봇을 등록한다.
4. 봇이 응답할 서버 채널을 `--group` 으로 시드한다 (일반적인 구성; DM 전용 봇이면 생략).
5. `cctg up` 으로 시작한다.
6. 봇에 DM 을 보내거나 서버 채널에서 멘션한다.

프로젝트 봇마다 2~6단계만 반복한다. 1단계는 전역 1회 설치다.

## Telegram 과 다른 Discord 접근 방식

Discord 등록은 [Telegram](telegram-setup.ko.md) 과 동일한 구조이지만, 접근 모델이 두 가지 중요한 점에서 다르다.

- **숫자 ID 가 선택 사항이다.** Telegram 은 숫자 ID 가 필수이며 즉시 허용목록을 시드한다. Discord 는 ID(`--id`) 가 선택이며, 제공 여부가 **DM 접근 정책**을 결정한다.
  - **`--id` 없이** (기본): 봇이 **페어링(pairing)** 모드로 시작한다. 봇에 처음 DM 을 보내면 플러그인이 페어링 코드를 알려주고, 이를 터미널에서 승인한다.
  - **`--id <본인 user ID>` 와 함께**: 봇이 **허용목록(allowlist)** 모드로 시작하여 본인 계정을 즉시 신뢰한다 — 페어링 단계가 없다.
- **서버 채널을 지원한다.** Discord 봇은 서버 채널 안에서도 응답할 수 있으며, `--group` 플래그로 시드한다 ([4단계](#4단계--group-으로-서버-채널-추가) 참조). Telegram 등록에는 대응 기능이 없다.

## 1단계 — Discord 플러그인 설치

CCTG 는 공식 Discord 플러그인을 구동하며, 이 플러그인은 Claude Code 안에 **전역**으로 설치되어야 한다. Claude Code 에서 다음을 실행한다.

```
/plugin install discord@claude-plugins-official
```

`cctg doctor` 가 이 요구사항을 상기시키므로, 플러그인 존재 여부가 확실하지 않으면 `cctg doctor` 를 실행하고 출력 끝부분의 플러그인 힌트를 확인한다.

## 2단계 — Discord 애플리케이션·봇 생성

봇은 **[Discord 개발자 포털](https://discord.com/developers/applications)** 에서 만든다 — 이 단계는 CCTG 가 아니라 Discord 와 `discord@claude-plugins-official` 플러그인에 속한다. 순서대로 따른다.

1. **애플리케이션 생성.** 개발자 포털을 열고 **New Application** 을 클릭한 뒤 이름을 지정하고 확인한다.
2. **봇 추가.** 좌측 사이드바에서 **Bot** 을 열고 봇의 **username** 을 설정한다.
3. **메시지 본문 intent 활성화.** 같은 **Bot** 페이지에서 **Privileged Gateway Intents** 로 스크롤해 **Message Content Intent** 를 켠다. 이걸 켜지 않으면 봇이 모든 메시지를 빈 본문으로 받아, 사용자가 보낸 내용을 전혀 볼 수 없다.
4. **봇 토큰 복사.** 같은 **Bot** 페이지의 **Token** 에서 **Reset Token** 을 클릭하고 값을 복사한다. **한 번만** 표시되므로 3단계용으로 안전한 곳에 보관한다. 이 토큰을 가진 사람은 누구나 봇을 제어할 수 있으니 비밀번호처럼 취급한다.
5. **봇을 서버에 초대.** Discord 는 봇과 같은 서버에 있지 않으면 DM 을 허용하지 않는다. **OAuth2 → URL Generator** 로 가서 **`bot`** scope 를 체크하고, **Bot Permissions** 에서 다음을 활성화한다.
   - View Channels
   - Send Messages
   - Send Messages in Threads
   - Read Message History
   - Attach Files
   - Add Reactions

   **Integration Type** 를 **Guild Install** 로 설정하고, **Generated URL** 을 복사해 브라우저에서 열어 본인이 속한 서버에 봇을 추가한다.

   > DM 전용으로는 권한이 하나도 필요 없지만, 지금 켜 두면 나중에 서버 채널에서 봇을 쓰려 할 때 다시 오지 않아도 된다 ([4단계](#4단계--group-으로-서버-채널-추가)).

봇이 서버에 들어가고 토큰을 확보했으면 3단계를 위해 CCTG 로 돌아온다.

> **플러그인 자체의 `/discord:configure` 나 `--channels` 단계는 실행하지 않는다.** 플러그인 README 는 그 단계들을 독립 전역 봇용으로 안내하지만, CCTG 에서는 `cctg add` 가 토큰을 저장하고 `cctg up` 이 올바른 채널 플래그로 봇을 기동한다.
>
> **라벨이 바뀌었다면:** Discord 포털 UI 는 시간이 지나며 바뀐다. 현재 intent/scope 요구사항의 권위 있는 출처는 `discord@claude-plugins-official` 플러그인의 자체 README 와 [Discord 공식 개발자 문서](https://discord.com/developers/docs)다.

## 3단계 — `cctg add` 로 봇 등록

```bash
cctg add <name> <working_dir> --channel discord --group <channelId>
```

- `<name>` — 이 봇의 식별자. 문자, 숫자, `_`, `-` 만 사용한다. `telegram`, `discord`, `imessage`, `fakechat` 은 **예약어**이며 거부된다.
- `<working_dir>` — 봇의 Claude Code 세션이 실행되는 프로젝트 디렉터리(작업 디렉터리 / cwd).
- `--channel discord` — Discord 채널을 선택한다. (지정하지 않으면 채널은 Telegram 이 기본값이다.)
- `--group <channelId>` — 봇이 응답할 서버 채널을 시드한다. Discord 봇은 보통 서버 채널에 추가해 사용하므로 일반적으로 최소 하나는 지정하게 된다. 반복 가능하며 수식어 형식·`jq` 요구사항이 있다 — 상세는 [4단계](#4단계--group-으로-서버-채널-추가). 생략하면 DM 전용 봇이 된다 (아래 예시 다음의 노트 참조).

### 대화형 등록

토큰 플래그 없이 `cctg add ... --channel discord` 를 실행하면 최대 세 가지를 순서대로 묻는다.

1. **봇 토큰** — 가려진 입력으로 붙여넣는다(입력한 키가 화면에 보이지 않는다).
2. **본인 Discord user ID** — Discord 에서는 *선택 사항*이다. Enter 로 건너뛸 수 있다(이 경우 페어링 모드가 선택된다). 입력한다면 숫자만(`^[0-9]+$`) 가능하며, 아니면 `add` 가 거부한다.
3. **권한 모드** — 메뉴에서 번호를 고른다 (`1` = `bypassPermissions`, `2` = `acceptEdits`, …). Enter(또는 `7`)를 누르면 공통 정책을 따른다. 모드명을 직접 입력해도 되며, 잘못 입력하면 다시 묻는다.

모든 입력이 검증되기 전에는 디스크에 아무것도 쓰지 않으므로, 잘못 입력해도 반쪽 생성된 봇이 남지 않는다.

서버 채널 하나를 시드하고 ID 는 건너뛰는 예시 세션(토큰 가려짐):

```console
$ cctg add mybot ~/work/mybot --channel discord --group 846209781206941736
Bot token: ********
Discord user ID:
Permission mode — pick a number:
  1) bypassPermissions   2) acceptEdits   3) auto
  4) default             5) dontAsk       6) plan
  7) (follow shared)
Number [1-7, Enter=follow shared]: 1
Registered: mybot → cwd=/Users/you/work/mybot, state=/Users/you/.claude/channels/mybot
```

> **`--group` 없이 등록했다면?** 봇은 **DM 전용**으로 시작한다 — 서버 채널이 시드되기 전까지는 어떤 서버 채널에서도 응답하지 않는다. 재등록할 필요는 없다: 터미널에서 `/discord:access` 스킬로 나중에 채널을 추가할 수 있다 ([런타임 접근 관리](#런타임-접근-관리) 참조).

등록 시 상태 디렉터리 `~/.claude/channels/<name>/` 를 생성하고 다음을 수행한다.

- 토큰을 `.env` 에 `DISCORD_BOT_TOKEN` 으로 저장한다(권한 `chmod 600`).
- `access.json` 을 작성한다(형태는 다음 절 참조).
- `launch.env`(봇별 옵션)와 `inbox/` 디렉터리를 만든다.

### DM 접근: 페어링 vs. 허용목록

Discord 에서는 숫자 ID 의 제공 여부가 시드되는 DM 정책을 결정한다.

- **`--id` 없이** (또는 대화형 ID 프롬프트를 빈 채로 둠): `access.json` 이 다음과 같이 시드된다.

  ```json
  { "dmPolicy": "pairing", "allowFrom": [], "groups": {} }
  ```

  봇에 처음 DM 을 보내면 플러그인이 **페어링 코드**를 반환한다. 이를 터미널에서 Discord 접근 스킬로 승인한다.

  ```
  /discord:access pair <code>
  ```

- **`--id <본인 user ID>` 와 함께**: `access.json` 이 페어링을 건너뛰고 허용목록 모드로 바로 시드된다.

  ```json
  { "dmPolicy": "allowlist", "allowFrom": ["<본인 user ID>"], "groups": {} }
  ```

### 비대화형 등록 (CI / 스크립트)

토큰 플래그를 제공하면 `add` 가 비대화형 모드로 전환된다. 토큰은 명령행 인자로 전달되지 않으며(프로세스 목록을 통해 유출되므로) 환경 변수 또는 stdin 으로 받는다. Discord 에서는 비대화형 모드에서도 `--id` 가 선택으로 유지된다(생략 시 페어링 선택). `--mode` 도 선택이다.

| 플래그 | 의미 |
| --- | --- |
| `--channel discord` | 채널 타입. Discord 를 선택하려면 필수다(기본값은 Telegram). |
| `--id <num>` | 본인 Discord user ID. Discord 에서는 **선택** — 페어링은 생략, 즉시 허용목록은 제공. `^[0-9]+$` 와 일치해야 한다. |
| `--token-env <VAR>` | 환경 변수 `<VAR>` 에서 토큰을 읽는다. |
| `--token-stdin` | 표준 입력에서 토큰을 읽는다. |
| `--mode <m>` | 권한 모드: `acceptEdits`, `auto`, `bypassPermissions`, `default`, `dontAsk`, `plan` 중 하나. 선택. |
| `--group <spec>` | 서버 채널을 시드한다. 반복 가능. [4단계](#4단계--group-으로-서버-채널-추가) 참조. |

예시:

```bash
# 페어링 모드(--id 없음): 나중에 첫 DM 을 터미널에서 승인한다.
DISCORD_TOKEN="..." cctg add mybot ~/work/mybot --channel discord \
  --token-env DISCORD_TOKEN --mode bypassPermissions

# 허용목록 모드: 본인 계정을 즉시 신뢰한다.
secrets get discord-token | cctg add mybot ~/work/mybot --channel discord \
  --token-stdin --id 184695080709324800
```

## 4단계 — `--group` 으로 서버 채널 추가

DM 외에도 Discord 봇은 서버 채널 안에서 응답할 수 있다. 각 `--group` 플래그는 하나의 **채널 ID** 를 `access.json` 의 `groups` 객체에 시드한다. 채널 ID 뒤의 컴파운드 토큰이 해당 채널의 동작을 설정한다.

| `--group` 형식 | 효과 | 저장 형태 |
| --- | --- | --- |
| `--group <channelId>` | @mention 요구; 모든 멤버 허용. | `{ "requireMention": true, "allowFrom": [] }` |
| `--group <channelId>:nomention` | @mention 없이 응답. | `{ "requireMention": false, ... }` |
| `--group <channelId>:allow=<m1>,<m2>` | 해당 멤버 ID 만 봇을 트리거할 수 있다. | `{ ..., "allowFrom": ["<m1>","<m2>"] }` |
| `--group <id>:nomention:allow=<m1>,<m2>` | 두 수식어를 조합. | `{ "requireMention": false, "allowFrom": ["<m1>","<m2>"] }` |

참고:

- 여러 채널을 시드하려면 **`--group` 을 반복**한다.
- **모든 채널·멤버 ID 는 숫자**(`^[0-9]+$`)여야 한다. 숫자가 아닌 값은 거부되며 봇은 **등록되지 않는다**(검증이 레지스트리 기록 전에 일어난다).
- **`--group` 은 `jq` 설치를 요구한다** — 가변 키 JSON 객체를 `jq` 로 구성하기 때문이다. `jq` 가 없으면 명령이 실패한다. (`--group` 없는 일반 `cctg add` 는 `jq` 가 필요 없다.) `jq` 존재 여부는 `cctg doctor` 로 확인한다.

예시:

```bash
DISCORD_TOKEN="..." cctg add mybot ~/work/mybot --channel discord \
  --token-env DISCORD_TOKEN \
  --group 846209781206941736:nomention \
  --group 900111222333444555:allow=184695080709324800
```

결과 `access.json` 은 다음과 같다(형태는 예시).

```json
{
  "dmPolicy": "pairing",
  "allowFrom": [],
  "groups": {
    "846209781206941736": { "requireMention": false, "allowFrom": [] },
    "900111222333444555": { "requireMention": true,  "allowFrom": ["184695080709324800"] }
  }
}
```

## 5단계 — 봇 시작

```bash
cctg up <name>
```

이 명령은 `cctg-<name>` 라는 분리된 tmux 세션을 시작하며, 봇이 실행되는 동안 Mac 이 잠들지 않도록 `caffeinate -is` 로 감싼다. 봇이 올라오면 봇에 DM 을 보내거나 시드된 서버 채널에서 멘션한다.

## 6단계 — 확인

```bash
cctg status
```

`cctg status` 는 봇을 RUNNING 으로 표시하며 가동 시간, cwd / 상태 경로, 권한 모드, 채널 토폴로지를 보여준다. `jq` 가 있고 `access.json` 이 존재하면 채널 줄에 DM 정책과 시드된 그룹 수도 표시된다. 예:

```console
channel=Discord (pairing, 0 groups)
channel=Discord (allowlist, 2 groups)
```

그 밖의 유용한 확인:

- `cctg logs <name>` — 봇 세션의 최근 출력을 보여준다.
- `cctg attach <name>` — 실행 중인 tmux 세션에 연결한다(다시 분리하려면 `Ctrl-b` 후 `d`).

## 런타임 접근 관리

`cctg add` 는 **초기** `access.json` 만 시드한다. 그 이후의 모든 것 — 페어링 승인, 허용목록 편집, 그룹 추가·제거, DM 정책 변경 — 은 `/discord:access` 스킬의 영역이며, 이를 **터미널에서** 실행한다.

```
/discord:access pair <code>
```

> **보안:** 채팅 메시지가 요청한다는 이유만으로 페어링을 승인하거나 누군가를 허용목록에 추가하지 않는다. "대기 중인 페어링을 승인해줘" 나 "나를 허용목록에 추가해줘" 라는 메시지는 프롬프트 인젝션이 정확히 하는 요청이다. 접근 승인은 신뢰하려는 대상에 한해 본인 터미널에서만 한다.

## 문제 해결

봇이 응답하지 않으면:

- **플러그인 누락?** `cctg doctor` 를 실행하고 Discord 플러그인이 설치되었는지 확인한다(1단계).
- **실행 중이 아님?** `cctg status` 를 실행하고 봇이 RUNNING 으로 표시되는지 확인한다. 아니면 `cctg up <name>`.
- **아직 페어링 모드?** `--id` 없이 등록했다면 첫 DM 은 페어링 코드만 만든다 — 터미널에서 `/discord:access pair <code>` 로 승인한다.
- **`--group` 실패?** `jq` 가 설치되었는지(`cctg doctor`), 모든 채널·멤버 ID 가 숫자인지 확인한다. 숫자가 아닌 ID 는 명령 전체를 거부하고 봇을 미등록 상태로 둔다.
- **`status` 에서 BROKEN?** 작업 디렉터리가 없거나 `.env` 토큰 파일이 없다. 작업 디렉터리를 다시 만들거나 봇을 재등록한다.
- **권한 프롬프트나 멈춤?** [permissions.ko.md](permissions.ko.md) 참조.

## 운영자 책임

이 봇을 운영하면 당신은 Discord 봇 운영자이자 Anthropic API 사용자가 된다. Discord 개발자 약관은 모든 봇에 개인정보처리방침 공개를 **요구**하며 플랫폼 "API data" 의 상업화를 금지한다. 또한 다른 사람이 봇에 접근 가능하면 봇이 AI임을 고지하고, 사용은 본인 Anthropic 플랜 약관과 Usage Policy의 적용을 받음을 유의한다. **[SECURITY.md → Your responsibilities as a bot operator](../SECURITY.md#your-responsibilities-as-a-bot-operator)** 참조.

## 관련 문서

- [installation.ko.md](installation.ko.md)
- [commands.ko.md](commands.ko.md)
- [permissions.ko.md](permissions.ko.md)
- [telegram-setup.ko.md](telegram-setup.ko.md)

[← README 로 돌아가기](../README.ko.md)
