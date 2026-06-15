# cctg TODO

> 향후 작업 후보. 우선순위·근거를 함께 기록한다. 착수 시 해당 항목을 갱신한다.
> 완료 항목의 상세는 `CHANGELOG.md` 가 SoT 이며, 여기에는 후속 작업의 전제로서만 짧게 남긴다.

## 목차

- [구조 / 확장성](#구조--확장성)
  - [lib/ 분리 (libexec 본래 의도)](#lib-분리-libexec-본래-의도)
- [기능 아이디어](#기능-아이디어)
  - [봇 로그 파일 영속화](#봇-로그-파일-영속화)
  - [상태/관찰 추가 개선](#상태관찰-추가-개선)
- [완료됨 (전제·이력)](#완료됨-전제이력)

## 구조 / 확장성

### lib/ 분리 (libexec 본래 의도)

copy 설치의 libexec 레이아웃(`~/.local/libexec/cctg/` 에 `cc-tg.sh`·`VERSION`·`messages/`)과 `cmd_*()` 함수 분리는 이미 완료됐다([완료됨](#완료됨-전제이력) 참조). 남은 것은 `cc-tg.sh` 본체를 런타임 source 하는 `lib/*.sh` 모듈로 쪼개는 단계다.

- **무엇**: 공통 헬퍼(conf_*, set_env_kv, registry 조작 등)와 `cmd_*()` 군을 `lib/*.sh` 로 분리하고, `cc-tg.sh` 는 source + 디스패처만 남긴다. libexec 레이아웃은 이미 동반 파일을 같은 디렉터리에 두므로 `lib/` 도 그대로 수용한다.
- **이점**: 파일별 책임 분리, 명령별 테스트 용이.
- **착수 조건(권장)**: 명령 수가 더 늘거나 단일 파일(현재 ~730줄)이 유지보수에 부담이 될 때. **현재 규모에서는 단일 파일이 더 단순하므로 보류.**
- **주의**: source 경로 해석(`SCRIPT_DIR`)이 copy/dev 양쪽에서 동작하도록 유지. shellcheck 의 SC1090(비상수 source)은 `# shellcheck source=` 디렉티브로 처리.

## 기능 아이디어

### 봇 로그 파일 영속화

현재 봇 출력은 tmux 세션 안에만 있어 `attach`/`logs`(capture-pane)로만 볼 수 있고, 세션 종료 시 사라진다.

- **무엇**: 봇 출력을 상태 디렉터리의 로그 파일(예: `<state>/cctg.log`)로도 영속화. tmux `pipe-pane` 또는 기동 명령에 `tee` 결합.
- **이점**: 종료 후에도 로그 보존, 외부 도구로 분석 가능. `~/.claude/rules` 의 HTTP API E2E 로깅 설계와 유사한 방향.
- **주의**: 로그 회전(날짜별/크기) 정책, 민감정보 노출 검토 필요.

### 상태/관찰 추가 개선

- `status --json` 등 기계 판독 출력(다른 도구 연동용).
- 깨진 봇 자동 복구 힌트(예: BROKEN 사유별 다음 조치 안내).

## 완료됨 (전제·이력)

후속 작업의 전제가 되는 완료 항목만 짧게 남긴다. 상세는 `CHANGELOG.md`.

- **`cmd_*()` 함수 분리** — 단일 `case` 디스패처에 인라인돼 있던 서브커맨드 본문을 16개 `cmd_*()` 함수로 분리. 위 [lib/ 분리](#lib-분리-libexec-본래-의도)의 전제.
- **libexec 승격 (레이아웃)** — copy 설치가 패키지를 `~/.local/libexec/cctg/` 로 복사하고 `~/.local/bin/cctg` 심볼릭. 동반 파일(`VERSION`·`messages/`)이 런처 옆에 위치.
- **CI 게이트** — `.github/workflows/ci.yml` 가 push/PR(main)에서 `bash -n` + `shellcheck -S warning`(로직 스크립트) + `scripts/check-i18n-keys.sh`(i18n 키 패리티)를 자동 실행. PR 템플릿의 수동 shellcheck 체크를 자동화로 승격.
- **CHANGELOG·버전 태깅 규약** — `docs/RELEASING.md` 에 버전 올리기·태그·GitHub Release 절차를 정립. `VERSION` 파일이 SoT, 태그는 `v{VERSION}`.
- **`add` 비대화형 플래그** — `--id`·`--token-env`·`--token-stdin`·`--mode`. 토큰 플래그가 있으면 비대화형으로 전환(–-id 필수, --mode 생략 시 공통 따름). 토큰은 argv 노출을 피해 env/stdin 경유. bash/zsh 자동완성 반영.
