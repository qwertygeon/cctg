[English](installation.md) | **한국어**

# CCTG 설치·업데이트·제거

> macOS에서 `cctg` 런처를 설치·업데이트·제거하는 전체 레퍼런스. 설치 모드, 플래그, 각 단계가 건드리는 대상을 다룬다.

## 목차

- [요구 사항](#요구-사항)
- [빠른 설치](#빠른-설치)
- [`install.sh` 가 하는 일](#installsh-가-하는-일)
- [설치 모드](#설치-모드)
  - [복사 설치 (기본 — 릴리스)](#복사-설치-기본--릴리스)
  - [개발 설치 (`--dev` / `--link`)](#개발-설치---dev----link)
- [플래그·환경 변수](#플래그환경-변수)
- [파일이 놓이는 위치](#파일이-놓이는-위치)
  - [자동완성](#자동완성)
  - [셸 rc 관리 블록](#셸-rc-관리-블록)
  - [매니페스트·언어 설정](#매니페스트언어-설정)
- [PATH 설정](#path-설정)
- [설치 이후](#설치-이후)
- [업데이트](#업데이트)
- [제거](#제거)
- [제거해도 보존되는 것](#제거해도-보존되는-것)

## 요구 사항

CCTG는 **macOS 전용**이다 — macOS 빌트인인 `caffeinate` 에 의존하여 머신이 잠들지 않게 한다.

필수 의존성(둘 중 하나라도 없으면 설치를 중단한다):

- `claude` — Claude Code CLI.
- `tmux` — 런처가 그 안에서 실행되는 터미널 멀티플렉서.

권장 / 선택:

- `caffeinate` — macOS 빌트인. Mac의 절전을 방지한다. 없으면 `install.sh` 는 경고만 하고 중단하지 않는다.
- `jq` — 선택. `status --json`, `common` 의 구조화 편집(mode/deny/allow), `--group` 시드에 필요하다. `jq` 가 없으면 해당 동작은 오류가 나지만, `jq` 가 필요 없는 조회·편집 경로는 그대로 동작한다.

또한 해당 채널 플러그인을 Claude Code 안에 전역으로 설치해야 한다. 예:

```
/plugin install telegram@claude-plugins-official
/plugin install discord@claude-plugins-official
```

## 빠른 설치

```bash
git clone https://github.com/qwertygeon/cctg.git
cd cctg
./install.sh
```

`install.sh` 는 **멱등(idempotent)** 하다 — 다시 실행해도 안전하며 기존 설치를 갱신할 뿐이다.

## `install.sh` 가 하는 일

`./install.sh` 실행은 네 단계를 수행한다.

1. **의존성 점검.** `tmux` 와 `claude` 는 필수이며, 둘 중 하나라도 `PATH` 에 없으면 설치를 중단한다. `caffeinate` 도 점검하지만, 없을 경우 경고만 출력한다.
2. **런처 배치.** `~/.local/bin/cctg` 에 둔다(복사인지 심볼릭 링크인지는 설치 모드가 결정한다 — 아래 참조).
3. **셸 자동완성 설치.** bash·zsh 용.
4. **멱등 관리 블록 추가.** 셸 rc 파일에 `PATH` 와 자동완성을 활성화하는 블록을 추가한다.

## 설치 모드

### 복사 설치 (기본 — 릴리스)

```bash
./install.sh
# 또는 명시적으로:
./install.sh --copy
```

패키지(`cc-tg.sh`, `VERSION`, `lib/`, `messages/`)를 `~/.local/libexec/cctg/` 로 복사한 뒤, `~/.local/bin/cctg` 를 `~/.local/libexec/cctg/cc-tg.sh` 로 심볼릭 링크한다.

패키지를 레포 밖으로 복사하므로 **clone 한 레포를 지우거나 옮겨도 설치가 계속 동작한다.** 이것이 릴리스 방식이다. 이후 업데이트하려면 레포에서 `git pull` 후 `install.sh` 를 다시 실행하거나 `cctg update` 를 사용한다.

### 개발 설치 (`--dev` / `--link`)

```bash
./install.sh --dev
# --link 는 별칭이다:
./install.sh --link
```

`~/.local/bin/cctg` 를 레포의 `cc-tg.sh` 로 **직접** 심볼릭 링크한다. 레포에서 수정한 내용이 즉시 반영된다 — 개발 방식이다. 심볼릭 링크가 레포를 가리키므로 레포 위치를 고정해야 한다.

## 플래그·환경 변수

| 플래그 / 변수 | 효과 |
|---|---|
| `--copy` | 복사 설치(기본값). |
| `--dev` / `--link` | 레포를 가리키는 심볼릭 링크 설치. |
| `--no-completions` | bash/zsh 자동완성 설치를 건너뛴다. |
| `--no-shell-setup` | 셸 rc 관리 블록 추가를 건너뛴다. |
| `--lang en\|ko` | CLI 출력 언어를 시드한다. 미지정 시 `$LC_ALL`/`$LANG` 에서 자동 감지한다(`ko*` 또는 `*_KR*` → `ko`, 그 외 `en`). |
| `--alias` / `--alias=NAME` | `cctg` 와 동일하게 동작하는 짧은 별칭 명령을 자동완성과 함께 설치한다. `install.sh` 는 이 플래그가 없어도 기본으로 `cg` 를 설치하며, `--alias=NAME` 으로 다른 이름을 지정할 수 있다. 이름은 매니페스트에 기록된다. |
| `--no-alias` | 별칭을 설치하지 않는다(있으면 제거). |
| `-h` / `--help` | 도움말을 출력하고 종료한다. |
| `BINDIR=~/bin ./install.sh` | 설치 위치를 변경한다(기본 `~/.local/bin`). |
| `CCTG_LIBEXEC=...` | libexec 패키지 디렉터리를 변경한다(기본 `~/.local/libexec/cctg`). |

## 파일이 놓이는 위치

### 자동완성

- **bash:** `$XDG_DATA_HOME`(또는 `~/.local/share`)`/bash-completion/completions/cctg`
- **zsh:** `$XDG_DATA_HOME`(또는 `~/.local/share`)`/zsh/site-functions/_cctg`

자동완성 설치가 실패해도 전체 설치는 중단되지 않는다.

### 셸 rc 관리 블록

설치 스크립트는 마커로 구분되는 관리 블록을 기록한다.

```
# >>> cctg >>>
...
# <<< cctg <<<
```

이 블록이 `PATH` 와 자동완성을 활성화한다. 설치 스크립트가 파일을 처음 편집할 때 한 번에 한해 `<rc>.cctg-bak` 백업을 남긴다. 다시 실행해도 블록이 중복되지 않는다.

- **zsh:** `~/.zshrc` 를 편집한다.
- **bash:** `~/.bashrc` 와 `~/.bash_profile` 를 편집한다.
- **알 수 없는 셸:** rc 편집을 건너뛰고 수동 `PATH` 명령을 출력한다.

변경을 적용하려면 새 터미널을 열거나 해당 rc 를 `source` 한다(예: `source ~/.zshrc`).

### 매니페스트·언어 설정

- `install.sh` 는 `~/.config/cctg/install.conf` 에 매니페스트를 기록한다. 키: `repo`, `mode`, `version`, `bindir`, `libexecdir`, `bashcomp`, `zshcomp`, `shellrc`. `cctg update` 와 `uninstall.sh` 가 이 매니페스트를 읽는다.
- CLI 언어 설정은 `~/.config/cctg/config`(`lang=...`)에 분리 저장되어 `cctg update` 가 보존한다.

## PATH 설정

`~/.local/bin` 이 아직 `PATH` 에 없다면(그리고 `--no-shell-setup` 을 사용했거나 셸이 알 수 없는 경우) 수동으로 추가한다.

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
```

다음으로 확인한다.

```bash
cctg doctor
```

## 설치 이후

새 터미널을 열거나 셸을 다시 로드한 뒤 실행한다.

```bash
cctg doctor
```

`doctor` 는 의존성, `PATH`, 레지스트리, 공유 정책을 점검한다.

## 업데이트

```bash
cctg update
```

`cctg update` 는 매니페스트에서 레포 위치와 설치 모드를 읽어 `git pull --ff-only` 를 실행한 뒤 `install.sh`(멱등)를 다시 실행한다. 이전 → 이후 버전을 출력한다.

- **복사 설치** 의 경우 새 런처가 libexec 디렉터리로 다시 복사된다.
- **개발(`--dev`) 설치** 의 경우 pull 직후 런처가 이미 최신이며, 자동완성은 데이터 디렉터리로 복사되므로 다시 실행하면 갱신된다.
- 커밋되지 않은 로컬 변경으로 fast-forward 가 막히면 `update` 는 아무것도 덮어쓰지 않고 멈춘다 — 레포를 정리한 뒤 다시 시도한다.

## 제거

```bash
./uninstall.sh
```

`uninstall.sh` 는 CCTG가 설치한 모든 것을 제거한다.

- `~/.local/bin/cctg` — 단, **CCTG가 설치한 것임을 확인한 뒤에만** 제거한다(심볼릭 링크 대상 또는 복사 파일 내부의 정체성 문자열을 확인한다). 경로가 다른 대상을 가리키면 그대로 둔다.
- libexec 패키지 디렉터리(복사 설치의 경우).
- 매니페스트에 기록된 bash/zsh 자동완성 파일.
- 셸 rc 관리 블록 — `# >>> cctg >>>` / `# <<< cctg <<<` 마커 사이의 내용만.
- 한 번 남긴 `.cctg-bak` rc 백업.
- 언어 설정(`~/.config/cctg/config`).
- 매니페스트 자체.

정리할 bin 경로는 `BINDIR` 환경 변수 또는 매니페스트의 `bindir` 값으로 결정된다.

## 제거해도 보존되는 것

`uninstall.sh` 는 `~/.claude/channels/` 아래의 레지스트리·상태 디렉터리를 **절대 건드리지 않는다.** 봇 등록과 토큰은 재설치 후에도 보존되므로, 채널 설정을 잃지 않고 CCTG를 제거·재설치할 수 있다.

---

[← README로 돌아가기](../README.ko.md)

**함께 보기:**

- [Telegram 설정](telegram-setup.ko.md)
- [Discord 설정](discord-setup.ko.md)
- [명령어](commands.ko.md)
- [설정](configuration.ko.md)
