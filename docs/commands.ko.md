[English](commands.md) | **한국어**

# 명령어 레퍼런스

> `cctg` 의 전체 CLI 레퍼런스 — 모든 명령어·플래그·동작을 소스 기준으로 검증하여 기술한다.

## 목차

- [개요](#개요)
- [표기 규약](#표기-규약)
- [봇 라이프사이클](#봇-라이프사이클)
  - [`add`](#add)
  - [`rm`](#rm)
  - [`rename`](#rename)
- [실행 제어](#실행-제어)
  - [`up`](#up)
  - [`down`](#down)
  - [`restart`](#restart)
- [관찰](#관찰)
  - [`status`](#status)
  - [`logs`](#logs)
  - [`attach`](#attach)
- [설정](#설정)
  - [`config`](#config)
    - [config cwd](#config-cwd)
    - [config token](#config-token)
  - [`common`](#common)
  - [`lang`](#lang)
- [유지보수](#유지보수)
  - [`doctor`](#doctor)
  - [`update`](#update)
  - [`version`](#version)
  - [`help`](#help)
- [참고](#참고)

## 개요

```
cctg <command> [args]
  add <name> <cwd> [--channel telegram|discord] [--id <num>] [--token-env <VAR>|--token-stdin] [--mode <m>] [--group <id>[:nomention][:allow=m1,m2]]
  rm <name> [--purge]          rename <old> <new> [--keep-dir]
  config <name> [show|edit|mode <m|clear>|args <str>|snapshot <초|off>|cwd <경로>|token]
  common [...]
  up <name|all|telegram|discord>    down <name|all|telegram|discord>
  restart <name|all|telegram|discord>
  status [--json]              logs <name|telegram|discord> [N]          attach <name>
  lang [show|en|ko|clear]
  doctor    update    version    help
```

하나의 봇은 한 프로젝트의 Claude Code 채널 세션이다. 즉 작업 디렉터리 하나, 토큰·접근 정책을 가진 채널 하나(Telegram 또는 Discord), 그리고 `cctg-<name>` 이라는 이름의 detached `tmux` 세션으로 구성된다. 예약 이름 `telegram`·`discord` 로는 전역 채널 봇을 기동·정지·관찰할 수 있게 되었다.

모든 서브커맨드는 `--help`(`-h`) 를 받아 한 줄 사용법을 출력하고 종료 코드 `0` 으로 끝난다.

## 표기 규약

- **봇 이름**에는 `[A-Za-z0-9_-]` 만 쓸 수 있다. `telegram`, `discord`, `imessage`, `fakechat` 은 **예약 이름**이다. `add`, `rm`, `rename` 은 예약 이름을 거부한다. 단, `telegram`·`discord` 는 `up`, `down`, `restart`, `status`, `logs` 에서 전역 봇 제어에 사용할 수 있다([실행 제어](#실행-제어) 참조).
- CLI 는 **이중 언어**(영어 / 한국어)다. 아래 예시는 영어 출력이며, [`lang`](#lang) 으로 전환한다.
- 예시의 경로·숫자 ID·토큰은 **자리표시자**이므로 실제 값으로 바꾼다.
- `version`/`-v`/`--version` 과 `help`/`-h`/`--help`/인자 없음은 각각 `version`·`help` 의 별칭이다.
- 모든 서브커맨드는 `--help`(`-h`) 를 받아 사용법 한 줄을 출력하고 종료 코드 `0` 으로 끝난다.

## 봇 라이프사이클

### `add`

```
cctg add <name> <cwd> [--channel telegram|discord] [--id <num>] [--token-env <VAR>|--token-stdin] [--mode <m>] [--group <id>[:nomention][:allow=m1,m2]]
```

작업 디렉터리 `<cwd>` 에 대한 새 봇을 등록하고 상태 디렉터리를 `~/.claude/channels/<name>/` 에 스캐폴딩한다. 상태 디렉터리에는 봇 토큰(`.env`, 권한 `600`), 접근 정책(`access.json`), `inbox/`, 봇별 옵션(`launch.env`) 이 들어간다.

`add` 는 **기본적으로 대화형**이다 — 토큰(가림 입력), 채널 ID, 권한 모드를 프롬프트로 묻는다. `--token-env` 나 `--token-stdin` 을 주면 **비대화형 모드**로 전환되어 아무것도 묻지 않는다. 이때 Telegram 은 `--id` 도 함께 줘야 하며, 권한 모드는 `--mode` 를 주지 않으면 공통 정책을 따른다.

채널 동작은 `--channel`(기본 `telegram`) 에 따라 다르다.

- **Telegram** — ID 가 필수다(비대화형에서는 `--id` 로). 준 ID 가 allowlist 를 시드하므로(DM 정책 `allowlist`, `allowFrom: ["<id>"]`) 페어링이 필요 없다.
- **Discord** — ID 는 선택이다. ID 없이 추가하면 봇이 `pairing` DM 정책과 빈 allowlist 로 시작하므로, 이후 채널에서 페어링한다.

최초 설정 전체 절차는 [telegram-setup.md](telegram-setup.md) 와 [discord-setup.md](discord-setup.md) 를 참조한다.

플래그:

| 플래그 | 의미 |
|---|---|
| `--channel telegram\|discord` | 채널 타입. 기본 `telegram`. |
| `--id <num>` | 숫자 채널 ID. 비대화형 Telegram 에서는 필수, Discord 에서는 선택. `^[0-9]+$` 를 통과해야 한다. |
| `--token-env <VAR>` | 환경 변수 `VAR` 에서 봇 토큰을 읽는다. 비대화형 모드로 전환된다. 토큰은 `argv` 로 전달하지 않는다(프로세스 목록에 노출되므로). |
| `--token-stdin` | stdin 에서 봇 토큰을 읽는다. 비대화형 모드로 전환된다. |
| `--mode <m>` | 권한 모드: `acceptEdits`, `auto`, `bypassPermissions`, `default`, `dontAsk`, `plan`. |
| `--group <id>[:nomention][:allow=csv]` | Discord 서버 채널 접근(반복 가능). `id` 는 숫자여야 하고, `:nomention` 은 멘션 요구를 해제하며, `:allow=csv` 는 쉼표로 구분한 숫자 멤버 ID 목록이다. `jq` 가 필요하다. |

```console
$ cctg add proj ~/code/proj --channel telegram --id 123456789 --token-env PROJ_BOT_TOKEN --mode acceptEdits
$ cctg add gamebot ~/code/game --channel discord --token-stdin --group 555000111:nomention:allow=42,43
```

### `rm`

```
cctg rm <name> [--purge]
```

봇을 등록 해제한다. 기본적으로 **상태 디렉터리는 유지**되어 토큰·allowlist 를 나중에 재사용할 수 있으며, 레지스트리 항목만 제거된다. 실행 중인 봇은 먼저 [`down`](#down) 으로 정지해야 한다 — 실행 중이면 `rm` 이 거부한다.

`--purge` 는 상태 디렉터리도 삭제하지만, 그것이 `~/.claude/channels/` 하위이고 예약 전역 채널 디렉터리가 아닐 때만 삭제한다. `CHANNELS_DIR` 바깥 경로나 전역 채널 디렉터리는 절대 삭제하지 않는다(대신 안내가 출력된다).

```console
$ cctg rm proj
$ cctg rm proj --purge
```

### `rename`

```
cctg rename <old> <new> [--keep-dir]
```

봇 이름을 변경한다. 새 이름은 유효해야 하고 이미 등록되어 있지 않아야 한다. 실행 중인 봇은 먼저 정지해야 한다 — `tmux` 세션 이름(`cctg-<name>`) 이 봇 이름에서 파생되므로 실행 중이면 `rename` 이 거부한다.

기본적으로 상태 디렉터리도 함께 이동하지만, **기본 경로** `~/.claude/channels/<old>/` 에 있을 때만 이동한다. 이동 대상은 이미 존재해선 안 된다. 커스텀 상태 디렉터리 경로이거나 `--keep-dir` 를 주면 등록 이름과 `tmux` 세션 이름만 변경되고 디렉터리는 그대로 둔다.

```console
$ cctg rename proj proj-archived
$ cctg rename proj proj2 --keep-dir
```

## 실행 제어

### `up`

```
cctg up <name|all|telegram|discord>
```

`cctg-<name>` 이름의 detached `tmux` 세션에서 봇을 기동한다. 세션은 `caffeinate -is claude --channels <plugin> --settings <shared> [--permission-mode <mode>] [추가 인자]` 를 실행하며, 채널의 상태 디렉터리는 환경 변수(`TELEGRAM_STATE_DIR` / `DISCORD_STATE_DIR`) 로 주입된다. 공통 권한 정책은 `--settings` 로 주입되고, 봇별 `CCTG_PERMISSION_MODE`(`launch.env`) 가 공통 `defaultMode` 를 override 하며, `CLAUDE_EXTRA_ARGS` 가 뒤에 덧붙는다.

작업 디렉터리와 봇의 `.env`(토큰) 가 존재해야 하며, 없으면 `up` 이 오류를 보고한다. 봇에 `CCTG_LOG_SNAPSHOT_INTERVAL` 이 설정되어 있으면 주기 스냅샷 watcher 도 함께 기동된다. `cctg up all` 은 등록된 모든 봇을 기동한다.

**전역 채널 봇 (`telegram` / `discord`)**: 예약 이름을 전달하면 레지스트리 없이 `~/.claude/channels/<channel>/` 을 상태 디렉터리로 사용한다. 작업 디렉터리(`cwd`)는 `cctg up` 실행 시점의 현재 디렉터리(`$PWD`)다. **단독소유자 가드**: `cctg-<channel>` tmux 세션이 이미 존재하거나 상태 디렉터리의 `bot.pid` 에 살아 있는 PID 가 있으면(플러그인 러너 활성) 기동을 거부한다. `.env` 가 없어도 거부한다.

```console
$ cctg up proj
$ cctg up all
$ cctg up telegram
$ cctg up discord
```

### `down`

```
cctg down <name|all|telegram|discord>
```

봇을 정지한다. `tmux` 세션을 종료하기 전에 세션 화면 스냅샷을 `<state>/last-session.log` 에 저장하여(정지 후에도 [`logs`](#logs) 가 동작하도록) 두고, 실행 중인 스냅샷 watcher 가 있으면 정지한다. `cctg down all` 은 등록된 모든 봇을 정지한다. 이미 정지된 봇을 정지해도 남아 있는 스냅샷 watcher PID 파일을 정리한다.

**전역 채널 봇 (`telegram` / `discord`)**: `cctg-<channel>` tmux 세션만 종료한다. 채널 플러그인 자체의 러너(`bot.pid` 프로세스)는 종료 대상이 아니다 — 세션이 없을 때 이 한계를 출력 메시지로 안내한다.

```console
$ cctg down proj
$ cctg down all
$ cctg down telegram
```

### `restart`

```
cctg restart <name|all|telegram|discord>
```

`down` 후 `up`. 실행 중인 봇에 설정 변경(권한 모드·추가 인자·스냅샷 주기·공통 정책)을 적용할 때 사용한다. 예약 이름 `telegram`·`discord` 를 써서 전역 채널 봇을 재기동할 수 있다.

```console
$ cctg restart proj
$ cctg restart telegram
```

## 관찰

### `status`

```
cctg status [--json]
```

봇별 상태를 출력한다. 각 봇에 대해 상태 — `RUNNING`(가동 시간 포함) / `stopped` / `BROKEN` — 와 작업·상태 디렉터리 경로, 권한 모드(또는 `shared`), 채널을 보여준다. `jq` 가 있고 `access.json` 이 존재하면 채널 행에 DM 정책과 그룹 항목 수(토폴로지)도 표시한다.

봇은 등록되어 있으나 작업 디렉터리가 없거나 `.env`(토큰) 가 없으면 `BROKEN` 이며, 사유별 복구 힌트가 출력된다.

상태 디렉터리(`~/.claude/channels/<channel>/`)가 존재하는 예약 채널에 대해서는 `--- 전역 채널 봇 ---` 섹션이 이어서 출력된다. 전역 봇의 `cwd` 는 `cctg status` 를 실행한 시점의 현재 디렉터리다(전역 봇은 레지스트리에 작업 디렉터리가 없으므로).

`--json` 은 로케일 무관 토큰으로 구성된 기계 판독용 객체 배열을 출력한다(`jq` 필요). 각 객체는 `name`, `state`(`running`/`stopped`/`broken`), `running`(불리언), `cwd`, `stateDir`, `mode`, `channel`, `session`, `uptimeSeconds`(또는 `null`), `issues`(예: `no-cwd`, `no-token`) 를 가진다.

```console
$ cctg status
$ cctg status --json
```

```json
[
  {
    "name": "proj",
    "state": "running",
    "running": true,
    "cwd": "/Users/me/code/proj",
    "stateDir": "/Users/me/.claude/channels/proj",
    "mode": "acceptEdits",
    "channel": "telegram",
    "session": "cctg-proj",
    "uptimeSeconds": 3600,
    "issues": []
  }
]
```

### `logs`

```
cctg logs <name|telegram|discord> [N]
```

최근 `N` 줄의 로그를 출력한다(기본 `50`). 봇이 실행 중이면 라이브 `tmux` 화면을 읽는다(스크롤백 최대 2000줄). 정지 상태에서는 `<state>/last-session.log` 스냅샷([`down`](#down) 시 또는 주기 스냅샷터가 기록) 으로 대체한다. 정지 상태인데 스냅샷이 없으면 오류를 보고한다.

예약 이름 `telegram`·`discord` 를 써서 `~/.claude/channels/<channel>/` 의 전역 봇 로그를 읽을 수 있다.

```console
$ cctg logs proj
$ cctg logs proj 200
$ cctg logs telegram
```

### `attach`

```
cctg attach <name>
```

봇의 라이브 `tmux` 세션에 attach 하여 대화형으로 본다. 분리는 `Ctrl-b d`. 실행 중인 세션이 필요하다.

```console
$ cctg attach proj
```

## 설정

### `config`

```
cctg config <name> [show | edit | mode <m|clear> | args <str> | snapshot <초|off> | cwd <경로> | token [--token-env <VAR>|--token-stdin]]
```

`<state>/launch.env` 에 저장되는 봇별 옵션을 보거나 수정한다. 변경은 다음 [`up`](#up) / [`restart`](#restart) 시 적용되며, 봇이 실행 중이면 `cctg` 가 재기동을 안내한다.

| 동작 | 의미 |
|---|---|
| `show`(기본) | 채널, 권한 모드, 스냅샷 주기, `launch.env` 내용을 출력한다. |
| `edit` | `$EDITOR`(기본 `vi`) 로 `launch.env` 를 연다. |
| `mode <m>` | `CCTG_PERMISSION_MODE` 를 설정한다(`acceptEdits`, `auto`, `bypassPermissions`, `default`, `dontAsk`, `plan` 중 하나). |
| `mode clear` | 모드를 비워 봇이 공통 `defaultMode` 를 따르게 한다. |
| `args <str>` | `CLAUDE_EXTRA_ARGS` 를 설정한다. 예: `"--model opus"`. |
| `snapshot <초>` | `<초>` 초마다 주기 로그 스냅샷을 켠다(최소 `5`). |
| `snapshot off` | 주기 스냅샷을 끈다(`0` 도 허용, off 가 기본). |
| `cwd <경로>` | <a name="config-cwd"></a>레지스트리의 봇 작업 디렉터리를 변경한다. 경로가 실제로 존재해야 한다. 봇이 실행 중이면 재기동 안내가 출력된다. |
| `token` | <a name="config-token"></a>`<state>/.env` 의 토큰을 교체한다(권한 `600`). `--token-env <VAR>`, `--token-stdin`, 또는 대화형 가림 입력을 받는다. 토큰 키(`TELEGRAM_BOT_TOKEN` / `DISCORD_BOT_TOKEN`)는 봇의 채널로 결정된다. 봇이 실행 중이면 재기동 안내가 출력된다. |

권한 모델 자체는 [permissions.md](permissions.md) 를 참조한다.

```console
$ cctg config proj
$ cctg config proj mode bypassPermissions
$ cctg config proj args "--model opus"
$ cctg config proj snapshot 60
$ cctg config proj snapshot off
$ cctg config proj cwd ~/new/path/to/proj
$ cctg config proj token --token-stdin
$ cctg config proj token --token-env NEW_BOT_TOKEN
```

### `common`

```
cctg common [show | edit | mode <m> | deny add|rm <rule> | allow add|rm <rule>]
```

`--settings` 로 모든 봇에 주입되는 공통 권한 정책을 보거나 수정한다. 파일은 첫 `add`/`up` 시 자동 생성된다. `mode`·`deny`·`allow` 동작은 `jq` 가 필요하다.

| 동작 | 의미 |
|---|---|
| `show`(기본) | 공통 설정 파일을 출력한다. |
| `edit` | `$EDITOR` 로 파일을 연다. |
| `mode <m>` | `permissions.defaultMode` 를 설정한다. |
| `deny add <rule>` / `deny rm <rule>` | deny 규칙을 추가/제거한다. 예: `Bash(sudo *)`. |
| `allow add <rule>` / `allow rm <rule>` | allow 규칙을 추가/제거한다. |

전체 권한 모델은 [permissions.md](permissions.md) 를 참조한다.

```console
$ cctg common
$ cctg common mode default
$ cctg common deny add "Bash(sudo *)"
$ cctg common allow add "Read(~/notes/**)"
```

### `lang`

```
cctg lang [show | en | ko | clear]
```

CLI 출력 언어를 제어한다. `show`(기본) 는 현재 언어와 그 출처(env, config, 자동 감지, 기본값) 를 보고한다. `en`/`ko` 는 `~/.config/cctg/config` 에 설정을 영구 저장한다. `clear` 는 설정을 제거하여 언어가 자동 감지(`LC_ALL`/`LANG` 기반) 로 돌아가게 한다. [configuration.md](configuration.md) 를 참조한다.

```console
$ cctg lang
$ cctg lang ko
$ cctg lang clear
```

## 유지보수

### `doctor`

```
cctg doctor
```

환경을 진단한다. 의존성(`tmux`, `claude`, `caffeinate`, `jq`), `~/.local/bin` 의 `PATH` 등재 여부, 레지스트리 파일과 봇 개수, 공통 권한 정책(`defaultMode`, deny/allow 개수) 을 확인한다. 또한 채널 플러그인을 전역으로 설치하라고 안내한다.

```console
$ cctg doctor
```

### `update`

```
cctg update
```

레포에서 `git pull --ff-only` 를 실행한 뒤 `install.sh` 를 재실행(멱등) 하고, 이전 → 새 버전을 출력한다. [installation.md](installation.md) 를 참조한다.

```console
$ cctg update
```

### `version`

```
cctg version
cctg --version
cctg -v
```

버전을 출력한다(`VERSION` 파일 기준).

```console
$ cctg version
```

### `help`

```
cctg help
cctg --help
cctg -h
cctg
```

사용법 요약을 출력한다(인자 없이 실행해도 동일하게 표시된다).

```console
$ cctg help
```

## 참고

- [permissions.md](permissions.md) — 공통 권한 정책과 봇별 모드.
- [configuration.md](configuration.md) — `launch.env`, 공통 설정, 언어, 경로.
- [telegram-setup.md](telegram-setup.md) — Telegram 채널 최초 설정.
- [discord-setup.md](discord-setup.md) — Discord 채널 최초 설정.

[← README 로 돌아가기](../README.md)
