---
작성: Spec Agent
버전: v1.1
최종 수정: 2026-06-17
상태: 확정
---

# Spec: cli-convenience-patches

> Branch: feature/v0.5.0-001-cli-convenience-patches | Date: 2026-06-17 | Version: v0.5.0

## 목차

- [배경 및 목적](#배경-및-목적)
- [사용자 스토리](#사용자-스토리)
- [기능 요구사항](#기능-요구사항)
- [비기능 요구사항](#비기능-요구사항)
- [수용 기준](#수용-기준)
- [요구사항 구조화 매트릭스](#요구사항-구조화-매트릭스)
- [범위 외](#범위-외)
- [미결 사항](#미결-사항)

---

## 배경 및 목적

cctg v0.4.0 기준 편의성·실용성 관련 3개 유형의 불편이 존재한다.

1. **사후 변경 불가**: `add` 로 등록한 봇의 cwd(작업 디렉터리)·token(.env 봇 토큰)을 나중에 바꾸려면 `rm` 후 재등록해야 한다. 프로젝트 폴더 이사·토큰 교체 빈도를 고려할 때 이는 불필요한 마찰이다.

2. **자동완성 미비**: `config <name> mode <TAB>` 시 모드 값 목록이 나오지 않는다. zsh 에서 서브커맨드 설명(hint)이 있으나 config 액션 값에는 없다. 서브커맨드별 `--help` 플래그가 없어 인라인 사용법 확인이 불가하다.

3. **전역 봇 라이프사이클 제어 불가**: 예약어 `telegram`/`discord` 이름으로 `up`/`down`/`status` 등을 시도하면 ERR_NOT_REGISTERED 로 거부된다. 전역 봇 디렉터리(`~/.claude/channels/<ch>/`)에 이미 `.env`·`access.json` 이 존재하므로 구조적으로 라이프사이클 제어는 가능하나, cctg 가 레지스트리 기반으로만 동작하기 때문에 막혀 있다.

본 spec 은 위 3개 유형을 패치하여 cctg 사용 편의성을 높이는 것을 목적으로 한다.

---

## 사용자 스토리

US-001: 봇 운영자로서, 등록된 봇의 작업 디렉터리를 나중에 변경할 수 있기를 원한다 — 프로젝트 폴더 이사 시 rm 후 재등록 없이 경로만 바꾸기 위해.

US-002: 봇 운영자로서, 등록된 봇의 토큰을 나중에 교체할 수 있기를 원한다 — 토큰 만료·재발급 시 재등록 마찰 없이 토큰만 변경하기 위해.

US-003: CLI 사용자로서, `config <name> mode <TAB>` 시 유효한 모드 목록을 바로 볼 수 있기를 원한다 — 유효 값을 외울 필요 없이 자동완성으로 선택하기 위해.

US-004: CLI 사용자로서, `cctg add --help` 등 서브커맨드별 사용법을 인라인으로 확인할 수 있기를 원한다 — man 페이지나 위키 없이 터미널에서 바로 사용법을 보기 위해.

US-005: 봇 운영자로서, `cctg up telegram` / `cctg status` 등으로 전역 telegram/discord 봇의 라이프사이클을 제어하고 상태를 확인할 수 있기를 원한다 — cctg 하나로 프로젝트 봇과 전역 봇을 함께 관리하기 위해.

---

## 기능 요구사항

### 그룹 A: 사후 변경 커맨드

FR-001: `cctg config <name> cwd <path>` 명령이 존재하며, 등록된 봇의 작업 디렉터리를 `<path>` 로 변경하고 레지스트리(`projects.conf`) 2번 컬럼을 원자적으로 갱신한다.
- `<path>` 가 존재하지 않는 디렉터리이면 오류 메시지를 출력하고 변경하지 않는다.
- 봇이 실행 중이면 변경 후 restart 안내 메시지를 출력한다.
- cwd 변경 후 `config <name> show` 에 갱신된 경로가 반영된다.

FR-002: `cctg config <name> token` 명령이 존재하며, 등록된 봇의 봇 토큰을 교체하고 상태 디렉터리 `.env` 를 600 권한으로 재작성한다.
- 토큰 입력 방식은 `add` 와 동일: 대화형 마스킹 입력 / `--token-env <VAR>` / `--token-stdin`. argv 토큰 직접 전달은 허용하지 않는다(constitution P-003).
- 채널 타입에 따른 키 이름은 채널 descriptor(`channel_spec <ch> token_key`) 에서 결정한다 (telegram=`TELEGRAM_BOT_TOKEN`, discord=`DISCORD_BOT_TOKEN`).
- 빈 토큰은 거부하고 오류 메시지를 출력한다.
- 봇이 실행 중이면 변경 후 restart 안내 메시지를 출력한다.

### 그룹 B: 자동완성 보강

FR-003: `cctg config <name> mode <TAB>` 시 유효 모드 6종(acceptEdits / auto / bypassPermissions / default / dontAsk / plan)의 목록이 자동완성으로 제공된다.
- zsh(`completions/_cctg`): `_describe` 또는 `compadd` 로 모드 목록 제공. 설명(hint) 포함.
- bash(`completions/cctg.bash`): `compgen -W` 로 모드 목록 제공(bash 구조상 항목별 설명 불가).

FR-004: 자동완성에서 `config <name>` 의 액션 목록에 신규 액션 `cwd`·`token` 이 추가된다.
- zsh `_cctg` 와 bash `_cctg` 의 config 케이스 양쪽 모두 갱신한다.

FR-005: 각 서브커맨드(`add` / `rm` / `rename` / `config` / `common` / `up` / `down` / `restart` / `status` / `logs` / `attach` / `lang` / `doctor` / `update` / `version` / `help`)에 `--help` 플래그를 전달하면 해당 서브커맨드의 사용법을 출력하고 종료한다.
- 출력 내용은 `t USAGE_<SUBCMD> "$PROG"` 형태로 i18n 카탈로그(en.sh · ko.sh)에서 조회한다.
- 자동완성에서 서브커맨드별 플래그 목록에 `--help` 가 포함된다.

### 그룹 C: 예약어 런타임 지원

FR-006: `cctg up <reserved>` (`<reserved>` = telegram 또는 discord) 명령이 전역 봇 디렉터리(`~/.claude/channels/<reserved>/`)를 상태 디렉터리로 사용하여 전역 봇을 기동한다.
- 기동 전 단독소유자 가드를 수행한다: `cctg-<reserved>` tmux 세션이 이미 존재하거나, 전역 봇 디렉터리의 `bot.pid` 파일이 존재하고 해당 PID 가 살아 있으면 기동을 거부하고 사유를 사용자에게 안내한다.
- 전역 봇의 cwd 는 cctg 호출 시점 현재 작업 디렉터리(`$PWD`)를 사용한다(DEC-001).
- 상태 디렉터리에 `.env` 가 없으면 오류 메시지를 출력하고 중단한다.

FR-007: `cctg down <reserved>` 명령이 `cctg-<reserved>` tmux 세션을 종료한다.
- cctg 가 기동한 tmux 세션(`cctg-<ch>`)만 종료 가능하다. 플러그인 자체 러너(`bot.pid`)는 종료 대상이 아니다(NFR-003).
- 세션이 없으면 "이미 정지됨" 메시지를 출력한다.

FR-008: `cctg restart <reserved>` 명령이 `down → up` 을 수행한다 (FR-007 → FR-006 순서).

FR-009: `cctg status` 가 예약어 봇(telegram/discord)의 상태(RUNNING/stopped/BROKEN)를 프로젝트 봇과 동일 형식으로 출력한다.
- 전역 봇의 cwd 는 cctg 호출 시점 현재 작업 디렉터리(`$PWD`)(DEC-001), 상태 디렉터리는 `~/.claude/channels/<ch>/`.
- 레지스트리에 없으므로 별도 경로로 조회한다.

FR-010: `cctg logs <reserved> [N]` 명령이 `cctg-<reserved>` tmux 세션의 로그 또는 `last-session.log` 스냅샷을 출력한다.

FR-011: 예약어 이름에 대한 `add` / `rm` / `rename` 은 기존과 동일하게 ERR_RESERVED 로 차단한다.

---

## 비기능 요구사항

NFR-001: 모든 신규 명령·플래그·메시지는 macOS / Bash 3.2 에서 동작한다(연관 배열 미사용, 스칼라·case 기반). (constitution P-001)

NFR-002: 전역 봇 상태 디렉터리(`~/.claude/channels/<ch>/`)의 `.env`·`access.json` 을 덮어쓰거나 삭제하지 않는다. 쓰기는 cctg 가 기동·종료 과정에서 생성하는 파일(스냅샷·pid 제외)에 한정한다. (constitution P-002)

NFR-003: `cctg down <reserved>` 는 cctg 가 생성한 tmux 세션(`cctg-<ch>`)만 종료한다. 전역 봇 플러그인 자체 러너(`bot.pid` 기반 프로세스)는 종료 대상이 아니며, 이 한계를 사용자 안내 메시지로 명시한다.

NFR-004: 토큰은 argv 에 노출되지 않는다. `config <name> token` 의 입력 경로는 대화형 마스킹 / `--token-env <VAR>` / `--token-stdin` 으로 제한한다. (constitution P-003)

NFR-005: 레지스트리 갱신(cwd 변경)은 awk+mktemp+mv 원자적 패턴을 사용하여 중간 실패 시 원본을 보존한다. (registry.sh 기존 패턴 준용)

NFR-006: 자동완성 파일(`completions/_cctg`, `completions/cctg.bash`)은 `lib/channels.sh` 를 source 하지 않고 로컬 리터럴 미러 방식을 유지한다. (ADR-003)

NFR-007: 모든 신규 사용자 출력 문자열은 `messages/en.sh`·`messages/ko.sh` 카탈로그에 `CCTG_MSG_<KEY>` 키로 추가하고 `t()`/`die()` 로 조회한다. en.sh 와 ko.sh 의 키 패리티를 유지한다.

---

## 수용 기준

### 그룹 A: 사후 변경 커맨드

SC-001 (FR-001 관련): `config <name> cwd <path>` 가 레지스트리 2번 컬럼을 갱신한다.
- Given: 봇 `mybot` 이 cwd `/old/path` 로 등록됨 (디렉터리 존재)
- When: `cctg config mybot cwd /new/path` 실행 (디렉터리 존재)
- Then: `projects.conf` 의 mybot 행 2번 컬럼이 `/new/path` 로 변경되고, 성공 메시지 출력
[env:unit]

SC-002 (FR-001 관련): 존재하지 않는 경로를 cwd 로 지정하면 오류를 출력하고 레지스트리를 변경하지 않는다.
- Given: 봇 `mybot` 이 등록됨
- When: `cctg config mybot cwd /nonexistent/path` 실행
- Then: 오류 메시지 출력, 종료 코드 비-0, `projects.conf` 의 mybot cwd 변경 없음
[env:unit]

SC-003 (FR-001 관련): cwd 변경 후 봇이 실행 중이면 restart 안내 메시지를 출력한다.
- Given: 봇 `mybot` 이 실행 중(tmux 세션 존재)
- When: `cctg config mybot cwd /new/path` 실행
- Then: 레지스트리 갱신 + restart 안내 메시지 출력
[env:unit]

SC-004 (FR-002 관련): `config <name> token` 이 .env 를 채널 토큰 키로 재작성하고 권한 600 을 적용한다.
- Given: 봇 `mybot` (telegram 채널) 이 등록됨
- When: `cctg config mybot token` 실행 후 `--token-stdin` 입력으로 새 토큰 제공
- Then: `~/.claude/channels/mybot/.env` 에 `TELEGRAM_BOT_TOKEN=<new_token>` 이 기록되고 권한 600 확인
[env:unit]

SC-005 (FR-002 관련): 빈 토큰을 제공하면 오류를 출력하고 .env 를 변경하지 않는다.
- Given: 봇 `mybot` 이 등록됨
- When: `cctg config mybot token --token-stdin` 에 빈 입력 제공
- Then: ERR_EMPTY_TOKEN 메시지 출력, 종료 코드 비-0, .env 변경 없음
[env:unit]

SC-006 (FR-002 관련): discord 봇의 token 변경 시 DISCORD_BOT_TOKEN 키를 사용한다.
- Given: 봇 `discordbot` (discord 채널) 이 등록됨
- When: `cctg config discordbot token --token-stdin` 에 새 토큰 제공
- Then: `.env` 에 `DISCORD_BOT_TOKEN=<new_token>` 기록, 권한 600
[env:unit]

### 그룹 B: 자동완성 보강

SC-007 (FR-003 관련): zsh 자동완성에서 `config <name> mode <TAB>` 이 6개 모드 목록을 제공한다.
- Given: `completions/_cctg` 설치됨
- When: `cctg config mybot mode <TAB>` 입력
- Then: acceptEdits / auto / bypassPermissions / default / dontAsk / plan 6종이 완성 후보로 나타남
[env:static]

SC-008 (FR-003 관련): bash 자동완성에서 `config <name> mode <TAB>` 이 6개 모드 단어 목록을 제공한다.
- Given: `completions/cctg.bash` 설치됨
- When: `cctg config mybot mode <TAB>` 입력
- Then: 6개 모드 값이 COMPREPLY 에 포함됨
[env:static]

SC-009 (FR-004 관련): zsh·bash 자동완성 양쪽에서 `config <name> <TAB>` 액션 목록에 `cwd`·`token` 이 포함된다.
- Given: 완성 파일 설치됨
- When: `cctg config mybot <TAB>` 입력
- Then: show / edit / mode / args / snapshot / cwd / token 7종이 후보에 포함됨
[env:static]

SC-010 (FR-005 관련): `cctg add --help` 가 add 서브커맨드의 사용법을 출력한다.
- Given: cctg 설치됨
- When: `cctg add --help` 실행
- Then: add 의 사용법(인자·플래그 설명) 출력, 종료 코드 0
[env:unit]

SC-011 (FR-005 관련): `cctg config --help` 가 config 서브커맨드의 사용법을 출력한다.
- Given: cctg 설치됨
- When: `cctg config --help` 실행
- Then: config 의 사용법 출력, 종료 코드 0
[env:unit]

SC-012 (FR-005 관련): 자동완성에서 서브커맨드 플래그 목록에 `--help` 가 포함된다.
- Given: 완성 파일 설치됨
- When: `cctg add <TAB>` (플래그 위치)
- Then: --help 가 완성 후보에 포함됨
[env:static]

SC-013 (NFR-007 관련): en.sh 와 ko.sh 의 신규 메시지 키가 동일하게 존재한다(패리티).
- Given: 신규 메시지 키(CFG_CWD_SET, CFG_CWD_USAGE, CFG_TOKEN_SET, ERR_NO_SUCH_DIR, RESERVED_UP, RESERVED_DOWN_LIMIT, RESERVED_UP_OCCUPIED, USAGE_ADD, USAGE_CONFIG 등) 추가됨
- When: `bash scripts/check-i18n-keys.sh` 실행
- Then: 종료 코드 0 (패리티 오류 없음)
[env:unit]

### 그룹 C: 예약어 런타임 지원

SC-014 (FR-006 관련): `cctg up telegram` 이 cctg-telegram tmux 세션을 기동한다.
- Given: `~/.claude/channels/telegram/.env` 에 TELEGRAM_BOT_TOKEN 존재, cctg-telegram 세션 없음, bot.pid 없음
- When: `cctg up telegram` 실행
- Then: `cctg-telegram` tmux 세션이 생성됨, 성공 메시지 출력
[env:unit]

SC-025 (FR-006 관련): `cctg up telegram` 기동 시 전역 봇의 cwd 가 cctg 호출 시점의 현재 작업 디렉터리로 설정된다.
- Given: `~/.claude/channels/telegram/.env` 존재, cctg-telegram 세션 없음, 터미널 현재 디렉터리 = `/some/project`
- When: `/some/project` 에서 `cctg up telegram` 실행
- Then: `cctg-telegram` tmux 세션의 시작 디렉터리가 `/some/project` 임
[env:unit]

SC-015 (FR-006 관련): 단독소유자 가드 — cctg-telegram 세션이 이미 존재하면 기동을 거부한다.
- Given: `cctg-telegram` tmux 세션이 이미 존재
- When: `cctg up telegram` 실행
- Then: 오류 메시지 출력(이미 실행 중), 종료 코드 비-0, 새 세션 생성 안 됨
[env:unit]

SC-016 (FR-006 관련): 단독소유자 가드 — bot.pid 가 존재하고 PID 가 살아 있으면 기동을 거부한다.
- Given: `~/.claude/channels/telegram/bot.pid` 에 살아 있는 PID 기록
- When: `cctg up telegram` 실행
- Then: 오류 메시지 출력(전역 봇 러너 실행 중), 종료 코드 비-0
[env:unit]

SC-017 (FR-006 관련): 전역 봇 `.env` 가 없으면 오류를 출력하고 기동하지 않는다.
- Given: `~/.claude/channels/telegram/.env` 없음
- When: `cctg up telegram` 실행
- Then: 오류 메시지 출력(토큰 없음), 종료 코드 비-0
[env:unit]

SC-018 (FR-007 관련): `cctg down telegram` 이 cctg-telegram tmux 세션을 종료한다.
- Given: `cctg-telegram` tmux 세션이 실행 중
- When: `cctg down telegram` 실행
- Then: 세션이 종료됨, 성공 메시지 출력
[env:unit]

SC-019 (FR-007 / NFR-003 관련): `cctg down telegram` 은 bot.pid 러너를 종료하지 않는다.
- 구조적 한계 SC: down_one() 은 tmux kill-session 만 수행하며(session.sh:114), bot.pid kill 로직이 존재하지 않음. 이 한계를 사용자 출력 메시지로 명시하는 것이 검증 대상.
- Given: `cctg-telegram` 세션 없음(플러그인 러너로만 기동)
- When: `cctg down telegram` 실행
- Then: "세션 없음" 메시지 출력, bot.pid 관련 종료 시도 없음
[env:unit]

SC-020 (FR-009 관련): `cctg status` 출력에 전역 봇(telegram/discord)의 상태가 포함된다.
- Given: `~/.claude/channels/telegram/` 디렉터리 존재, cctg-telegram 세션 없음
- When: `cctg status` 실행
- Then: telegram 봇이 [stopped] 또는 [BROKEN] 으로 출력됨
[env:unit]

SC-021 (FR-010 관련): `cctg logs telegram` 이 cctg-telegram 세션 로그 또는 last-session.log 를 출력한다.
- Given: cctg-telegram 세션이 실행 중
- When: `cctg logs telegram` 실행
- Then: tmux capture-pane 결과를 출력
[env:unit]

SC-022 (FR-011 관련): 예약어 이름으로 `add`·`rm`·`rename` 은 여전히 ERR_RESERVED 로 거부된다.
- Given: cctg 설치됨
- When: `cctg add telegram /some/path` 실행
- Then: ERR_RESERVED 메시지 출력, 종료 코드 비-0
[env:unit]

SC-023 (NFR-001 관련): 모든 신규 코드가 Bash 3.2 구문을 사용한다.
- 연관 배열(`declare -A`), `{BASH_REMATCH}` 이외 Bash 4+ 기능 미사용. 정적 확인.
[env:static]

SC-024 (NFR-002 관련): `cctg down telegram` 이 `.env`·`access.json` 을 수정하지 않는다.
- Given: `~/.claude/channels/telegram/.env`, `access.json` 존재
- When: `cctg down telegram` 실행
- Then: 두 파일의 내용·mtime 변경 없음
[env:unit]

---

## 요구사항 구조화 매트릭스

| US-ID | FR-ID | NFR-ID | SC-ID | [env:*] | MoSCoW |
|---|---|---|---|---|---|
| US-001 | FR-001 | NFR-005 | SC-001 | unit | Must |
| US-001 | FR-001 | — | SC-002 | unit | Must |
| US-001 | FR-001 | — | SC-003 | unit | Must |
| US-002 | FR-002 | NFR-004 | SC-004 | unit | Must |
| US-002 | FR-002 | NFR-004 | SC-005 | unit | Must |
| US-002 | FR-002 | — | SC-006 | unit | Must |
| US-003 | FR-003 | NFR-006 | SC-007 | static | Must |
| US-003 | FR-003 | NFR-006 | SC-008 | static | Must |
| US-003 | FR-004 | NFR-006 | SC-009 | static | Must |
| US-004 | FR-005 | NFR-007 | SC-010 | unit | Must |
| US-004 | FR-005 | NFR-007 | SC-011 | unit | Must |
| US-004 | FR-005 | NFR-006 | SC-012 | static | Should |
| US-004 | FR-005 | NFR-007 | SC-013 | unit | Must |
| US-005 | FR-006 | NFR-002 | SC-014 | unit | Must |
| US-005 | FR-006 | — | SC-025 | unit | Must |
| US-005 | FR-006 | NFR-002 | SC-015 | unit | Must |
| US-005 | FR-006 | NFR-002 | SC-016 | unit | Must |
| US-005 | FR-006 | NFR-002 | SC-017 | unit | Must |
| US-005 | FR-007 | NFR-003 | SC-018 | unit | Must |
| US-005 | FR-007 | NFR-003 | SC-019 | unit | Must |
| US-005 | FR-009 | — | SC-020 | unit | Must |
| US-005 | FR-010 | — | SC-021 | unit | Must |
| US-005 | FR-011 | — | SC-022 | unit | Must |
| — | — | NFR-001 | SC-023 | static | Must |
| — | — | NFR-002 | SC-024 | unit | Must |
| US-005 | FR-008 | — | — | — | Must |

> FR-008(restart 예약어): down(SC-018) + up(SC-014) 의 조합 동작. 별도 SC 는 기존 SC 검증으로 충분하므로 통합 테스트에서 검증.

---

## 범위 외

- **channel 사후 변경** (telegram↔discord 전환): 채널 변경은 access.json·launch.env 구조 재생성이 필요하여 re-add 와 동등한 복잡도. 이 spec 에서 제외.
- **allowlist / telegram-id 사후 변경**: access.json 직접 편집(`cctg config <name> edit`)으로 우회 가능. 이 spec 에서 제외.
- **discord groups 사후 변경**: 동일 이유. 이 spec 에서 제외.
- **imessage/fakechat 예약어 런타임 지원**: 미구현 채널. channel_spec 케이스가 없어 plugin/statedir_env 미정. 이 spec 에서 제외.
- **전역 봇 add/rm/rename**: constitution P-002 보호 대상. 차단 유지.
- **bot.pid 러너 종료**: cctg 가 기동하지 않은 프로세스를 종료하는 것은 P-002 비침해 원칙에 맞지 않음. `down` 은 tmux 세션 범위만 담당.

**사후 운영 검증 피드백 사이클**:

본 spec 파이프라인 종료 후 사용자가 운영 환경에서 점검할 시나리오:
1. 예약어 `up telegram` 후 DM 응답 정상 확인.
2. bot.pid 생존 상태에서 `up telegram` 거부 안내 메시지 확인.
3. `config mybot cwd` 변경 후 `up mybot` 으로 봇이 새 경로에서 정상 기동 확인.
4. `config mybot token` 변경 후 `restart mybot` 으로 새 토큰 적용 확인.

결함 발견 시: 본 spec.md "배경 및 목적" 또는 별도 hotfix spec 으로 재진입.

---

## 미결 사항

없음. [NEEDS CLARIFICATION] 0건.
