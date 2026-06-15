# cctg

macOS에서 **tmux + Claude Code + Telegram 게이트웨이**를 묶어, 프로젝트별 Claude Code Telegram 봇을 쉽게 띄우고 관리하는 런처.

전역 봇(`~/.claude/channels/telegram/`)은 건드리지 않는다. 프로젝트 봇은 각자 상태 디렉터리·토큰·작업 디렉터리를 갖고 격리된 tmux 세션에서 돈다.

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
| telegram 플러그인 | Telegram 채널 연동 | 전역 설치 필요: `/plugin install telegram@claude-plugins-official` |

## 설치

```bash
git clone <repo-url> cctg
cd cctg
./install.sh
```

`install.sh` 는 의존성을 점검하고 `cc-tg.sh` 를 `~/.local/bin/cctg` 로 배치한다. 재실행해도 안전하다(idempotent).

### 설치 모드

| 명령 | 동작 | 용도 |
|---|---|---|
| `./install.sh` | `cc-tg.sh` 를 `~/.local/bin/cctg` 로 **복사** | 릴리스. 레포를 지우거나 옮겨도 동작. 업데이트는 `git pull` 후 재설치 |
| `./install.sh --dev` | `~/.local/bin/cctg` 를 레포의 `cc-tg.sh` 로 **심볼릭 링크** | 개발. 레포 수정 즉시 반영 |

설치 위치는 `BINDIR` 로 바꿀 수 있다: `BINDIR=~/bin ./install.sh`

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
  add <name> <cwd>      rm <name> [--purge]   up <name|all>     down <name|all>
  restart <name|all>    status                logs <name> [N]   attach <name>
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
cctg status              # 등록/실행(RUNNING/stopped) 상태 목록
cctg logs myproject      # 최근 로그 50줄 출력 (attach 없이)
cctg logs myproject 200  # 최근 200줄
cctg attach myproject    # 해당 tmux 세션에 붙어 실시간 확인 (분리: Ctrl-b d)
```

`logs` 와 `attach` 는 봇이 정지 상태면 친절한 안내와 함께 중단한다.

### 4. 진단 (doctor)

```bash
cctg doctor              # 의존성(tmux/claude/caffeinate)·PATH·레지스트리 점검
```

## 업데이트

```bash
cctg update
```

설치 시 기록된 매니페스트(`~/.config/cctg/install.conf`)에서 레포 위치·설치 모드를 읽어 `git pull --ff-only` 후 자동으로 재설치한다.

- **복사 설치**: `git pull` → `install.sh` 재실행으로 새 `cc-tg.sh` 를 `cctg` 에 다시 복사한다.
- **심볼릭(`--dev`) 설치**: `git pull` 만 하면 `cctg` 가 레포를 가리키므로 즉시 최신이 된다.

> 로컬에 커밋되지 않은 변경이 있어 fast-forward가 불가하면 `update` 는 덮어쓰지 않고 중단한다. 이 경우 레포에서 직접 정리한다.

## 동작 방식

- 등록 정보는 레지스트리(`~/.claude/channels/projects.conf`)에 `name | working_dir | state_dir` 형식으로 저장된다.
- 봇별 상태는 `~/.claude/channels/<name>/` 에 격리된다 (`.env` 토큰, `access.json` allowlist, `inbox/`).
- 각 봇은 `TELEGRAM_STATE_DIR` 를 분리 주입받아 전역 봇 및 다른 프로젝트 봇과 섞이지 않는다.
- tmux 세션 이름은 `cctg-<name>` 규칙을 따른다.

환경 변수로 경로를 바꿀 수 있다.

| 변수 | 기본값 | 의미 |
|---|---|---|
| `CC_CHANNELS_DIR` | `~/.claude/channels` | 채널 상태 루트 |
| `CC_TG_REGISTRY` | `$CC_CHANNELS_DIR/projects.conf` | 레지스트리 파일 |

## 제거

```bash
./uninstall.sh
```

`~/.local/bin/cctg` 만 제거하며(우리가 설치한 것인지 확인 후), 레지스트리·상태 디렉터리(`~/.claude/channels/`)는 건드리지 않으므로 재설치 시 봇 등록이 유지된다.

## 더 보기

- [패키징 구조와 향후 승격 경로](docs/packaging.md)
