# cctg TODO

> 향후 작업 후보. 우선순위·근거를 함께 기록한다. 착수 시 해당 항목을 갱신한다.
> 완료 항목의 상세는 `CHANGELOG.md` 가 SoT 이며, 여기에는 후속 작업의 전제로서만 짧게 남긴다.

## 목차

- [구조 / 확장성](#구조--확장성)
  - [lib/ 분리 (libexec 본래 의도)](#lib-분리-libexec-본래-의도)
- [기능 아이디어](#기능-아이디어)
  - [다중 게이트웨이 지원 (discord/imessage)](#다중-게이트웨이-지원-discordimessage)
  - [로그 크래시 커버리지](#로그-크래시-커버리지)
  - [테스트 커버리지 확장](#테스트-커버리지-확장)
- [완료됨 (전제·이력)](#완료됨-전제이력)

## 구조 / 확장성

### lib/ 분리 (libexec 본래 의도)

copy 설치의 libexec 레이아웃(`~/.local/libexec/cctg/` 에 `cc-tg.sh`·`VERSION`·`messages/`)과 `cmd_*()` 함수 분리는 이미 완료됐다([완료됨](#완료됨-전제이력) 참조). 남은 것은 `cc-tg.sh` 본체를 런타임 source 하는 `lib/*.sh` 모듈로 쪼개는 단계다.

- **무엇**: 공통 헬퍼(conf_*, set_env_kv, registry 조작 등)와 `cmd_*()` 군을 `lib/*.sh` 로 분리하고, `cc-tg.sh` 는 source + 디스패처만 남긴다. libexec 레이아웃은 이미 동반 파일을 같은 디렉터리에 두므로 `lib/` 도 그대로 수용한다.
- **이점**: 파일별 책임 분리, 명령별 테스트 용이.
- **착수 조건(권장)**: 명령 수가 더 늘거나 단일 파일(현재 ~730줄)이 유지보수에 부담이 될 때. **현재 규모에서는 단일 파일이 더 단순하므로 보류.**
- **주의**: source 경로 해석(`SCRIPT_DIR`)이 copy/dev 양쪽에서 동작하도록 유지. shellcheck 의 SC1090(비상수 source)은 `# shellcheck source=` 디렉티브로 처리.

## 기능 아이디어

### 다중 게이트웨이 지원 (discord/imessage)

현재 CCTG 는 Telegram 만 구동한다(`PLUGIN="plugin:telegram@..."` 하드코딩, `up_one` 의 `TELEGRAM_STATE_DIR` 주입). README 「지원 게이트웨이」 표는 discord·imessage 를 "예정"으로 표기하고, 이미 그 이름들을 예약해 뒀다.

- **무엇**: 봇별 채널 타입(telegram/discord/imessage)을 레지스트리·`launch.env` 에 저장하고, `up_one` 이 타입별 플러그인 ID 와 `<CHANNEL>_STATE_DIR` 환경변수를 선택하도록 일반화.
- **이점**: 한 런처로 여러 채널 봇 관리.
- **주의**: 채널별 토큰/접근제어 차이(imessage 는 토큰 없음·chat.db 의존), `add` 프롬프트·검증 분기. 레지스트리 스키마 변경(하위호환).

### 로그 크래시 커버리지

`down` 스냅샷 방식([완료됨](#완료됨-전제이력))은 `down` 을 거치지 않는 크래시·재부팅을 못 잡는다.

- **무엇**: 보완책으로 tmux `pipe-pane` 연속 기록을 옵트인(per-bot 설정)으로 추가하거나, 주기적 스냅샷.
- **주의**: TUI 의 ANSI 잡음·무한 증가 → 로그 회전·ANSI 스트립 필요. 옵트인 기본 OFF 권장.

### 테스트 커버리지 확장

`tests/` bats 스위트([완료됨](#완료됨-전제이력))는 등록·명령·가드 로직을 격리 상태 트리에서 검증한다. 아직 안 덮은 경로:

- **`up_one`/`down_one` 의 실제 기동 경로** — tmux stub 이 `new-session` 을 no-op 으로 처리하므로 `launch` 문자열 조립(`--settings`·`--permission-mode`·`CLAUDE_EXTRA_ARGS` 주입)은 미검증. stub 이 받은 인자를 파일로 기록해 단언하는 방식으로 확장 가능.
- **`install.sh`/`uninstall.sh`/`update`** — 파일시스템·심볼릭·매니페스트 부수효과가 커서 별도 격리(HOME 샌드박스 + git 픽스처)가 필요. 현재 `bash -n`·shellcheck 만 적용.

## 완료됨 (전제·이력)

후속 작업의 전제가 되는 완료 항목만 짧게 남긴다. 상세는 `CHANGELOG.md`.

- **bats 테스트 스위트 + CI `test` 잡** — `tests/` 에 63개 테스트(add/rm/rename/config/common/status --json/lang/logs/down/doctor/version + 디스패처 + 레지스트리·예약어·상태디렉터리 가드). 격리 상태 트리 + fake tmux(`tests/stubs/tmux`)로 실제 봇 미접촉. 작성 중 stopped 봇의 `config`·`status` 종료코드 1 버그 2건을 발견·수정. 위 [테스트 커버리지 확장](#테스트-커버리지-확장)의 전제.

- **`cmd_*()` 함수 분리** — 단일 `case` 디스패처에 인라인돼 있던 서브커맨드 본문을 16개 `cmd_*()` 함수로 분리. 위 [lib/ 분리](#lib-분리-libexec-본래-의도)의 전제.
- **libexec 승격 (레이아웃)** — copy 설치가 패키지를 `~/.local/libexec/cctg/` 로 복사하고 `~/.local/bin/cctg` 심볼릭. 동반 파일(`VERSION`·`messages/`)이 런처 옆에 위치.
- **CI 게이트** — `.github/workflows/ci.yml` 가 push/PR(main)에서 `bash -n` + `shellcheck -S warning`(로직 스크립트) + `scripts/check-i18n-keys.sh`(i18n 키 패리티)를 자동 실행. PR 템플릿의 수동 shellcheck 체크를 자동화로 승격.
- **CHANGELOG·버전 태깅 규약** — `docs/RELEASING.md` 에 버전 올리기·태그·GitHub Release 절차를 정립. `VERSION` 파일이 SoT, 태그는 `v{VERSION}`.
- **`add` 비대화형 플래그** — `--id`·`--token-env`·`--token-stdin`·`--mode`. 토큰 플래그가 있으면 비대화형으로 전환(–-id 필수, --mode 생략 시 공통 따름). 토큰은 argv 노출을 피해 env/stdin 경유. bash/zsh 자동완성 반영.
- **봇 로그 영속화** — `down` 시 tmux 페인 스냅샷(렌더 텍스트, ~2000줄)을 `<state>/last-session.log`(600)에 저장, `logs` 가 정지 상태에서 그 스냅샷으로 폴백. TUI 의 ANSI 잡음·무한 증가를 피하려 연속 `pipe-pane` 대신 down-스냅샷 방식 채택. 한계는 위 [로그 크래시 커버리지](#로그-크래시-커버리지).
- **`status --json` + BROKEN 복구 힌트** — `status --json` 이 로케일 무관 토큰으로 기계 판독 배열 출력(jq 필요). 텍스트 뷰는 BROKEN 봇 아래 사유별 복구 힌트(`↳ ...`) 출력.
