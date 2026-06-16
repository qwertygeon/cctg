# Project Context

> 작성: 2026-06-16 | 버전: 1.0 | 최종 수정: 2026-06-16 | 상태: 초안(사용자 검토 대기)
>
> 이 문서는 프로젝트의 **현재 상태를 묘사**하는 살아있는 참조 문서다.
> 새로운 spec 설계 전 반드시 읽어 프로젝트 구조·흐름·용어를 숙지한다.
>
> - **갱신 시점**: spec 구현·검증 완료 후, `CHANGES.md` 작성과 같은 시점에 갱신한다.
> - **작성 원칙**: 현재 코드베이스의 사실만 기록한다. 미래 계획·설계 의도는 spec.md 에 작성한다.
> - **constitution.md와의 구분**: constitution 은 "어떻게 만들어야 하는가(원칙)", 본 문서는 "현재 무엇이 존재하는가(사실)".

---

## 1. 프로젝트 개요

- **프로젝트명**: CCTG (Claude Code Tmux Gateway)
- **목적**: macOS에서 프로젝트별 Claude Code Telegram 채널 봇을 각자의 tmux 세션으로 띄우고 관리하는 CLI 런처. 명령은 `cctg`.
- **현재 버전**: v0.2.0
- **주요 기술 스택**: Bash(3.2 호환, 단일 진입점 `cc-tg.sh`), tmux, jq, `caffeinate`(macOS), Claude Code CLI(`claude --channels`), Telegram 채널 플러그인. 패키지 매니저 없음(순수 셸).

---

## 2. 프로젝트 구조

### 디렉토리 레이아웃 / 핵심 모듈 목록

| 모듈 | 위치 | 역할 | 비고 |
|---|---|---|---|
| 런처·디스패처 | `cc-tg.sh` | 전 명령 구현(`cmd_*()`) + 하단 얇은 디스패처. 봇 lifecycle·레지스트리·상태 디렉터리·공통 설정 관리 | 단일 파일(~940줄) |
| 메시지 카탈로그 | `messages/en.sh`, `messages/ko.sh` | i18n 출력 문자열(`CCTG_MSG_*` 스칼라). `t()`/`te()`/`die()` 가 키로 조회 | en=베이스, 선택언어 overlay |
| 자동완성 | `completions/cctg.bash`, `completions/_cctg` | bash/zsh 명령·플래그·봇이름 완성 | zsh 는 `#compdef` |
| 검증 스크립트 | `scripts/check-i18n-keys.sh` | en/ko 키 패리티 + 참조 키 검증 | CI lint |
| 테스트 | `tests/*.bats`, `tests/test_helper.bash`, `tests/stubs/tmux` | 격리 상태 트리 + stateful fake tmux 로 명령·lifecycle 검증(81) | 실제 봇/tmux 무접촉 |
| 설치/제거 | `install.sh`, `uninstall.sh` | copy(libexec) / `--dev`(symlink) 설치, 매니페스트·완성·셸rc 관리, 대칭 제거 | |
| 문서 | `docs/` (RELEASING·TODO·i18n·packaging), `README(.ko).md`, `CONTRIBUTING.md`, `SECURITY.md`, `CHANGELOG.md` | 사용자·기여자 문서 | |
| CI/릴리스 | `.github/workflows/ci.yml`, `release.yml` | lint+test(main) / VERSION 변경→태그·Release 자동 발행 | |
| 버전 SoT | `VERSION` | `v{VERSION}` 태그·`cctg version` 의 단일 소스 | |

---

## 3. 이벤트 및 데이터 흐름

### 3.1 주요 처리 흐름

- **등록 → 기동 → 관찰**: `add <name> <cwd>` (상태 디렉터리 스캐폴딩 + 토큰 `.env` + 텔레그램 ID → `access.json`/allowlist, 레지스트리 행 추가) → `up <name>` (공통 설정 주입 후 detached tmux 세션에서 `caffeinate -is claude --channels <plugin> --settings ... [--permission-mode ...]` 기동) → `status`/`logs`/`attach` 로 관찰 → `down` (스냅샷 후 세션 종료).
- **출력**: 모든 사용자 문자열은 `messages/<lang>.sh` 카탈로그에서 `t()` 로 조회(언어는 startup 1회 고정: `CCTG_LANG` > config `lang=` > 로케일 > en).

### 3.2 이벤트 흐름

- **로그 스냅샷 watcher**: `config <name> snapshot <초>` 설정 시, `up` 이 백그라운드 watcher 를 띄워 N초마다 tmux pane(렌더 텍스트)을 `<state>/last-session.log` 로 재캡처하고 세션 종료 시 자가 종료(`.snapshotter.pid` 로 추적). `down` 이 watcher 정지 + 최종 스냅샷. crash/reboot 후에도 `logs` 가 최근 스냅샷을 보여준다.

### 3.3 상태 흐름 (state machine)

```
봇: (미등록) → registered → running → stopped
                              ↘ BROKEN (cwd 없음 / 토큰 없음 등 issue)
  - 미등록 → registered: add
  - registered → running: up (tmux 세션 생성)
  - running → stopped: down (스냅샷 + 세션 kill)
  - registered/running → BROKEN: status 점검에서 cwd 부재·토큰(.env) 부재 등 발견
  - * → (미등록): rm (--purge 시 상태 디렉터리도 삭제)
```

### 3.4 외부 시스템 연동

- **tmux**: 봇당 세션 `cctg-<name>`. 기동/종료/스냅샷/attach 의 대상.
- **Claude Code CLI**: `claude --channels plugin:telegram@claude-plugins-official --settings <shared> [--permission-mode <m>]` 로 실행.
- **Telegram 채널 플러그인**: 상태 디렉터리(`TELEGRAM_STATE_DIR`)에서 `.env`(토큰)·`access.json`(allowlist) 사용.
- **파일시스템**: 레지스트리·상태 디렉터리·공통 설정·매니페스트(아래 §4).

---

## 4. 도메인 모델

### 핵심 엔티티 / 관계

- **봇(레지스트리 행)**: `projects.conf` 의 `name | working_dir | state_dir`.
- **상태 디렉터리**: 기본 `~/.claude/channels/<name>/` — `.env`(토큰), `launch.env`(`CCTG_PERMISSION_MODE`/`CLAUDE_EXTRA_ARGS`/`CCTG_LOG_SNAPSHOT_INTERVAL`), `access.json`(텔레그램 allowlist), `last-session.log`(스냅샷), `.snapshotter.pid`.
- **공통 설정**: `cctg-shared.settings.json` — 전 봇에 `--settings` 로 주입(권한 `defaultMode`/`deny`/`allow`). 기본 `bypassPermissions` + deny 안전망.
- **설치 매니페스트**: `~/.config/cctg/install.conf` (`repo`/`mode`/`version`/`bindir`/`libexecdir`/`bashcomp`/`zshcomp`/`shellrc`). 사용자 언어 설정 `~/.config/cctg/config` 는 매니페스트와 분리(update 가 보존).

---

## 5. 도메인 용어 사전 (Glossary)

| 용어 | 정의 | 사용 금지 동의어 |
|---|---|---|
| state dir (상태 디렉터리) | 봇별 토큰·설정·로그가 사는 디렉터리(`~/.claude/channels/<name>/`) | data dir |
| registry (레지스트리) | 봇 목록 파일 `projects.conf` (`name\|cwd\|state_dir`) | db |
| shared settings (공통 설정) | 전 봇 주입 권한 정책 `cctg-shared.settings.json` | |
| launch.env | 봇별 기동 옵션(권한 모드·추가 인자·스냅샷 간격) | |
| managed block (관리 블록) | install 이 셸 rc 에 마커(`# >>> cctg >>>`)로 넣는 PATH/완성 블록 | |
| snapshot (스냅샷) | tmux pane 텍스트를 `last-session.log` 로 저장한 것 | |
| BROKEN | 등록됐으나 cwd/토큰 부재 등으로 정상 기동 불가한 상태 | |
| reserved name (예약 이름) | 전역 채널 봇 이름(telegram/discord/imessage/fakechat) — 봇 이름으로 거부 | |

---

## 6. 알려진 제약 및 기술 부채

| 항목 | 내용 | 영향 범위 | 관련 spec |
|---|---|---|---|
| 단일 게이트웨이 | `PLUGIN="plugin:telegram@..."` 하드코딩 + `up` 의 `TELEGRAM_STATE_DIR` 주입 — Telegram 만 구동. discord/imessage 는 README 에 "예정"·이름 예약만 | `cc-tg.sh` up 경로 | (예정) 다중 게이트웨이 |
| 단일 파일 구조 | 전 로직이 `cc-tg.sh`(~940줄) 한 파일. `lib/*.sh` 런타임 분리는 보류(규모 부담 시 착수) | `cc-tg.sh` | (예정) lib 분리 |
| Bash 3.2 제약 | 연관 배열 불가 → 메시지 카탈로그가 스칼라 변수. macOS BSD 도구 의존 | 전체 | — |
| 플랫폼 한정 | `caffeinate` 등 macOS 의존 — Linux/WSL 미지원(의도된 범위) | 전체 | — |
| 컨테이너/DB/서버 부재 | Docker·DB·서버 없음. 로컬 사용자 머신에서 직접 실행 | 전체 | — |

> **CHANGES.md와의 구분**: CHANGES.md 는 "직전 작업에서 생긴 주의사항", 본 섹션은 "현재 시점에서 해소되지 않은 구조적 제약".
