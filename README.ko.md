[English](README.md) | **한국어**

# CCTG — Claude Code Tmux Gateway

[![CI](https://github.com/qwertygeon/cctg/actions/workflows/ci.yml/badge.svg)](https://github.com/qwertygeon/cctg/actions/workflows/ci.yml)

**CCTG**(Claude Code Tmux Gateway)는 macOS에서 **tmux + Claude Code + 채팅 게이트웨이(Telegram 또는 Discord)**를 묶어, 프로젝트별 Claude Code 채팅 봇을 휴대폰이나 채팅 클라이언트에서 띄우고 관리하는 런처다. 명령은 `cctg` 다.

각 프로젝트 봇은 자기만의 상태 디렉터리·토큰·작업 디렉터리·격리된 tmux 세션을 가지며, CCTG는 전역 채널 봇(`~/.claude/channels/<채널>/`)을 건드리지 않는다.

> ⚠️ **프라이버시 — 먼저 읽으세요.** 봇은 받은 메시지를 자신의 작업 디렉터리에서 실행되는 Claude Code 프로세스로 중계하며, Claude Code는 그 내용을 처리를 위해 **Anthropic API로 전송**한다. 즉 봇과 주고받는 대화·코드·파일 내용이 제3자(Anthropic) 및 Telegram/Discord 인프라를 거친다. 민감한 저장소에 봇을 붙이기 전에 한 번 더 생각하고, `access.json` allowlist로 접근 주체를 본인(또는 신뢰된 사용자)으로 엄격히 제한하라.
>
> ℹ️ **비공식 도구.** CCTG는 Anthropic이 만들거나 보증하지 않은 비공식 서드파티 도구다. "Claude Code"·"Claude"는 Anthropic의 상표이며, 본 프로젝트는 Anthropic과 무관하다.
>
> 📜 **사용은 상위 서비스 약관에 종속된다.** 봇과의 대화 내용은 Anthropic API로 전송되므로, 사용은 본인 Anthropic 플랜 약관과 Usage Policy의 적용을 받는다. 또한 봇 운영은 곧 Telegram/Discord 봇 운영자가 됨을 뜻한다(예: Discord는 개인정보처리방침을 요구하며, 본인 외 다른 사람이 봇에 접근 가능하면 AI임을 고지해야 한다). 의미는 **[SECURITY.md → Your responsibilities as a bot operator](SECURITY.md#your-responsibilities-as-a-bot-operator)** 참조.

## 목차

- [누구를 위한 도구인가?](#누구를-위한-도구인가)
- [요구 사항](#요구-사항)
- [빠른 시작](#빠른-시작)
  - [1단계 — 사전 준비 설치](#1단계--사전-준비-설치)
  - [2단계 — CCTG 설치](#2단계--cctg-설치)
  - [3단계 — 봇 만들고 연결하기](#3단계--봇-만들고-연결하기)
  - [4단계 — 봇 기동](#4단계--봇-기동)
  - [5단계 — 메시지 보내고 상태 확인](#5단계--메시지-보내고-상태-확인)
- [자주 쓰는 명령](#자주-쓰는-명령)
- [권한 1분 요약](#권한-1분-요약)
- [지원 채널](#지원-채널)
- [문서](#문서)
- [제거](#제거)
- [기여 & 라이선스](#기여--라이선스)

## 누구를 위한 도구인가?

내 프로젝트 디렉터리에서 도는 Claude Code와 Telegram·Discord로 대화하고 싶을 때 — 예를 들어 휴대폰에서 작업을 던지거나, 저장소에 장기 실행 어시스턴트를 붙여 두고 싶을 때 — 터미널을 켜 두고 권한 프롬프트를 일일이 봐 주지 않아도 되게 해 준다. CCTG는 프로젝트마다 격리된 봇을 주고, 분리된 tmux 세션에서 계속 살아 있게 한다.

## 요구 사항

> **macOS 전용.** CCTG는 `caffeinate`(macOS 내장)에 의존하고 macOS 셸/도구 구조를 전제한다. Linux·WSL은 현재 **지원하지 않는다**.

| 의존성 | 용도 | 필수? |
|---|---|---|
| `claude` | Claude Code CLI — 각 봇이 실행하는 어시스턴트 | ✅ 필수 |
| `tmux` | 봇을 분리된 백그라운드 세션에서 실행 | ✅ 필수 |
| `caffeinate` | 봇 실행 중 Mac sleep 방지 | macOS 내장 |
| `jq` | `status --json`, `common` 구조적 편집, Discord `--group` 시드 | 선택 |
| 채널 플러그인 | Telegram/Discord 연동 — Claude Code에 전역 설치 | ✅ 사용하는 채널에 필수 |

설치 상세·PATH 설정·업데이트/제거는 **[docs/installation.ko.md](docs/installation.ko.md)** 참조.

## 빠른 시작

0에서 동작하는 봇까지 가장 빠른 경로. 예시는 **Telegram** 기준이며, Discord는 3단계를 **[docs/discord-setup.ko.md](docs/discord-setup.ko.md)** 로 대체한다.

### 1단계 — 사전 준비 설치

1. **Claude Code** 와 **tmux** 를 설치한다(예: `brew install tmux`). 선택으로 `brew install jq`.
2. 채널 플러그인을 **Claude Code 안에서 전역 설치**한다:

   ```text
   /plugin install telegram@claude-plugins-official
   ```

   (Discord는: `/plugin install discord@claude-plugins-official`.)

### 2단계 — CCTG 설치

```bash
git clone https://github.com/qwertygeon/cctg.git
cd cctg
./install.sh
```

`install.sh` 는 의존성을 점검하고 `cctg` 를 `~/.local/bin/cctg` 에 배치하며, 셸 자동완성을 설치하고, PATH·자동완성을 위한 관리 블록을 셸 rc에 추가한다. 재실행해도 안전하다. 그 뒤 새 터미널을 열거나(`source ~/.zshrc`) 확인한다:

```bash
cctg doctor
```

`~/.local/bin` 이 PATH에 없으면 설치 스크립트가 추가할 정확한 줄을 출력한다. 설치 모드(릴리스 vs `--dev`)·`BINDIR`·자동완성 등은 **[docs/installation.ko.md](docs/installation.ko.md)** 참조.

### 3단계 — 봇 만들고 연결하기

Telegram은 두 가지가 필요하다 — **봇 토큰** 과 **본인의 숫자 Telegram ID**:

1. [@BotFather](https://t.me/BotFather) 로 **새 봇 생성**: `/newbot` 을 보내고 이름·사용자명을 정한다. BotFather가 `123456789:ABCdef...` 형태의 **토큰** 을 준다. 반드시 새 봇이어야 한다(다른 곳에서 이미 도는 봇이면 안 됨).
2. **숫자 ID 확인**: [@userinfobot](https://t.me/userinfobot) 에 DM하면 본인의 숫자 사용자 ID를 알려준다.

이제 봇을 등록한다. `<name>` 은 임의 라벨(영숫자/`_`/`-`), `<dir>` 은 봇이 작업할 프로젝트 디렉터리다:

```bash
cctg add myproject ~/work/myproject
```

`add` 는 토큰(가림 입력)·숫자 ID·권한 모드를 차례로 묻는다. 상태 디렉터리를 만들고, 토큰을 `600` 권한으로 저장하며, `access.json` allowlist에 본인 ID를 시드한다 — 그래서 Telegram은 **별도 페어링 단계가 필요 없다**.

```console
$ cctg add myproject ~/work/myproject
Bot token (issued by @BotFather, must be a NEW bot): ********
Your Telegram numeric ID: 123456789
Permission mode [Enter=follow shared | acceptEdits auto bypassPermissions default dontAsk plan]:
Registered: myproject → cwd=/Users/you/work/myproject, state=/Users/you/.claude/channels/myproject
  seeded 123456789 into the allowlist (no pairing needed)
```

> CI용 비대화형 등록을 포함한 전체 안내: **[docs/telegram-setup.ko.md](docs/telegram-setup.ko.md)** · **[docs/discord-setup.ko.md](docs/discord-setup.ko.md)**.

### 4단계 — 봇 기동

```bash
cctg up myproject
```

분리된 tmux 세션(`cctg-myproject`)을 `caffeinate -is` 아래에서 띄워, 실행 중 Mac이 sleep에 들지 않게 한다.

```console
$ cctg up myproject
UP   myproject  (cwd=/Users/you/work/myproject, state=/Users/you/.claude/channels/myproject, tmux=cctg-myproject)
```

### 5단계 — 메시지 보내고 상태 확인

Telegram을 열고 새 봇에 DM하면 — 프로젝트 디렉터리에서 도는 Claude Code가 바로 응답한다. 언제든 확인할 수 있다:

```bash
cctg status            # 실행 중인지? 얼마나 됐는지? 어떤 모드/채널인지?
cctg logs myproject    # 최근 출력(봇 정지 후에도 동작)
cctg attach myproject  # 라이브 세션 보기(Ctrl-b d 로 detach)
```

끝이다. `cctg down myproject` 로 정지, `cctg restart myproject` 로 재기동한다.

> 💬 **봇은 채널로 답하도록 지시된다.** 봇이 터미널에서만 "생각"하지 않고 항상 채팅으로 답하도록, CCTG 는 모든 봇에 짧은 reply 리마인더를 `claude --append-system-prompt` 로 주입한다. **기본 ON** 이며 `~/.claude/channels/cctg-reply-reminder.txt` 에 시드된다. 문구를 바꾸려면 그 파일을 편집하고, 끄려면 비우면 된다. `cctg doctor` 가 ON/OFF 를 표시한다. 자세히: **[docs/configuration.ko.md → 채널 reply 리마인더](docs/configuration.ko.md#채널-reply-리마인더)**.

## 자주 쓰는 명령

```text
cctg <command> [args]
  add <name> <cwd> [--channel telegram|discord] [--id <num>]
                   [--token-env <VAR>|--token-stdin] [--mode <m>] [--group ...]
  rm <name> [--purge]      rename <old> <new> [--keep-dir]
  up <name...|all>         down <name...|all>       restart <name...|all>
  status [--json]          logs <name> [N]          attach <name>
  config <name> [...]      common [...]             lang [show|en|ko|clear]
  doctor    update    version    help
```

| 명령 | 하는 일 |
|---|---|
| `add` / `rm` / `rename` | 봇 등록·해제·이름 변경 |
| `up` / `down` / `restart` | 봇 기동 / 정지 / 재기동 — 여러 타겟(이름·`telegram`/`discord`·`all`) 한 번에 |
| `status` / `logs` / `attach` | 상태·가동시간 / 로그 조회 / 라이브 세션 attach |
| `config` / `common` | 봇별 옵션 / 공통 권한 정책 |
| `lang` | CLI 출력 언어 전환(영/한) |
| `doctor` / `update` / `version` | 환경 진단 / CCTG 업데이트 / 버전 출력 |

모든 명령과 플래그의 전체 레퍼런스는 **[docs/commands.ko.md](docs/commands.ko.md)** 에 있다.

## 권한 1분 요약

봇은 tmux에서 헤드리스로 도는 Claude Code TUI다 — 권한 프롬프트에 답할 사람이 없으므로 프롬프트가 뜨면 봇이 멈춘다. CCTG의 해법은 **"위험하지 않은 건 자동 승인, 위험한 건 deny 규칙으로 차단"** 이다.

- **공통 정책**(`cctg common`)은 모든 봇에 적용된다: 기본값은 `bypassPermissions` + deny 안전망(`sudo`, `rm -rf /`, force-push, `~/.ssh` 읽기 등)이다. deny 규칙과 PreToolUse 훅은 `bypassPermissions` 에서도 그대로 작동한다.
- **봇별 모드**(`cctg config <name> mode ...`)는 한 봇에 한해 공통 기본값을 덮어쓴다.

모든 모드·기본 deny 목록·강화 방법 등 전체 모델은 **[docs/permissions.ko.md](docs/permissions.ko.md)** 에 있다.

## 지원 채널

CCTG는 Claude Code의 **channels** 구조(`~/.claude/channels/`)를 따른다: 각 채널 플러그인은 전역 봇을 `~/.claude/channels/<채널>/` 에 두며, 프로세스별로는 그 플러그인의 `<CHANNEL>_STATE_DIR` 로 덮어쓸 수 있다.

| 채널 | Claude Code 플러그인 | CCTG 지원 |
|---|---|---|
| **Telegram** | `telegram@claude-plugins-official` | ✅ 지원 — [docs/telegram-setup.ko.md](docs/telegram-setup.ko.md) 참조 |
| **Discord** | `discord@claude-plugins-official` | ✅ 지원 — DM은 기본 페어링, 서버 채널은 `--group`; [docs/discord-setup.ko.md](docs/discord-setup.ko.md) 참조 |
| iMessage | `imessage@claude-plugins-official` | ⛔ 예정 — 이름 예약 |
| fakechat | `fakechat@claude-plugins-official` | ⛔ 비해당 — 이름 예약 |
| Slack | `slack@claude-plugins-official` | ➖ 범위 외 — tmux 호스팅 메시지 브리지가 아님 |

> CCTG는 `telegram`·`discord`·`imessage`·`fakechat` 이름을 **예약**하여, 프로젝트 봇이 전역 채널 봇의 토큰·allowlist를 덮어쓰지 못하게 한다. 또한 CCTG가 만들지 않은 채널 봇 상태가 이미 든 상태 디렉터리의 재사용을 거부한다. 채널 배선 방식(`channel_spec` descriptor)은 [docs/configuration.ko.md](docs/configuration.ko.md) 에서 다룬다.

## 문서

| 문서 | 내용 |
|---|---|
| [설치](docs/installation.ko.md) | 상세 설치·모드·PATH·자동완성·업데이트·제거 |
| [Telegram 설정](docs/telegram-setup.ko.md) | BotFather로 봇 만들기·ID 확인·단계별 연결 |
| [Discord 설정](docs/discord-setup.ko.md) | Discord 애플리케이션/봇·토큰·페어링·서버채널 `--group` |
| [명령어 레퍼런스](docs/commands.ko.md) | 모든 명령·플래그·예시 |
| [권한 정책](docs/permissions.ko.md) | 공통 정책 + 봇별 모드, deny/allow, 기본 deny 목록 |
| [설정·동작 원리](docs/configuration.ko.md) | CLI 언어, 환경변수/경로, 동작 방식, 로그 스냅샷 |

프로젝트 메타: [기여](CONTRIBUTING.md) · [보안 정책](SECURITY.md) · [변경 로그](CHANGELOG.md) · [패키징 구조](docs/packaging.md) · [릴리스](docs/RELEASING.md) · [TODO / 향후 작업](docs/TODO.md)

## 제거

```bash
./uninstall.sh
```

`cctg` 런처·자동완성·셸 rc 관리 블록·CCTG 자체 설정을 제거하지만, `~/.claude/channels/` 하위의 레지스트리·상태 디렉터리는 **건드리지 않는다** — 따라서 봇 등록·토큰은 재설치해도 보존된다. 상세는 [docs/installation.ko.md](docs/installation.ko.md#제거) 참조.

## 기여 & 라이선스

기여는 환영한다 — [CONTRIBUTING.md](CONTRIBUTING.md) 참조. 버전은 저장소 루트의 `VERSION` 파일이 단일 소스(SoT)이며 `cctg version` 으로 확인한다. `cctg update` 는 전/후 버전을 함께 보여준다. 라이선스는 [MIT](LICENSE).
