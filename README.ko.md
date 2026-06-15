[English](README.md) | **한국어**

# CCTG — Claude Code Tmux Gateway

**CCTG**(Claude Code Tmux Gateway)는 macOS에서 **tmux + Claude Code + Telegram 게이트웨이**를 묶어, 프로젝트별 Claude Code 텔레그램 채널 봇을 쉽게 띄우고 관리하는 런처다. 명령은 `cctg` 다.

전역 봇(`~/.claude/channels/telegram/`)은 건드리지 않는다. 프로젝트 봇은 각자 상태 디렉터리·토큰·작업 디렉터리를 갖고 격리된 tmux 세션에서 돈다.

> **지원 채널 범위** — CCTG의 상태 디렉터리는 Claude Code의 **channels**(`~/.claude/channels/`) 구조를 따른다. **현재 연동 가능한 게이트웨이는 Telegram 하나뿐**이다. Claude Code가 channels 기능으로 제공하는 다른 게이트웨이(예: Slack·Discord 등)는 **추후 모두 지원할 예정**이다. 그때까지 `cctg`의 `add`/`up` 등 명령은 Telegram 봇만 대상으로 한다.

> ⚠️ **프라이버시 — 데이터 흐름 고지** — CCTG는 텔레그램으로 받은 메시지를 봇의 작업 디렉터리에서 실행되는 Claude Code로 중계하며, Claude Code는 그 내용을 처리를 위해 **Anthropic API로 전송**한다. 즉 봇과 주고받는 대화·코드·파일 내용이 제3자(Anthropic) 및 텔레그램 인프라를 거친다. 민감 정보를 다루는 저장소에 봇을 붙일 때는 이 점을 고려하고, `access.json` allowlist로 접근 주체를 본인(또는 신뢰된 사용자)으로 엄격히 제한하라.

> ℹ️ **비공식 도구** — CCTG는 Anthropic이 만들거나 보증하지 않은 **비공식 서드파티 도구**다. "Claude Code"·"Claude" 는 Anthropic의 상표이며, 본 프로젝트는 Anthropic과 무관하다.

## 목차

- [요구 사항](#요구-사항)
- [설치](#설치)
  - [설치 모드](#설치-모드)
  - [PATH 설정](#path-설정)
- [사용법](#사용법)
  - [1. 봇 등록·해제 (add / rm)](#1-봇-등록해제-add--rm)
  - [2. 봇 기동·정지·재기동 (up / down / restart)](#2-봇-기동정지재기동-up--down--restart)
  - [3. 상태 확인·로그 (status / logs / attach)](#3-상태-확인로그-status--logs--attach)
  - [4. 진단 (doctor)](#4-진단-doctor)
- [프로젝트별 claude 옵션](#프로젝트별-claude-옵션)
- [업데이트](#업데이트)
- [동작 방식](#동작-방식)
- [제거](#제거)
- [더 보기](#더-보기)

## 요구 사항

| 의존성 | 용도 | 비고 |
|---|---|---|
| `claude` | Claude Code CLI | 필수 |
| `tmux` | 봇을 detached 세션으로 구동 | 필수 |
| `caffeinate` | 구동 중 시스템 sleep 방지 | macOS 기본 제공 |
| `jq` | `cctg common` 의 구조화된 권한 정책 수정 | 선택(없으면 `common edit` 로 직접 편집) |
| telegram 플러그인 | Telegram 채널 연동 | 전역 설치 필요: `/plugin install telegram@claude-plugins-official` |

## 설치

```bash
git clone https://github.com/qwertygeon/cctg.git
cd cctg
./install.sh
```

`install.sh` 는 의존성을 점검하고 `cc-tg.sh` 를 `~/.local/bin/cctg` 로 배치한다. 재실행해도 안전하다(idempotent).

### 설치 모드

| 명령 | 동작 | 용도 |
|---|---|---|
| `./install.sh` | `cc-tg.sh` 를 `~/.local/bin/cctg` 로 **복사** | 릴리스. 레포를 지우거나 옮겨도 동작. 업데이트는 `git pull` 후 재설치 |
| `./install.sh --dev` | `~/.local/bin/cctg` 를 레포의 `cc-tg.sh` 로 **심볼릭 링크** | 개발. 레포 수정 즉시 반영 |

설치 시 다음이 자동 처리된다.

- **셸 자동완성(bash/zsh)** 설치 — `--no-completions` 로 생략
- **셸 rc 자동 설정** — 현재 셸의 rc(`~/.zshrc` 또는 `~/.bashrc`·`~/.bash_profile`)에 PATH·자동완성 활성화를 담은 **관리 블록**(`# >>> cctg >>>` ~ `# <<< cctg <<<`)을 멱등하게 추가한다. 최초 1회 `.cctg-bak` 백업을 남기고, 재실행해도 중복되지 않으며, `uninstall.sh` 가 블록만 깔끔히 제거한다. `--no-shell-setup` 으로 생략 가능.

적용하려면 새 터미널을 열거나 `source ~/.zshrc`(해당 rc) 한다. 설치 위치는 `BINDIR` 로 바꿀 수 있다: `BINDIR=~/bin ./install.sh`

### PATH 설정

`~/.local/bin` 이 PATH에 없으면 `install.sh` 가 셸에 맞는 추가 명령을 안내한다. 예 (zsh):

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
```

설치 후 확인:

```bash
cctg status
```

## 사용법

```
cctg <command> [args]
  add <name> <cwd>      rm <name> [--purge]   rename <old> <new> [--keep-dir]
  config <name> [...]   common [...]          (권한·옵션 — 아래 「권한·옵션」 절)
  up <name|all>         down <name|all>       restart <name|all>
  status                logs <name> [N]       attach <name>
  doctor                update                version           help
```

> 봇 이름은 영문/숫자/`_`/`-` 만 허용한다(tmux 세션명·레지스트리 구분자 충돌 방지). `telegram` 은 전역 봇 예약 이름이라 쓸 수 없다.

### 1. 봇 등록·해제 (add / rm)

```bash
cctg add myproject ~/work/myproject   # 등록
cctg rm  myproject                    # 등록 해제 (상태 디렉터리 보존)
cctg rm  myproject --purge            # 등록 해제 + 상태 디렉터리 삭제
```

`add` 는 대화형으로 다음을 입력받아 상태 디렉터리(`~/.claude/channels/<name>/`)를 스캐폴딩한다.

- **봇 토큰** — [@BotFather](https://t.me/BotFather)에서 발급한 **새 봇** 토큰 (가려서 입력, `.env` 600 권한으로 저장)
- **본인 Telegram 숫자 ID** — 모르면 [@userinfobot](https://t.me/userinfobot)에 DM. 입력한 ID로 `access.json` allowlist를 자동 생성하므로 별도 페어링이 필요 없다.

`rm` 은 기본적으로 토큰·allowlist가 든 상태 디렉터리를 **보존**한다(재등록 시 재사용 가능). 실행 중인 봇은 먼저 `down` 해야 한다. `--purge` 는 상태 디렉터리까지 삭제하되, 전역 봇 디렉터리나 `CHANNELS_DIR` 밖 경로는 안전을 위해 건드리지 않는다.

### 1-1. 이름 변경 (rename)

```bash
cctg rename myproject newname              # 이름 변경 + 상태 디렉터리도 함께 이동
cctg rename myproject newname --keep-dir   # 이름만 변경, 디렉터리 경로 유지
```

레지스트리에 상태 디렉터리 경로가 명시적으로 저장되므로 이름과 데이터 위치는 분리돼 있다. 기본 동작은 상태 디렉터리가 기본 경로(`~/.claude/channels/<old>/`)일 때만 `<new>` 로 이동하고 레지스트리를 갱신한다. 커스텀 경로이거나 `--keep-dir` 지정 시에는 디렉터리를 그대로 두고 이름(과 tmux 세션명 `cctg-<name>`)만 바꾼다. 세션명이 이름 기반이므로 **실행 중인 봇은 먼저 `down`** 해야 하며, `<new>` 가 이미 등록돼 있거나 대상 디렉터리가 이미 존재하면 거부한다.

### 2. 봇 기동·정지·재기동 (up / down / restart)

```bash
cctg up myproject       # 특정 봇 기동
cctg up all             # 등록된 모든 봇 기동
cctg down myproject     # 정지
cctg down all           # 전체 정지
cctg restart myproject  # 재기동 (down + up)
cctg restart all        # 전체 재기동
```

기동하면 `caffeinate -is` 로 sleep을 막으며 detached tmux 세션(`cctg-<name>`)에서 봇이 돈다. 이후 봇에 DM하면 바로 응답한다.

### 3. 상태 확인·로그 (status / logs / attach)

```bash
cctg status              # 봇별 상태(RUNNING+업타임 / stopped / BROKEN) + cwd·state 경로
cctg logs myproject      # 최근 로그 50줄 출력 (attach 없이)
cctg logs myproject 200  # 최근 200줄
cctg attach myproject    # 해당 tmux 세션에 붙어 실시간 확인 (분리: Ctrl-b d)
```

`status` 는 봇마다 `RUNNING`(+업타임)/`stopped`/`BROKEN` 상태와 `cwd`·`state` 경로를 보여준다. `BROKEN` 은 등록은 됐지만 작업 디렉터리가 없거나 토큰 파일(`.env`)이 없는 경우다. `logs` 와 `attach` 는 봇이 정지 상태면 친절한 안내와 함께 중단한다.

### 4. 진단 (doctor)

```bash
cctg doctor              # 의존성(tmux/claude/caffeinate/jq)·PATH·레지스트리·공통 권한 정책 점검
```

## 권한·옵션 (config / common)

봇은 tmux 안에서 **대화형 TUI**로 도는데 운영자는 그 TUI 앞에 없고 텔레그램으로만 상호작용한다. 그래서 권한 프롬프트가 뜨면 아무도 응답할 수 없어 봇이 멈춘다. CCTG는 이를 "**위험하지 않은 건 자동승인하고, 위험한 건 deny로 차단**"하는 모델로 푼다 — 프롬프트가 뜨는 회색지대를 없앤다.

두 계층으로 설정한다.

| 계층 | 저장 위치 | 주입 방식 | 수정 명령 |
|---|---|---|---|
| **공통**(모든 봇) | `~/.claude/channels/cctg-shared.settings.json` | `claude --settings <file>` | `cctg common ...` |
| **봇별**(우선) | `~/.claude/channels/<name>/launch.env` | `claude --permission-mode <m>` + `$CLAUDE_EXTRA_ARGS` | `cctg config <name> ...` |

봇별 `CCTG_PERMISSION_MODE` 가 있으면 공통 `defaultMode` 를 덮어쓴다. 비우면 공통값을 따른다.

### 공통 권한 정책 (common)

처음 `add`/`up` 시 공통 설정 파일이 자동 생성된다. 기본값은 `defaultMode: bypassPermissions` + dangerous 패턴 deny 안전망이다(전역 `~/.claude/settings.json` 의 deny·PreToolUse 훅과 **merge**되며, deny는 union·deny가 allow보다 우선).

```bash
cctg common                          # 현재 공통 설정 출력 (= common show)
cctg common edit                     # $EDITOR 로 직접 편집
cctg common mode acceptEdits         # 공통 defaultMode 변경
cctg common deny add 'Bash(sudo *)'  # deny 규칙 추가
cctg common deny rm  'Bash(sudo *)'  # deny 규칙 제거
cctg common allow add 'Read(/data/**)'   # allow 규칙 추가/제거
```

> `mode`/`deny`/`allow` 같은 구조화된 수정은 `jq` 가 필요하다(없으면 `common edit` 로 직접 편집). `show`/`edit` 는 `jq` 없이도 동작한다.

### 봇별 옵션 (config)

```bash
cctg config myproject                       # 봇 옵션 출력 (= config ... show)
cctg config myproject mode bypassPermissions   # 이 봇 권한 모드 설정
cctg config myproject mode clear            # 공통값을 따르도록 비움
cctg config myproject args "--model opus"   # 이 봇 전용 claude 추가 인자
cctg config myproject edit                  # launch.env 직접 편집
```

권한 모드 값: `acceptEdits | auto | bypassPermissions | default | dontAsk | plan`.

| 모드 | 봇 맥락 동작 |
|---|---|
| `bypassPermissions` | 전부 자동승인. **deny 규칙·PreToolUse 훅(git-guard 등)은 그대로 작동** → 위험 차단은 여기에 의존 |
| `acceptEdits` | 편집·안전 fs명령만 자동, 그 외 Bash/네트워크는 프롬프트(헤드리스에선 멈출 수 있음) |
| `dontAsk` | 회색지대를 프롬프트 대신 자동 거부(안전하지만 allow에 없으면 조용히 실패) |

설정 변경은 `up`/`restart` 시 적용된다(실행 중이면 `cctg restart <name>`). 현재 적용 모드는 `cctg status`·`cctg doctor` 에서 확인한다.

## 업데이트

```bash
cctg update
```

설치 시 기록된 매니페스트(`~/.config/cctg/install.conf`)에서 레포 위치·설치 모드를 읽어 `git pull --ff-only` 후 두 모드 모두 `install.sh` 를 재실행(멱등)한다.

- **복사 설치**: `git pull` → `install.sh` 재실행으로 새 `cc-tg.sh` 를 `cctg` 에 다시 복사한다.
- **심볼릭(`--dev`) 설치**: `cctg`(심볼릭)는 `git pull` 로 즉시 최신이 되지만, 자동완성은 `DATA_DIR` 로 *복사*되므로 `install.sh --dev` 재실행으로 함께 갱신한다.

> 로컬에 커밋되지 않은 변경이 있어 fast-forward가 불가하면 `update` 는 덮어쓰지 않고 중단한다. 이 경우 레포에서 직접 정리한다.

## 동작 방식

- 등록 정보는 레지스트리(`~/.claude/channels/projects.conf`)에 `name | working_dir | state_dir` 형식으로 저장된다.
- 봇별 상태는 `~/.claude/channels/<name>/` 에 격리된다 (`.env` 토큰, `access.json` allowlist, `launch.env` 봇별 옵션, `inbox/`).
- 공통 권한 정책은 `~/.claude/channels/cctg-shared.settings.json` 에 두고 모든 봇에 `--settings` 로 주입된다.
- 각 봇은 `TELEGRAM_STATE_DIR` 를 분리 주입받아 전역 봇 및 다른 프로젝트 봇과 섞이지 않는다.
- tmux 세션 이름은 `cctg-<name>` 규칙을 따른다.

환경 변수로 경로를 바꿀 수 있다.

| 변수 | 기본값 | 의미 |
|---|---|---|
| `CC_CHANNELS_DIR` | `~/.claude/channels` | 채널 상태 루트 |
| `CC_TG_REGISTRY` | `$CC_CHANNELS_DIR/projects.conf` | 레지스트리 파일 |
| `CC_TG_SHARED_SETTINGS` | `$CC_CHANNELS_DIR/cctg-shared.settings.json` | 공통 권한 정책 파일 |

## 제거

```bash
./uninstall.sh
```

`~/.local/bin/cctg` 만 제거하며(우리가 설치한 것인지 확인 후), 레지스트리·상태 디렉터리(`~/.claude/channels/`)는 건드리지 않으므로 재설치 시 봇 등록이 유지된다.

## 더 보기

- [패키징 구조와 향후 승격 경로](docs/packaging.md)
- [향후 작업 후보 (TODO)](docs/TODO.md)

버전은 저장소 루트의 `VERSION` 파일이 기준(SoT)이다. `cctg version` 으로 확인하고, `cctg update` 는 업데이트 전후 버전을 함께 표시한다.
