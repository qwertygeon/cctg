# cctg 패키징 구조

> 설치 레이아웃의 현재 설계와, 패키지가 커졌을 때의 승격 경로를 기록한다.

## 목차

- [현재 구조 (단일 자립 스크립트)](#현재-구조-단일-자립-스크립트)
  - [설치 모드](#설치-모드)
  - [왜 단일 파일은 복사만으로 충분한가](#왜-단일-파일은-복사만으로-충분한가)
- [설치 위치를 ~/.local/bin 으로 둔 이유](#설치-위치를-localbin-으로-둔-이유)
- [향후 승격 경로 (Homebrew식 libexec 구조)](#향후-승격-경로-homebrew식-libexec-구조)
  - [승격 트리거](#승격-트리거)
  - [승격 후 레이아웃](#승격-후-레이아웃)

## 현재 구조 (단일 자립 스크립트)

`cc-tg.sh` 는 다른 파일에 의존하지 않는 단일 자립 스크립트다. 설치는 이 한 파일을 사용자가 `cctg` 명령으로 호출할 수 있게 만드는 것이 전부다.

```
레포/
├── cc-tg.sh        # 런처 본체 (단일 자립)
├── install.sh      # 설치 (copy 기본 / --dev 심볼릭) + 매니페스트 기록
└── uninstall.sh    # 제거
```

설치 시 `install.sh` 는 `~/.config/cctg/install.conf` 에 `repo` / `mode` / `bindir` 를 기록한다. `cctg update` 는 이 매니페스트로 레포 위치와 설치 모드를 찾아 `git pull` 후 재설치한다 (copy 모드는 레포와 분리돼 있어 매니페스트 없이는 출처를 알 수 없기 때문).

### 설치 모드

| 모드 | 명령 | 동작 | 용도 |
|---|---|---|---|
| copy (기본) | `./install.sh` | `cc-tg.sh` → `~/.local/bin/cctg` 로 **복사** | 릴리스. 레포를 지우거나 옮겨도 동작. 업데이트는 `git pull` 후 재설치 |
| link | `./install.sh --dev` | `~/.local/bin/cctg` → 레포의 `cc-tg.sh` **심볼릭 링크** | 개발. 레포 수정 즉시 반영. 레포 위치 고정 필요 |

### 왜 단일 파일은 복사만으로 충분한가

복사 대상(`~/.local/bin`)이 이미 PATH 디렉터리이므로, 복사 한 번이 곧 설치 완료다. "복사 후 그 경로로 다시 심볼릭 링크"를 거는 것은 단일 파일 단계에서는 중복 indirection일 뿐 이득이 없다. 심볼릭의 가치는 (a) PATH 밖의 위치(레포·버전 디렉터리)를 PATH로 노출하거나, (b) 여러 파일을 한 디렉터리에 모아둘 때 비로소 생긴다.

## 설치 위치를 ~/.local/bin 으로 둔 이유

`~/bin` 대신 `~/.local/bin` 을 표준 설치 경로로 사용한다.

- XDG Base Directory 관행에 부합하는 user-binary 경로다.
- pip/pipx/rustup 등 다수 도구가 이 경로를 PATH에 추가하거나 전제로 한다.
- `~/bin` 은 옛 관행이며 최신 macOS/리눅스 기본 셸 설정에서 PATH에 없는 경우가 많다.

`BINDIR` 환경 변수로 설치 위치를 변경할 수 있다 (예: `BINDIR=~/bin ./install.sh`).

## 향후 승격 경로 (Homebrew식 libexec 구조)

스크립트가 여러 파일로 커지면 복사 대상을 `~/.local/libexec/cctg/` 로 옮기고 `~/.local/bin/cctg` 심볼릭을 거는 Homebrew식 구조로 승격한다.

### 승격 트리거

다음 중 하나라도 발생하면 단일 파일 → libexec 구조로 전환을 검토한다.

- 보조 라이브러리(`lib/*.sh`) 등 `cc-tg.sh` 가 source 하는 동반 파일이 생김
- 셸 자동완성 스크립트(bash/zsh completion) 추가
- 버전별 디렉터리 분리나 다중 진입점(여러 실행 명령)이 필요해짐

### 승격 후 레이아웃

```
~/.local/libexec/cctg/      # 패키지 본체 (PATH 밖)
├── cc-tg.sh
├── lib/...
└── completions/...
~/.local/bin/cctg           # → ~/.local/libexec/cctg/cc-tg.sh 심볼릭
```

이 단계에서 PATH에 노출되는 것은 `~/.local/bin/cctg` 하나뿐이고, 동반 파일은 libexec 안에 격리된다. `install.sh` 는 libexec 디렉터리를 통째로 복사한 뒤 bin 심볼릭을 거는 흐름으로 확장한다.
