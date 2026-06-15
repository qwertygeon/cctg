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
├── cc-tg.sh           # 런처 본체
├── VERSION            # 패키지 버전 SoT
├── install.sh         # 설치 (copy 기본 / --dev 심볼릭) + 자동완성 설치 + 매니페스트 기록
├── uninstall.sh       # 제거 (bin + libexec + 자동완성)
├── messages/          # i18n 메시지 카탈로그 (cc-tg.sh 가 런타임에 source)
│   ├── en.sh
│   └── ko.sh
└── completions/
    ├── cctg.bash      # bash 자동완성
    └── _cctg          # zsh 자동완성
```

> **현재 copy 설치는 libexec 구조를 쓴다(아래 "승격 경로" 참조).** `cc-tg.sh` 가 런타임에 source 하는 동반 파일(`messages/*.sh`)이 생기면서 단일 자립 스크립트 가정이 깨졌고, 그 시점에 승격 트리거가 발동했다. dev(`--dev`) 설치는 레포의 `cc-tg.sh` 를 직접 심볼릭하므로 동반 파일을 레포에서 읽는다.

설치 시 `install.sh` 는 매니페스트(`~/.config/cctg/install.conf`)에 `repo` / `mode` / `version` / `bindir` / `bashcomp` / `zshcomp` 를 기록한다.

버전 결정 순서: (1) 스크립트 옆 `VERSION`(레포 직접 실행·`--dev` 심볼릭) → (2) 매니페스트 `version=`(copy 설치는 `VERSION` 이 옆에 없으므로) → (3) 임베디드 폴백. `cctg version` 과 `install.sh` / `cctg update` 가 이 값을 표시한다.

- `cctg update` 는 매니페스트로 레포 위치와 설치 모드를 찾아 `git pull` 후 재설치한다 (copy 모드는 레포와 분리돼 있어 매니페스트 없이는 출처를 알 수 없기 때문).
- `uninstall.sh` 는 매니페스트의 `bashcomp` / `zshcomp` 경로를 보고 자동완성 파일까지 정리한다.

> **자동완성은 libexec 승격을 강제하지 않는다.** 완성 파일은 `cc-tg.sh` 가 런타임에 source 하는 동반 파일이 아니라, 표준 완성 디렉터리(`~/.local/share/bash-completion/completions/`, zsh `fpath`)로 따로 설치되는 셸 통합물이다. 승격 트리거는 `cc-tg.sh` 가 *source 하는* 동반 파일(`messages/*.sh`, 향후 `lib/*.sh`)이 생길 때이며, i18n 카탈로그 도입으로 **이미 충족되어 copy 설치가 libexec 로 승격되었다.**

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

## 승격 경로 (Homebrew식 libexec 구조) — copy 설치에 적용됨

`cc-tg.sh` 가 source 하는 동반 파일(i18n `messages/*.sh`)이 생기면서, copy 설치는 패키지를 `~/.local/libexec/cctg/` 로 복사하고 `~/.local/bin/cctg` 심볼릭을 거는 Homebrew식 구조로 승격되었다.

### 승격 트리거 (충족됨)

다음 중 하나라도 발생하면 단일 파일 → libexec 구조로 전환한다.

- 보조 라이브러리(`lib/*.sh`)·메시지 카탈로그(`messages/*.sh`) 등 `cc-tg.sh` 가 source 하는 동반 파일이 생김 — **i18n 도입으로 충족**
- 버전별 디렉터리 분리나 다중 진입점(여러 실행 명령)이 필요해짐

셸 자동완성은 표준 완성 디렉터리로 따로 설치되는 별도 통합물이라 승격 트리거가 아니다(위 참고).

### 레이아웃 (현재 copy 설치)

```
~/.local/libexec/cctg/      # 패키지 본체 (PATH 밖)
├── cc-tg.sh
├── VERSION
├── messages/               # en.sh · ko.sh
└── lib/...                 # (향후)
~/.local/bin/cctg           # → ~/.local/libexec/cctg/cc-tg.sh 심볼릭
```

PATH에 노출되는 것은 `~/.local/bin/cctg` 하나뿐이고, 동반 파일은 libexec 안에 격리된다. `install.sh` 는 libexec 디렉터리에 패키지를 복사한 뒤 bin 심볼릭을 건다. libexec 위치는 `CCTG_LIBEXEC` 로 바꿀 수 있고, 매니페스트의 `libexecdir=` 에 기록되어 `uninstall.sh` 가 이를 정리한다. `cc-tg.sh` 는 동반 파일을 자기 위치(`SCRIPT_DIR`) 기준으로 찾으므로 copy(libexec)·dev(레포) 양쪽에서 동일하게 동작한다.

> 자동완성 파일은 여전히 표준 완성 디렉터리로 설치된다(libexec 안에 두지 않는다). libexec 에는 `cc-tg.sh` 가 직접 source/참조하는 동반 파일만 둔다.
