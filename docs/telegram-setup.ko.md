[English](telegram-setup.md) | **한국어**

# Telegram 봇 설정

> 단계별 안내: 새 Telegram 봇을 만들고, `cctg add` 로 등록한 뒤, 휴대폰에서 Claude Code 프로젝트와 대화한다.

## 목차

- [시작하기 전에](#시작하기-전에)
- [1단계 — Telegram 플러그인 설치](#1단계--telegram-플러그인-설치)
- [2단계 — BotFather 로 새 봇 만들기](#2단계--botfather-로-새-봇-만들기)
- [3단계 — 본인의 숫자 Telegram ID 확인](#3단계--본인의-숫자-telegram-id-확인)
- [4단계 — `cctg add` 로 봇 등록](#4단계--cctg-add-로-봇-등록)
  - [대화형 등록](#대화형-등록)
  - [비대화형 등록 (CI / 스크립트)](#비대화형-등록-ci--스크립트)
- [5단계 — 봇 시작](#5단계--봇-시작)
- [6단계 — 확인](#6단계--확인)
- [문제 해결](#문제-해결)
- [함께 보기](#함께-보기)

## 시작하기 전에

전체 흐름은 다음과 같다.

1. Claude Code 에 Telegram 플러그인을 설치한다 (전역, 1회).
2. BotFather 로 **새** Telegram 봇을 만들고 토큰을 복사한다.
3. 본인의 **숫자** Telegram ID 를 확인한다.
4. `cctg add` 로 봇을 등록한다.
5. `cctg up` 으로 시작한다.
6. Telegram 에서 봇에게 DM 을 보낸다.

프로젝트 봇마다 2~6단계만 반복하며, 1단계는 1회성 전역 설치다.

## 1단계 — Telegram 플러그인 설치

CCTG 는 공식 Telegram 플러그인을 구동하며, 이 플러그인은 Claude Code 안에 **전역**으로 설치되어야 한다. Claude Code 에서 다음을 실행한다.

```
/plugin install telegram@claude-plugins-official
```

`cctg doctor` 가 이 요구사항을 안내하므로, 플러그인 설치 여부가 불확실하면 `cctg doctor` 를 실행하여 출력 끝부분의 플러그인 안내를 확인한다.

## 2단계 — BotFather 로 새 봇 만들기

1. Telegram 에서 [@BotFather](https://t.me/BotFather) 를 연다.
2. `/newbot` 명령을 보낸다.
3. **표시 이름**(채팅에 보이는 이름)을 정한다.
4. **사용자명**을 정한다 — 반드시 `bot` 으로 끝나야 한다 (예: `myproject_helper_bot`).
5. BotFather 가 다음과 같은 형태의 **봇 토큰**으로 응답한다.

   ```
   123456789:ABCdefGhIJKlmNoPQRstuVWXyz1234567890
   ```

이 토큰은 비공개로 보관한다 — 토큰을 가진 사람은 누구나 봇을 제어할 수 있다.

> **반드시 새 봇이어야 한다.** 각 프로젝트 봇은 자신의 토큰으로 Telegram 을 폴링한다. 하나의 토큰을 동시에 실행 중인 두 프로세스에서 재사용하면 두 폴러가 충돌하여 메시지가 누락된다. 등록하는 CCTG 봇마다 별도의 봇을 만든다.

## 3단계 — 본인의 숫자 Telegram ID 확인

CCTG 는 본인만 봇에 접근할 수 있도록 봇을 잠근다. 이를 위해 본인의 **숫자** Telegram 사용자 ID 가 필요하다 (`@username` 이 아니라 숫자만).

1. Telegram 에서 [@userinfobot](https://t.me/userinfobot) 에게 DM 을 보낸다.
2. 봇이 숫자 사용자 ID 로 응답한다 (예: `123456789`).

CCTG 는 등록 시 이 ID 를 봇의 `access.json` allowlist 에 시드하므로 **Telegram 은 별도의 페어링 단계가 필요 없다** — 등록 직후 바로 봇에게 메시지를 보낼 수 있다.

## 4단계 — `cctg add` 로 봇 등록

```bash
cctg add <name> <working_dir>
```

- `<name>` — 이 봇의 식별자. 문자, 숫자, `_`, `-` 만 사용한다. `telegram`, `discord`, `imessage`, `fakechat` 이름은 **예약어**라 거부된다.
- `<working_dir>` — 봇의 Claude Code 세션이 실행되는 프로젝트 디렉터리 (작업 디렉터리 / cwd).

### 대화형 등록

토큰 플래그 없이 `cctg add` 를 실행하면 다음 세 가지를 순서대로 입력받는다.

1. **봇 토큰** — 입력이 가려진 상태로 붙여넣는다 (키 입력이 표시되지 않는다).
2. **본인의 숫자 Telegram ID** — 숫자만 가능하며 (`^[0-9]+$`), 아니면 `add` 가 거부한다.
3. **권한 모드** — 메뉴에서 번호를 고른다 (`1` = `bypassPermissions`, `2` = `acceptEdits`, …). Enter(또는 `7`)를 누르면 공통 정책을 따른다. 모드명을 직접 입력해도 되며, 잘못 입력하면 다시 묻는다.

세 입력이 모두 검증되기 전에는 디스크에 아무것도 쓰지 않으므로, 잘못 입력해도 반쪽 생성된 봇이 남지 않는다.

예시 세션 (토큰은 가려짐):

```console
$ cctg add myproject ~/work/myproject
Bot token (issued by @BotFather, must be a NEW bot): ********
Your Telegram numeric ID: 123456789
Permission mode — pick a number:
  1) bypassPermissions   2) acceptEdits   3) auto
  4) default             5) dontAsk       6) plan
  7) (follow shared)
Number [1-7, Enter=follow shared]: 1
Registered: myproject → cwd=/Users/you/work/myproject, state=/Users/you/.claude/channels/myproject
  seeded 123456789 into the allowlist (no pairing needed)
```

등록은 상태 디렉터리 `~/.claude/channels/<name>/` 를 만들고 다음을 수행한다.

- 토큰을 `.env` 에 `TELEGRAM_BOT_TOKEN` 으로 저장한다 (권한 `chmod 600`).
- `access.json` 에 `dmPolicy: "allowlist"`, `allowFrom: ["<본인 ID>"]`, `groups: {}` 를 기록한다.
- `launch.env`(봇별 옵션)와 `inbox/` 디렉터리를 생성한다.

### 비대화형 등록 (CI / 스크립트)

토큰 플래그를 지정하면 `add` 가 비대화형 모드로 전환된다. 이 모드에서 Telegram 은 `--id <num>` 이 **필수**이며 `--mode` 는 선택이다. 토큰은 명령줄 인자로 전달되지 않으며 (프로세스 목록으로 노출되므로) 환경 변수나 stdin 으로 받는다.

| 플래그 | 의미 |
| --- | --- |
| `--channel telegram` | 채널 타입 (Telegram 이 기본값이라 생략 가능). |
| `--id <num>` | 본인의 숫자 Telegram ID. Telegram 비대화형 모드에서 필수이며 `^[0-9]+$` 를 만족해야 한다. |
| `--token-env <VAR>` | 환경 변수 `<VAR>` 에서 토큰을 읽는다. |
| `--token-stdin` | 표준 입력에서 토큰을 읽는다. |
| `--mode <m>` | 권한 모드: `acceptEdits`, `auto`, `bypassPermissions`, `default`, `dontAsk`, `plan` 중 하나. 선택. |

예시:

```bash
BOT_TOKEN="123:ABC..." cctg add myproject ~/work/myproject \
  --token-env BOT_TOKEN --id 123456789 --mode bypassPermissions

secrets get tg-token | cctg add myproject ~/work/myproject --token-stdin --id 123456789
```

## 5단계 — 봇 시작

```bash
cctg up <name>
```

이 명령은 `cctg-<name>` 이라는 분리된 tmux 세션을 시작하며, 봇이 실행되는 동안 Mac 이 절전되지 않도록 `caffeinate -is` 로 감싼다. 봇이 올라오면 Telegram 에서 봇에게 DM 을 보내면 응답한다.

## 6단계 — 확인

```bash
cctg status
```

`cctg status` 는 봇을 RUNNING 상태로 표시하며 가동 시간, cwd / 상태 경로, 권한 모드, 채널 토폴로지를 함께 보여준다.

그 밖에 유용한 확인:

- `cctg logs <name>` — 봇 세션의 최근 출력을 보여준다.
- `cctg attach <name>` — 실행 중인 tmux 세션에 접속한다 (다시 분리하려면 `Ctrl-b` 후 `d`).

## 문제 해결

봇이 응답하지 않으면:

- **플러그인 누락?** `cctg doctor` 를 실행하여 Telegram 플러그인이 설치되어 있는지 확인한다 (1단계).
- **실행 중이 아님?** `cctg status` 를 실행하여 봇이 RUNNING 인지 확인하고, 아니면 `cctg up <name>` 을 실행한다.
- **allowlist 에 없음?** 등록한 숫자 ID 와 동일한 Telegram 계정으로 DM 을 보내고 있는지 확인한다.
- **`status` 에서 BROKEN 표시?** 작업 디렉터리가 없거나 `.env` 토큰 파일이 없다. 작업 디렉터리를 다시 만들거나 봇을 재등록한다.
- **권한 프롬프트나 멈춤?** [permissions.ko.md](permissions.ko.md) 를 참조한다.

## 운영자 책임

이 봇을 운영하면 당신은 Telegram 봇 운영자이자 Anthropic API 사용자가 된다. 상위 서비스에서 비롯되는 몇 가지 의무가 있다: 본인 외 누군가가 봇에 접근 가능하면 봇이 AI임을 고지하고, 다른 사람이 사용하면 개인정보처리방침을 공개하며, 사용은 본인 Anthropic 플랜 약관과 Usage Policy의 적용을 받음을 유의한다. **[SECURITY.md → Your responsibilities as a bot operator](../SECURITY.md#your-responsibilities-as-a-bot-operator)** 참조.

## 함께 보기

- [installation.ko.md](installation.ko.md)
- [commands.ko.md](commands.ko.md)
- [permissions.ko.md](permissions.ko.md)
- [discord-setup.ko.md](discord-setup.ko.md)

[← README로 돌아가기](../README.ko.md)
