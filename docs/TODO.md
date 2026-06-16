# cctg TODO

> 향후 작업 후보. 우선순위·근거를 함께 기록한다. 착수 시 해당 항목을 갱신한다.
> 완료한 항목은 여기서 제거한다. 완료 이력은 `CHANGELOG.md`(+ git 이력)가 SoT.

## 목차

- [구조 / 확장성](#구조--확장성)
  - [lib/ 분리 (libexec 본래 의도)](#lib-분리-libexec-본래-의도)
- [기능 아이디어](#기능-아이디어)
  - [다중 게이트웨이 지원 (discord/imessage)](#다중-게이트웨이-지원-discordimessage)
  - [테스트 커버리지 확장](#테스트-커버리지-확장)

## 구조 / 확장성

### lib/ 분리 (libexec 본래 의도)

copy 설치의 libexec 레이아웃(`~/.local/libexec/cctg/` 에 `cc-tg.sh`·`VERSION`·`messages/`)과 `cmd_*()` 함수 분리는 이미 완료됐다(CHANGELOG 참조). 남은 것은 `cc-tg.sh` 본체를 런타임 source 하는 `lib/*.sh` 모듈로 쪼개는 단계다.

- **무엇**: 공통 헬퍼(conf_*, set_env_kv, registry 조작 등)와 `cmd_*()` 군을 `lib/*.sh` 로 분리하고, `cc-tg.sh` 는 source + 디스패처만 남긴다. libexec 레이아웃은 이미 동반 파일을 같은 디렉터리에 두므로 `lib/` 도 그대로 수용한다.
- **이점**: 파일별 책임 분리, 명령별 테스트 용이.
- **착수 조건(권장)**: 명령 수가 더 늘거나 단일 파일(현재 ~940줄)이 유지보수에 부담이 될 때. **현재 규모에서는 단일 파일이 더 단순하므로 보류.**
- **주의**: source 경로 해석(`SCRIPT_DIR`)이 copy/dev 양쪽에서 동작하도록 유지. shellcheck 의 SC1090(비상수 source)은 `# shellcheck source=` 디렉티브로 처리.

## 기능 아이디어

### 다중 게이트웨이 지원 (discord/imessage)

현재 CCTG 는 Telegram 만 구동한다(`PLUGIN="plugin:telegram@..."` 하드코딩, `up_one` 의 `TELEGRAM_STATE_DIR` 주입). README 「지원 게이트웨이」 표는 discord·imessage 를 "예정"으로 표기하고, 이미 그 이름들을 예약해 뒀다.

- **무엇**: 봇별 채널 타입(telegram/discord/imessage)을 레지스트리·`launch.env` 에 저장하고, `up_one` 이 타입별 플러그인 ID 와 `<CHANNEL>_STATE_DIR` 환경변수를 선택하도록 일반화.
- **이점**: 한 런처로 여러 채널 봇 관리.
- **주의**: 채널별 토큰/접근제어 차이(imessage 는 토큰 없음·chat.db 의존), `add` 프롬프트·검증 분기. 레지스트리 스키마 변경(하위호환).

### 테스트 커버리지 확장

`tests/` bats 스위트는 등록·명령·라이프사이클(up/down/restart)·스냅샷 watcher·가드 로직을 격리 상태 트리 + stateful fake tmux 로 검증한다. 아직 안 덮은 경로:

- **`launch` 문자열 내용 검증** — stub 이 세션 생성/종료(`-s`/`-t`)는 추적하지만 `new-session` 의 명령 인자 본문(`--settings`·`--permission-mode`·`CLAUDE_EXTRA_ARGS` 주입)은 단언하지 않는다. stub 이 받은 전체 argv 를 파일로 기록해 검증하는 방식으로 확장 가능.
- **`install.sh`/`uninstall.sh`/`update`** — 파일시스템·심볼릭·매니페스트 부수효과가 커서 별도 격리(HOME 샌드박스 + git 픽스처)가 필요. 현재 `bash -n`·shellcheck 만 적용.
