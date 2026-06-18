# cctg TODO

> 향후 작업 후보. 우선순위·근거를 함께 기록한다. 착수 시 해당 항목을 갱신하고, 완료하면 여기서 제거한다. 완료 이력은 `CHANGELOG.md`(+ git 이력)가 SoT.
> 우선순위: **P1**(높음) / **P2**(중간) / **P3**(낮음). 대부분 항목은 2026-06-16 전체 문서·구조 감사에서 도출했다.

## 목차

- [릴리스 / 버전](#릴리스--버전)
  - [P1 — 0.2.0 발행 (누적분 릴리스)](#p1--020-발행-누적분-릴리스)
- [문서 정합성](#문서-정합성)
  - [P2 — README doctor 예시의 버전 하드코딩 제거](#p2--readme-doctor-예시의-버전-하드코딩-제거)
  - [P2 — CONTRIBUTING 에 브랜치 정책 추가](#p2--contributing-에-브랜치-정책-추가)
- [CI / 릴리스 / 브랜치 보호](#ci--릴리스--브랜치-보호)
  - [P2 — main 브랜치 보호 활성화](#p2--main-브랜치-보호-활성화)
  - [P2 — .shellcheckrc 추가](#p2--shellcheckrc-추가)
  - [P3 — release.yml VERSION 읽기 하드닝](#p3--releaseyml-version-읽기-하드닝)
- [설치 / 정리](#설치--정리)
  - [P2 — uninstall 잔여물 정리](#p2--uninstall-잔여물-정리)
  - [P3 — uninstall 의 bindir 매니페스트 반영](#p3--uninstall-의-bindir-매니페스트-반영)
- [CLI 표면 / 자동완성](#cli-표면--자동완성)
  - [P3 — rm --purge / rename --keep-dir 자동완성](#p3--rm---purge--rename---keep-dir-자동완성)
  - [P3 — remove / mv 별칭 처리 결정](#p3--remove--mv-별칭-처리-결정)
- [리포지토리 위생](#리포지토리-위생)
  - [P3 — .gitignore 보강](#p3--gitignore-보강)
  - [P3 — .editorconfig 추가](#p3--editorconfig-추가)
- [구조 / 확장성](#구조--확장성)
  - [lib/ 런타임 분리 (잔여)](#lib-런타임-분리-잔여)
  - [다중 게이트웨이 지원 (discord/imessage)](#다중-게이트웨이-지원-discordimessage)
- [테스트 커버리지 확장](#테스트-커버리지-확장)

## 릴리스 / 버전

### P1 — 0.2.0 발행 (누적분 릴리스)

`VERSION` 은 `0.1.1` 이지만 `develop` 의 `CHANGELOG.md [Unreleased]` 에 하위호환 기능이 다수 누적돼 있다(자동 릴리스 워크플로·주기 로그 스냅샷·81개 bats 스위트·`status --json`·로그 영속·비대화 `add`·CI). SemVer 상 MINOR 발행 대상이다.

- **무엇**: `VERSION` 을 `0.2.0` 으로 bump → `[Unreleased]` 를 `## [0.2.0] - <date>` 로 확정 → compare 링크 갱신 → `develop → main` PR 머지. 머지 시 `release.yml` 이 태그·GitHub Release 를 자동 발행한다(`docs/RELEASING.md`).
- **선행**: 아래 P2 문서 정합성 항목(특히 README 버전 하드코딩)을 함께 정리하면 깔끔하다.

## 문서 정합성

### P2 — README doctor 예시의 버전 하드코딩 제거

`README.md`·`README.ko.md` 의 `cctg doctor` 샘플 출력이 `cctg doctor (v0.1.0)` 으로 하드코딩돼 있다. 실제 헤더는 `VERSION` 에서 동적으로 렌더링(`messages/*.sh` 의 `%s`)되므로 릴리스마다 예시가 어긋난다.

- **무엇**: 두 README 의 예시 출력을 `cctg doctor (vX.Y.Z)` 플레이스홀더로 교체.

### P2 — CONTRIBUTING 에 브랜치 정책 추가

`docs/RELEASING.md` 는 `feature/* → develop → PR → main` 2단계 모델을 정의하지만, `CONTRIBUTING.md` 에는 어느 브랜치에서 분기·PR 하는지 안내가 없어 기여자가 GitHub 기본값인 `main` 으로 PR 하기 쉽다.

- **무엇**: CONTRIBUTING "Before opening a PR" 에 "Branch from and PR against `develop` (not `main`) — see [docs/RELEASING.md](docs/RELEASING.md)." 한 줄 추가.

## CI / 릴리스 / 브랜치 보호

### P2 — main 브랜치 보호 활성화

`release.yml` 은 `main` push **후** 게이트를 실행하므로, `main` 직접 push 를 막지 않으면 잘못된 `VERSION` bump 가 `main` 에 먼저 도달한 뒤 게이트가 실패한다. "main 직접 push 금지" 는 현재 문서상의 약속(prose)일 뿐 강제되지 않는다.

- **무엇**: GitHub repo Settings → Branches 에서 `main` 에 "Require a pull request before merging" + "Require status checks (CI)" 보호 규칙 활성화.
- **문서**: `docs/RELEASING.md` 에 이 보호 규칙이 전제임을 명시(워크플로만으로는 강제 불가).
- **주의**: 워크플로의 `github.token` 태그 push 는 CI 를 재트리거하지 않는다. `release.yml` 의 인라인 게이트가 태그 시점 단일 게이트이며, PR 시점 CI 가 실질 방어선이다.

### P2 — .shellcheckrc 추가

CI 의 shellcheck 제외 근거(`messages/*.sh` 의 SC2034, `completions/*` 의 SC2207)가 `ci.yml` 주석에만 존재해, 기여자가 로컬에서 동일한 결과를 재현하기 어렵다.

- **무엇**: `.shellcheckrc`(예: `severity=warning`) 추가 또는 해당 파일에 인라인 `# shellcheck disable=` 디렉티브로 제외를 in-band 문서화.

### P3 — release.yml VERSION 읽기 하드닝

`v="$(cat VERSION)"` 는 명령 치환이 끝의 개행은 제거하지만, 편집기가 넣은 선행/후행 공백·CRLF 는 태그명 `v$v` 로 전파될 수 있다.

- **무엇**: `v="$(tr -d '[:space:]' < VERSION)"` 로 방어.

## 설치 / 정리

### P2 — uninstall 잔여물 정리

`uninstall.sh` 가 상태 디렉터리는 의도적으로 보존하지만, 설치 시점 산출물인 매니페스트(`~/.config/cctg/install.conf`)·lang config·`install.sh` 가 만든 `*.cctg-bak` rc 백업은 제거하지 않아 잔여물로 남는다.

- **무엇**: uninstall 시 매니페스트·lang config 제거(또는 위치를 알리는 안내 1줄 출력). 사용자 데이터(상태 디렉터리)는 계속 보존.

### P3 — uninstall 의 bindir 매니페스트 반영

`uninstall.sh` 는 `libexecdir` 는 매니페스트에서 읽지만 `BINDIR` 은 하드코딩 기본값(`~/.local/bin`)을 쓴다. 매니페스트에 `bindir=` 가 저장돼 있으므로 비기본 설치(`BINDIR=~/bin`)는 수동 환경변수 없이 제거되지 않는다.

- **무엇**: `libexecdir` 처럼 매니페스트의 `bindir=` 를 우선 사용.

## CLI 표면 / 자동완성

### P3 — rm --purge / rename --keep-dir 자동완성

두 플래그는 실제 동작하지만(`cc-tg.sh`), `completions/cctg.bash`·`completions/_cctg` 어디에서도 제안되지 않는다.

- **무엇**: bash 완성에 `rm`/`rename` 의 `COMP_CWORD>=3` 분기로 `--purge`/`--keep-dir` 제안, zsh 도 동일하게 `compadd`.

### P3 — remove / mv 별칭 처리 결정

디스패처에 `rm|remove`·`rename|mv` 별칭이 있지만 README·i18n USAGE·완성·테스트 어디에도 없다.

- **무엇**: 의도된 별칭이면 USAGE·README 에 명시, 불필요하면 디스패처에서 제거해 표면을 최소화. (택1 결정 필요)

## 리포지토리 위생

### P3 — .gitignore 보강

방어적으로 다음을 추가한다.

- **무엇**: `RELEASE_NOTES.md`(release.yml·수동 폴백이 작업 트리에 생성), `.env`(기여자가 repo 루트에서 로컬 테스트 시 생성 가능). 봇 상태·토큰은 `~/.claude/channels/` 등 repo 밖이라 커밋 위험은 본래 낮으나, 위 둘은 트리에 떨어질 수 있다.

### P3 — .editorconfig 추가

셸 위주 프로젝트의 들여쓰기·EOL·charset 일관성(특히 rc 블록·heredoc 본문).

- **무엇**: 최소 `.editorconfig`(sh = house style, LF, UTF-8, 끝 개행).

## 구조 / 확장성

### lib/ 런타임 분리 (잔여)

copy 설치의 libexec 레이아웃과 `cmd_*()` 함수 분리는 이미 적용됐다. 남은 단계는 `cc-tg.sh` 본체를 런타임 source 하는 `lib/*.sh` 모듈로 쪼개는 것이다.

- **무엇**: 공통 헬퍼(`conf_*`·`set_env_kv`·registry 조작 등)와 `cmd_*()` 군을 `lib/*.sh` 로 분리하고, `cc-tg.sh` 는 source + 디스패처만 남긴다. libexec 레이아웃이 동반 파일을 같은 디렉터리에 두므로 `lib/` 도 그대로 수용한다.
- **이점**: 파일별 책임 분리, 명령별 테스트 용이.
- **착수 조건(권장)**: 명령 수가 더 늘거나 단일 파일(현재 ~940줄)이 유지보수에 부담이 될 때. **현재 규모에서는 단일 파일이 더 단순하므로 보류.**
- **주의**: source 경로 해석(`SCRIPT_DIR`)이 copy/dev 양쪽에서 동작하도록 유지. shellcheck SC1090(비상수 source)은 `# shellcheck source=` 디렉티브로 처리.

### 다중 게이트웨이 지원 (discord/imessage)

현재 CCTG 는 Telegram 만 구동한다(`PLUGIN="plugin:telegram@..."` 하드코딩, `up_one` 의 `TELEGRAM_STATE_DIR` 주입). README 「지원 게이트웨이」 표는 discord·imessage 를 "예정"으로 표기하고 이름을 예약해 뒀다.

- **무엇**: 봇별 채널 타입(telegram/discord/imessage)을 레지스트리·`launch.env` 에 저장하고, `up_one` 이 타입별 플러그인 ID 와 `<CHANNEL>_STATE_DIR` 환경변수를 선택하도록 일반화.
- **이점**: 한 런처로 여러 채널 봇 관리.
- **주의**: 채널별 토큰/접근제어 차이(imessage 는 토큰 없음·chat.db 의존), `add` 프롬프트·검증 분기. 레지스트리 스키마 변경(하위호환).

## 테스트 커버리지 확장

`tests/` bats 스위트(167 테스트)는 등록·명령·라이프사이클(up/down/restart, 다중 타겟 포함)·스냅샷 watcher·가드 로직을 격리 상태 트리 + stateful fake tmux 로 검증한다. 아직 안 덮은 경로:

- **텍스트형 `status`** — 현재 `status --json` 만 테스트된다(`status_json.bats`). RUNNING/stopped/BROKEN 렌더링·uptime·복구 힌트는 순수 로직이므로 fake tmux 로 `tests/status.bats` 추가 가치가 있다.
- **`attach` / `update`** — 인터랙티브·네트워크 의존이라 수동 검증 영역으로 남기는 것이 합리적(테스트 추가는 선택).
- **`config edit` / `common edit` / `common allow rm`** — `edit` 은 `$EDITOR` 로 셸아웃이라 가치 낮음. `allow rm` 은 `deny rm` 과 jq 경로를 공유하므로 대칭성용으로만 선택 추가.
- **`launch` 문자열 내용 검증** — stub 이 세션 생성/종료(`-s`/`-t`)는 추적하지만 `new-session` 의 명령 인자 본문(`--settings`·`--permission-mode`·`CLAUDE_EXTRA_ARGS` 주입)은 단언하지 않는다. stub 이 받은 전체 argv 를 파일로 기록해 검증하도록 확장 가능.
- **`install.sh` / `uninstall.sh` / `update`** — 파일시스템·심볼릭·매니페스트 부수효과가 커서 별도 격리(HOME 샌드박스 + git 픽스처)가 필요. 현재 `bash -n`·shellcheck 만 적용.
