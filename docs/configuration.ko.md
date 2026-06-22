[English](configuration.md) | **한국어**

# 설정·동작 원리

> CCTG 가 CLI 언어를 결정하는 방식, 읽어 들이는 환경 변수와 경로, 봇이 기동되는 방식, 로그 스냅샷을 캡처하는 방식을 설명한다.

## 목차

- [CLI 언어](#cli-언어)
  - [결정 순서](#결정-순서)
  - [선호 설정 관리](#선호-설정-관리)
  - [언어 중립 텍스트](#언어-중립-텍스트)
- [환경 변수·경로](#환경-변수경로)
  - [환경 변수](#환경-변수)
  - [봇별 채널 상태 env](#봇별-채널-상태-env)
  - [주요 파일](#주요-파일)
- [동작 원리(아키텍처)](#동작-원리아키텍처)
  - [레지스트리](#레지스트리)
  - [상태 격리](#상태-격리)
  - [공통 권한 정책](#공통-권한-정책)
  - [채널 reply 리마인더](#채널-reply-리마인더)
  - [tmux 세션](#tmux-세션)
  - [`up` 기동 라인](#up-기동-라인)
  - [채널](#채널)
- [로그 스냅샷](#로그-스냅샷)
  - [정상 `down` 시 스냅샷](#정상-down-시-스냅샷)
  - [주기 스냅샷(옵트인)](#주기-스냅샷옵트인)

## CLI 언어

CLI 는 메시지를 영어 또는 한국어로 출력한다.

### 결정 순서

언어는 다음 순서로 결정되며, 먼저 일치하는 항목이 우선한다.

1. `CCTG_LANG` 환경 변수 — 일회성 오버라이드. 예: `CCTG_LANG=ko cctg status`.
2. `~/.config/cctg/config` 의 `lang` 값(`cctg lang` 으로 설정).
3. 로케일 자동 감지(`$LC_ALL` / `$LANG`; `ko*` 또는 `*_KR*` → 한국어, 그 외 → 영어).
4. 기본값: 영어.

### 선호 설정 관리

```bash
cctg lang            # 현재 언어와 그 출처를 표시한다
cctg lang ko         # 한국어로 영구 전환한다 (~/.config/cctg/config 기록)
cctg lang en         # 영어로 영구 전환한다
cctg lang clear      # 선호 설정을 제거한다 (자동 감지로 복귀)
```

설치 시점에 `./install.sh --lang en|ko` 로 초기 언어를 선택한다. 선호 설정은 설치 매니페스트(`~/.config/cctg/install.conf`)와 분리된 `~/.config/cctg/config` 에 저장되므로, `cctg update` 가 이를 보존한다. 메시지 카탈로그는 런처 옆에 `messages/en.sh` 와 `messages/ko.sh` 로 함께 배포된다.

### 언어 중립 텍스트

일부 텍스트는 결정된 언어와 무관하게 언어 중립으로 유지된다. 생성된 `launch.env` 주석, 필수 인자 누락 오류, zsh 자동완성 설명이 이에 해당한다.

## 환경 변수·경로

### 환경 변수

| 변수 | 기본값 | 의미 |
|---|---|---|
| `CC_CHANNELS_DIR` | `~/.claude/channels` | 채널 상태 루트 |
| `CC_TG_REGISTRY` | `$CC_CHANNELS_DIR/projects.conf` | 레지스트리 파일 |
| `CC_TG_SHARED_SETTINGS` | `$CC_CHANNELS_DIR/cctg-shared.settings.json` | 공통 권한 정책 파일 |
| `CC_TG_REPLY_REMINDER_FILE` | `$CC_CHANNELS_DIR/cctg-reply-reminder.txt` | 모든 봇에 주입되는 채널 reply 리마인더 텍스트 |
| `CC_TG_SESS_WIDTH` | (미설정) | detached 세션 폭(칼럼) 오버라이드. `cctg common width` 전역 기본값보다 우선 |
| `CCTG_LANG` | (미설정) | 일회성 CLI 언어 오버라이드(`en`/`ko`) |
| `BINDIR` | `~/.local/bin` | 설치 위치(`install.sh` / `uninstall.sh`) |
| `CCTG_LIBEXEC` | `~/.local/libexec/cctg` | 복사 설치 패키지 디렉터리(`install.sh`) |

### 봇별 채널 상태 env

각 봇은 채널의 상태 디렉터리 env — `TELEGRAM_STATE_DIR` 또는 `DISCORD_STATE_DIR`(채널 descriptor 에서 해석) — 가 `~/.claude/channels/<name>/` 를 가리킨 상태로 기동된다. 따라서 전역 채널 봇이나 다른 프로젝트 봇과 절대 섞이지 않는다.

### 주요 파일

설치 단위:

- 런처 `~/.local/bin/cctg`
- 복사 설치 패키지 `~/.local/libexec/cctg/`
- 매니페스트 `~/.config/cctg/install.conf`
- 사용자 설정 `~/.config/cctg/config` (`lang` 과 전역 기본 `sess_width` 보관)

봇별 상태 디렉터리 `~/.claude/channels/<name>/` 의 구성:

- `.env`(토큰, `chmod 600`)
- `access.json`(allowlist / 그룹)
- `launch.env`(봇별 옵션)
- `inbox/`
- 정지 후의 `last-session.log`(`chmod 600`)

실행 중인 주기 스냅샷터는 자신의 PID 를 `.snapshotter.pid` 로 추적한다.

## 동작 원리(아키텍처)

### 레지스트리

레지스트리 `~/.claude/channels/projects.conf` 는 봇당 한 줄을 저장한다.

```
name | working_dir | state_dir | channel
```

4번째 컬럼은 채널 타입이며, 레거시 3컬럼 행은 `telegram` 으로 기본 처리된다.

### 상태 격리

봇별 상태는 `~/.claude/channels/<name>/` 아래에 격리된다. 각 봇은 별도의 채널 `STATE_DIR` env 를 받으므로 상태가 절대 섞이지 않는다.

### 공통 권한 정책

공통 권한 정책(`cctg-shared.settings.json`)은 `claude --settings` 를 통해 모든 봇에 주입된다.

### 채널 reply 리마인더

모든 봇은 **매 턴** 채널의 reply 도구로(그리고 `reply_to` 로 quote-reply 하여) 답하도록 상기된다. 봇의 터미널/전사 출력은 사용자에게 전달되지 않기 때문이다. 이로써 봇이 답장을 보내지 않은 채 "혼잣말"만 하는 상황을 막는다.

- **위치**: 평문 파일 `~/.claude/channels/cctg-reply-reminder.txt`. 봇을 처음 `add`/`up` 할 때 기본 문구로 시드된다.
- **적용 방식**: `up` 시 CCTG 가 파일 내용을 `claude --append-system-prompt` 로 전달한다([`up` 기동 라인](#up-기동-라인) 참조). **기본 ON**.
- **편집**: 파일을 수정하면 된다. CCTG 는 파일이 없을 때만 작성하므로 사용자 수정은 업그레이드에도 보존된다.
- **비활성(opt-out)**: 파일을 비운다(`: > ~/.claude/channels/cctg-reply-reminder.txt`). 빈 파일은 그대로 유지되고 주입을 건너뛴다. 삭제하면 다음 `up` 에 기본 문구가 재시드되므로, 삭제가 아니라 비워라.
- **적용 범위**: CCTG 봇 세션에만 영향. 사용자의 일반 `claude` 사용에는 영향 없다.
- `cctg doctor` 가 리마인더 ON/OFF 를 표시한다.

> **왜 settings 훅이 아닌가?** 초기 설계는 `cctg-shared.settings.json` 에 `UserPromptSubmit` 훅을 넣는 것이었다. 그러나 Claude Code 는 `--settings` 파일의 `hooks` 키가 전역 `~/.claude/settings.json` 의 hooks 와 병합되는지 대체되는지 문서화하지 않는다. 대체라면 모든 봇 세션(`bypassPermissions` 로 실행)이 전역 hooks — `git-guard` 류 `PreToolUse` 안전망 포함 — 를 잃는다. `--append-system-prompt` 는 hooks 를 건드리지 않아 이 위험이 없다.

### tmux 세션

tmux 세션 이름은 `cctg-<name>` 규약을 따른다. 세션은 detached 라 tmux 가 폭을 80 칼럼으로 제한해 `logs`/snapshot 캡처가 잘릴 수 있어, CCTG 는 `new-session -x` 로 폭을 고정한다. 유효 폭은 다음 순서로 해석한다(첫 유효값 채택): 봇별 `CCTG_SESS_WIDTH`(`cctg config <name> width`) → env `CC_TG_SESS_WIDTH` → 전역 기본 `sess_width`(`cctg common width`, `~/.config/cctg/config`) → 내장 기본값 `100`. 각 후보는 20 이상의 정수여야 한다.

### `up` 기동 라인

`up` 시 런처는 대략 다음을 수행한다.

1. `cd <cwd>`
2. 채널 `STATE_DIR` export
3. `.env`(토큰)와 `launch.env`(옵션) source
4. 분리된 tmux 세션 안에서 다음을 실행:

```bash
caffeinate -is claude --channels <plugin> --settings <shared> [--permission-mode <mode>] \
  [--append-system-prompt "$(cat <reply-reminder>)"] [$CLAUDE_EXTRA_ARGS]
```

`caffeinate -is` 는 봇이 실행되는 동안 시스템이 잠들지 않도록 막는다. `--append-system-prompt` 플래그는 [reply 리마인더](#채널-reply-리마인더) 파일이 비어 있지 않을 때만 추가된다.

### 채널

채널은 `lib/channels.sh` 의 `channel_spec`(8개 필드)로 기술된다. `telegram` 과 `discord` 가 구현되어 있으며, `imessage` / `fakechat` 이름은 예약되어 있다.

## 로그 스냅샷

### 정상 `down` 시 스냅샷

정상 `down` 시 CCTG 는 tmux 페인의 스냅샷(렌더 텍스트, 스크롤백 최대 약 2000줄)을 `<state>/last-session.log`(`chmod 600`)로 저장한다. 따라서 봇이 정지된 뒤에도 `cctg logs` 가 계속 동작한다(이 스냅샷으로 폴백한다). `attach` 는 여전히 실행 중인 세션이 필요하다. 스냅샷에는 대화 내용이 포함될 수 있으므로, `0700` 상태 디렉터리의 나머지 파일과 동일하게 취급한다.

### 주기 스냅샷(옵트인)

크래시나 재부팅은 `down` 을 실행하지 않으므로, 이를 대비하려면 봇별로 주기 스냅샷을 활성화한다(옵트인, 기본 off).

```bash
cctg config myproject snapshot 60    # 실행 중 60초마다 스냅샷 (최소 5)
cctg config myproject snapshot off   # 비활성화 (기본값)
```

봇이 실행되는 동안 가벼운 백그라운드 watcher 가 N초마다 페인을 동일한 `last-session.log` 로 다시 캡처하고, 세션이 끝나면 자동으로 종료한다. 크래시/재부팅 이후에는 `cctg logs` 가 가장 최근 스냅샷(최대 N초 이내로 오래된 상태)을 보여준다. `restart` 는 변경된 간격을 적용한다.

---

[← README 로 돌아가기](../README.md)

함께 보기: [commands.ko.md](commands.ko.md) · [permissions.ko.md](permissions.ko.md) · [installation.ko.md](installation.ko.md)
