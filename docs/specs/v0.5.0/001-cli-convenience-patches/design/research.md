---
작성: Design Agent
버전: v1.0
최종 수정: 2026-06-17 22:39
상태: 확정
---

# Research: cli-convenience-patches

> Branch: feature/v0.5.0-001-cli-convenience-patches | Plan: [plan.md](../planning/plan.md) | Spec: [spec.md](../spec/spec.md)

## 목차

- [요약](#요약)
- [기존 코드베이스 분석](#기존-코드베이스-분석)
  - [모듈 계층 구조 (변경 대상 한정)](#모듈-계층-구조-변경-대상-한정)
  - [영향 범위 분석 (호출 측 전수)](#영향-범위-분석-호출-측-전수)
  - [공유 상태·동시성 분석](#공유-상태동시성-분석)
- [외부 라이브러리 API 실제 동작 확인](#외부-라이브러리-api-실제-동작-확인)
- [§F production 시그니처 변경 — 호출 측 테스트 식별](#f-production-시그니처-변경--호출-측-테스트-식별)
- [doctrine·제약 대조](#doctrine제약-대조)
- [context.md 부정합 사전 점검 (PATCH-A11)](#contextmd-부정합-사전-점검-patch-a11)
- [배포 환경 영향 추정 (PATCH-A10)](#배포-환경-영향-추정-patch-a10)
- [기술 선택 조사 (plan ADR cross-check)](#기술-선택-조사-plan-adr-cross-check)
- [엣지 케이스 및 한계](#엣지-케이스-및-한계)
- [completeness critic](#completeness-critic)

---

## 요약

본 spec 은 순수 Bash CLI(cctg) 의 편의성 패치 3그룹이다. **외부 라이브러리 신규 도입 0건** — 사용 명령은 모두 OS 표준(tmux/awk/mktemp/mv/chmod/kill/grep)이고 기존 `lib/session.sh`·`lib/registry.sh` 에서 검증된 패턴을 재사용한다. plan.md 핵심설계의 코드 인용(라인 번호)을 실제 `lib/*.sh` 와 대조하여 전부 정확함을 확인했다. 변경은 모두 **신규 함수 추가 + 기존 case 분기 추가**이며 기존 함수 시그니처를 바꾸지 않으므로 §F 호출측 마이그레이션이 발생하지 않는다. context.md 부정합 0건(스키마·용어 불변). 신규 GAP 0건.

> 분석 우선순위 게이트(03-design §분석우선순위): plan.md "핵심 설계" 의 변경 대상 모듈(`lib/commands.sh`·`lib/session.sh`·`lib/registry.sh`·`completions/_cctg`·`completions/cctg.bash`·`messages/en.sh`·`messages/ko.sh`·`cc-tg.sh`)에 분석 범위를 한정. §D(다단계 병렬 파이프라인)·외부 라이브러리 검증(§13/§14/PROC-013)은 트리거 미충족으로 해당 없음.

---

## 기존 코드베이스 분석

> 전체 구조는 context.md §2 핵심 모듈 목록 참조. 본 절은 변경 대상에 한정한 사실 검증.

### 모듈 계층 구조 (변경 대상 한정)

Bash 모듈은 클래스 상속이 없다. `cc-tg.sh` 가 `lib/*.sh` 를 정의 전용으로 source(`cc-tg.sh:60-74`)한 뒤 디스패처(`cc-tg.sh:83-106`)가 `cmd_*` 로 라우팅한다. 호출 의존 방향:

- `cmd_config`(`commands.sh:228`) → `lookup`/`expand`(registry.sh) · `set_env_kv`/`mode_of`(config.sh) · `channel_spec`/`channel_of`(channels.sh) · `is_running`(session.sh) · `t`/`te`/`die`(output.sh).
- `cmd_up/down/restart/status/logs`(`commands.sh:337/346/355/364/451`) → `up_one`/`down_one`(session.sh) · `lookup`/`all_names`(registry.sh) · `is_reserved_name`(registry.sh:5).
- `up_one`/`down_one`(session.sh:62/106) → `lookup`/`expand` · `channel_of`/`channel_spec` · `sess_of`/`is_running`(session.sh:5-6) · `ensure_shared_settings`(util.sh) · `start_snapshotter`/`stop_snapshotter`/`take_snapshot`(session.sh).

신규 함수 배치(레이어 정합):
- `set_registry_cwd`(신규) → `lib/registry.sh` — 기존 `rename_registry_line`(registry.sh:27) 와 동형 레이어.
- `up_reserved`/`down_reserved`/`reserved_runner_alive`(신규) → `lib/session.sh` — 기존 `up_one`/`down_one` 와 동형 레이어.
- `sub_usage`(신규) → `lib/util.sh`(또는 `commands.sh`) — `usage`(util.sh:55) 와 동형.
- `cwd)`/`token)` case → `cmd_config`(commands.sh) 내부. `is_reserved_name` 분기 → 각 `cmd_up/down/restart/status/logs` 진입부.

> ABC/인터페이스 변경 없음(Bash). pure virtual·protected 생성자 해당 없음.

### 영향 범위 분석 (호출 측 전수)

| 파일 | 변경 유형 | 영향 내용 | 호출 측 영향 |
|---|---|---|---|
| `lib/registry.sh` | 신규 함수 `set_registry_cwd` 추가 | cwd(2번 컬럼) 원자 갱신 | 신규 — 기존 함수 미수정. 호출자=`cmd_config` cwd 분기뿐 |
| `lib/commands.sh` | `cmd_config` 에 `cwd)`·`token)` case 추가 | 기존 `case "$ACTION"`(commands.sh:251) 의 `show/edit/mode/args/snapshot/*` 불변, 신규 2 arm 삽입 | 기존 액션 호출자 영향 0 (case 추가만) |
| `lib/commands.sh` | `cmd_up/down/restart/status/logs` 진입부 `is_reserved_name` 분기 추가 | 비예약어 인자는 기존 경로 그대로(early return 후 분기) | 비예약어 호출 100% 보존(하위호환) |
| `lib/session.sh` | 신규 `up_reserved`/`down_reserved`/`reserved_runner_alive` 추가 | up_one/down_one 의 예약어판(좌표 고정) | 기존 up_one/down_one 미수정 |
| `lib/util.sh`(또는 commands.sh) | 신규 `sub_usage` 추가 | 서브커맨드별 USAGE 라우팅 | 신규 — 호출자=cc-tg.sh --help 선검사뿐 |
| `cc-tg.sh` | case 디스패치 직전 `--help`/`-h` 선검사 블록 추가 | 기존 top-level `help\|--help\|-h\|""`(cc-tg.sh:99) 와 무충돌(CMD 확정 후 인자 스캔) | `cctg --help`(=top usage) vs `cctg add --help`(=add usage) 분리. 기존 디스패치 불변 |
| `completions/_cctg` | config 액션에 `cwd token` + mode 값 6종 + 서브커맨드 `--help` 후보 추가 | `_cctg:60` 액션 리터럴 확장, 신규 mode 케이스(CURRENT==5) | 다른 케이스 불변 |
| `completions/cctg.bash` | 동일 미러 — config 액션 `cwd token` + mode 6종 + `--help` | `cctg.bash:30` 액션 리터럴 확장, config COMP_CWORD==4 mode 케이스 | 다른 케이스 불변 |
| `messages/en.sh`·`ko.sh` | 신규 `CCTG_MSG_*` 키 추가 | 기존 키 미수정. en/ko 패리티 유지 | t/te/die 신규 키 참조만 |

**"컴파일 대상 제외 vs 호출 안 됨" 구분**: 셸은 컴파일 단위 없음. 모든 `lib/*.sh` 가 `cc-tg.sh:60-74` 에서 무조건 source 되므로 신규 함수는 정의 즉시 호출 가능. 누락 위험 없음.

**검증된 plan 핵심설계 사실 (코드 대조)**:
- `lookup`(registry.sh:50-57) 은 매치 행에서 **`$2"\t"$3`** = `cwd<TAB>state_dir` 출력 — 확인. 따라서 호출측 `cut -f1`=cwd, `cut -f2`=state_dir.
- `cmd_config`(commands.sh:231-232): `row="$(lookup "$NAME")" || die ERR_NOT_REGISTERED`; `sd="$(expand "$(cut -f2 <<<"$row")")"` — cwd 는 `cut -f1` 로 추가 확보 가능(현재 미사용). 미등록 name 은 232행 도달 전 거부.
- `cmd_status`(commands.sh:374-375): 프로젝트 봇은 `cwd="$(expand "$(cut -f1 <<<"$row")")"` 로 cwd 확보. 예약어는 lookup 불가 → `cwd="$PWD"`(DEC-001) 별도 경로 필요. status 의 헤더 `STATUS_GLOBAL`(commands.sh:368)·`STATUS_PROJECT_HEADER`(369) 사이/후에 예약어 섹션 삽입.
- `set_env_kv`(config.sh:32) 는 `KEY="value"` 따옴표 upsert — token 분기는 `.env` 를 토큰 키 1줄 **전체 재작성**(cmd_add commands.sh:69 와 동일)이라 set_env_kv 가 아닌 `printf '%s=%s\n' > "$sd/.env"` 사용이 정합(따옴표 없음 — .env 는 `set -a; source` 로 읽히므로 cmd_add 와 동일 무따옴표 형식 유지해야 함).
- `is_reserved_name`(registry.sh:5)·`channel_spec`(channels.sh:16)·`sess_of`(session.sh:5)·`reserved_runner_alive` 의 `kill -0` — 전부 기존 패턴 또는 POSIX 표준.

> **token 분기 .env 형식 주의 (Design 확정)**: plan.md A-2 의 `printf '%s=%s\n' "$tk" "$NEWTOK" > "$sd/.env"`(plan.md:145) 가 정확하다. cmd_add(commands.sh:69) 가 `printf '%s=%s\n' "$(channel_spec ...)" "$TOKEN" > "$SD/.env"` 로 **따옴표 없는** `KEY=value` 를 쓰며, up_one(session.sh:88) 이 `set -a && source "$sd/.env"` 로 읽으므로 token 값에 공백이 없는 전제(봇 토큰은 공백 없음)에서 정합. SC-004/006 기대(`TELEGRAM_BOT_TOKEN=<new>` / `DISCORD_BOT_TOKEN=<new>`)와 일치. set_env_kv(따옴표 부가) 사용 금지 — cmd_add 와 형식 불일치 유발.

### 공유 상태·동시성 분석

- **레지스트리 갱신(set_registry_cwd)**: `awk ... > tmp && mv tmp "$REGISTRY"`(registry.sh:15-44 패턴) — mv 가 원자적이라 동시 reader 가 부분 파일을 보지 않음(NFR-005). 단일 cctg 프로세스 가정(CLI 1회 호출)이라 writer 경합 없음. **Lock 불요** — 이유: cctg 는 사용자가 셸에서 1회 실행하는 단발 CLI 이며, 동시 다중 실행은 사용자 책임 영역(기존 rename/rm 도 동일 무락 패턴).
- **단독소유자 가드(up_reserved)**: Check-Then-Act 패턴 존재 — `is_running` 체크 + `reserved_runner_alive` 체크 후 `tmux new-session`. cctg-측 이중 기동은 양쪽 검사로 차단(plan ADR-007). 단 cctg 와 플러그인 러너(bot.pid 소유) 간 진정한 상호배제는 OS lock 이 아님 — TOCTOU window 존재(체크와 new-session 사이). **수용 가능** — 이유: bot.pid 는 플러그인 소유라 cctg 가 lock 을 강제할 수단이 없고(P-002 비침해), stale bot.pid 허용 정책으로 영구 락아웃을 회피하며, 한계를 NFR-003 사용자 안내로 명시. 운영 검증(PROC-014)으로 사후 확인.
- **stale bot.pid 처리**: `reserved_runner_alive` 는 `[ -f pidf ]` + `kill -0 pid` — PID 죽으면 false 반환(기동 허용). cctg 는 bot.pid 를 쓰지 않으므로 정리는 플러그인 책임(P-002).
- **down_reserved 스냅샷 회피**: down_one(session.sh:111-113) 은 `stop_snapshotter`+`take_snapshot` 호출. 전역 봇은 cctg launch.env·watcher 가 없으므로 down_reserved 는 이들을 **호출하지 않음**(ADR-008) → `.env`/`access.json`/`.snapshotter.pid` 미접근(SC-024 P-002 안전).

---

## 외부 라이브러리 API 실제 동작 확인

**해당 없음 — 신규 외부 라이브러리 API 의존 0건.**

- plan.md 기술컨텍스트(plan.md:52-54) 및 Constitution Gate P-001 과 일치: 사용 외부 명령은 모두 OS 표준이며 기존 코드에서 검증된 패턴 재사용.
- `tmux has-session/new-session/kill-session/capture-pane/display-message`: 기존 `is_running`(session.sh:6)·`up_one`(session.sh:95)·`down_one`(session.sh:114)·`cmd_logs`(commands.sh:454) 에서 사용 중. 테스트는 fake tmux stub(`tests/stubs/tmux`)로 결정적 검증 — new-session 은 `-s` 세션을 state 파일에 기록, kill-session 은 제거, has-session 은 grep 판정(stub 30-45행 확인).
- `kill -0 <pid>`: POSIX 표준 시그널 0(존재·권한 확인, 시그널 미전송). macOS Bash 3.2 지원 — ASM-004 확정. private API·lifecycle flag 아님 → PROC-013 4시나리오 해당 없음.
- `${!var}` 간접 확장: cmd_add(commands.sh:46) 가 이미 사용 — Bash 3.2 지원 확인. P-001 안전.
- `awk`/`mktemp`/`mv`/`chmod`/`grep`: 기존 registry.sh·config.sh·commands.sh 전반 사용.

> public/private API 우선(PATCH-A14)·PROC-013 lifecycle 4시나리오: 외부 라이브러리 신규 도입이 없어 트리거 미충족. 적용 없음.

---

## §F production 시그니처 변경 — 호출 측 테스트 식별

**production 메서드 시그니처 변경 0건 → 호출 측 마이그레이션 불요.**

본 spec 의 변경은 전부 (1) 신규 함수 추가, (2) 기존 `case` 에 새 arm 추가, (3) 진입부 early 분기 추가다. 기존 함수의 인자·반환·동작을 바꾸지 않는다.

| 신규/변경 | 종류 | 기존 호출측 영향 |
|---|---|---|
| `set_registry_cwd <name> <newcwd>` | 신규 함수 | 없음(신규 호출자만) |
| `up_reserved`/`down_reserved`/`reserved_runner_alive` | 신규 함수 | 없음 |
| `sub_usage <subcmd>` | 신규 함수 | 없음 |
| `cmd_config` `cwd)`/`token)` arm | case 추가 | 기존 `show/edit/mode/args/snapshot`(commands.sh:252-293) 시그니처·동작 불변 |
| `cmd_up/down/restart/status/logs` 진입부 분기 | early branch | 비예약어 인자 = 기존 코드 경로 100% 보존 |
| `cc-tg.sh` `--help` 선검사 | dispatcher 추가 | 기존 case(cc-tg.sh:83-106) 불변 |

**기존 테스트 회귀 안전 예측 (PROC-001/002/003/004 점검)**:
- 기존 bats 스위트(`up_down.bats`·`config.bats`·`status_view.bats`·`status_json.bats` 등 81개)는 **비예약어 봇**(seed_bot=mybot/a/b)을 대상으로 한다. 신규 `is_reserved_name` 분기는 예약어(telegram/discord)일 때만 발동하므로 기존 테스트 입력(mybot 등)은 분기를 타지 않음 → 기존 경로 그대로 PASS 예측.
  - representation/binding(PROC-001/002): bats 단언은 stdout 텍스트(`$output` 부분 매치)·파일 내용(grep)·tmux state 파일(grep)을 읽는다. mock patch target·logger 바인딩·f-string 류 Python 사각지대 해당 없음(Bash·텍스트 단언).
  - 전수형 SC(PROC-003): SC-013(i18n 패리티)은 전수형이나 `scripts/check-i18n-keys.sh` 가 en/ko 전체 키 집합을 comm 비교하므로 신규 키를 양쪽에 동시 추가하면 자동 검증. FR 열거 누락 위험은 "USAGE_<16개 서브커맨드> 전체 추가"(plan.md:200)로 차단.
  - caplog propagate(PROC-004): 해당 없음(Python 전용).
- **신규 코드 정적 검증**: `bash -n`(commands.sh — process substitution 때문에 `--posix` 불가, static.bats:99 패턴) + `bash --norc --noprofile --posix -n`(channels.sh/messages/completions, static.bats:91) + `shellcheck -S warning`. SC-023(Bash 3.2)은 `declare -A`·Bash4+ 문법 grep 0건으로 검증.

> 동적 호출(eval/getattr) 한계: 셸의 `eval` 은 output.sh:36 의 `t()` 키 확장에만 사용(메시지 키). 신규 키는 정적이라 동적 식별 누락 없음. CI 전체 suite 가 사후 안전망.

---

## doctrine·제약 대조 (pipeline-quality §7.1)

| 대조 대상 | 결과 |
|---|---|
| constitution.md P-001 (macOS·Bash 3.2) | 신규 코드 전부 스칼라·case·awk. 연관 배열·Bash4+ 0건. `${!var}`·`kill -0`·`<<<` here-string·`< <()` process substitution 은 기존 코드가 이미 사용(Bash 3.2 동작). 준수. |
| P-002 (전역 봇 비침해) | up_reserved/status 는 `.env` **읽기**만, down_reserved 는 tmux kill 만. `.env`/`access.json` write·삭제 0. snapshot/watcher 미호출(ADR-008). 준수. |
| P-003 (시크릿 비노출) | token 분기 argv 토큰 금지 — 대화형 마스킹/`--token-env`/`--token-stdin`(cmd_add 블록 재사용). `.env` 600. 준수. |
| P-004 (git/gh 사용자 확인) | 설계 단계 산출물은 문서뿐. 코드 커밋은 후속 단계 사용자 확인. 해당 없음. |
| P-005 (최소 표면·하위호환) | 신규 top-level 명령 0(config 서브액션 확장 + 기존 서브커맨드 --help + 예약어로 기존 동사 허용). 레지스트리 스키마 불변. 준수. |
| constitution §3 (품질·측정 선언) | SLA·측정 NFR 없음 선언 → 성능 수치화 면제. 검증 게이트=테스트 추가+CI green. 본 spec 모든 SC bats/static 자동 검증. 정합. |
| ADR-003 (완성 파일 lib 미source 리터럴 미러) | 신규 mode 6종·config 액션은 완성 파일에 **리터럴**로 추가(VALID_MODES env.sh:13 미러). NFR-006 준수. |
| 런타임/패키징 제약 | 셸 스크립트, 빌드 없음. install.sh copy/dev 모드 영향 없음(신규 파일 0, 기존 파일 편집만). |

---

## context.md 부정합 사전 점검 (PATCH-A11)

변경 대상 클래스·필드·Enum 을 context.md §2 핵심 모듈 표 / §5 도메인 용어 사전에서 grep 추출하여 본 spec 변경 후에도 정의가 유효한지 평가.

| context.md 항목 | 현재 정의 | 본 spec 변경 후 | 부정합? |
|---|---|---|---|
| §5 registry | `projects.conf`(`name\|cwd\|state_dir\|channel`; 3컬럼 레거시=telegram) | cwd(2번 컬럼) **값**만 갱신(FR-001). 스키마·컬럼 수 불변 | 없음 |
| §5 state dir | `~/.claude/channels/<name>/` | token 분기가 `.env` 재작성(FR-002), 예약어 up 이 전역 state dir 읽기. 정의 불변 | 없음 |
| §5 channel descriptor | `channel_spec` 8필드 | token_key·plugin·statedir_env 조회만(읽기). descriptor 불변 | 없음 |
| §5 launch.env | 봇별 기동 옵션 | cwd 변경은 레지스트리(launch.env 아님). 정의 불변 | 없음 |
| §5 reserved name | telegram/discord/imessage/fakechat — 봇 이름 거부 | **add/rm/rename 거부는 유지**(FR-011), up/down/restart/status/logs 런타임은 신규 허용. "봇 이름으로 거부"는 정확(add 대상). 단 "런타임 동사는 허용" 은 §6 신규 항목 후보 | 경미 — §6 기술부채/제약에 "예약어 런타임 지원" 항목 추가 권고(Docs 6단계) |
| §6 완성 채널 미러 수동 동기화 | completions 3곳 수동 갱신 | 동일 패턴 확장(mode/액션/--help 미러). 정의 강화(여전히 수동) | 없음(오히려 정합) |
| §2 자동완성 모듈 | bash/zsh 명령·플래그·봇이름 완성 | 역할 불변(후보 추가) | 없음 |

> **context.md 갱신 예상 항목(6단계 Docs Agent 위임)**: §5 reserved name 정의에 "add/rm/rename 은 거부하나 up/down/restart/status/logs 런타임 동사는 전역 봇 제어로 허용(v0.5.0/001)" 명확화, §6 또는 §3.3 상태흐름에 "예약어 런타임 라이프사이클(전역 봇 cwd=$PWD)" 추가. **부정합이 아니라 신규 기능 반영**이므로 BLOCKED 사유 아님 — gaps.md GAP 미등록, 본 절 가시화로 Docs Agent 검토 유도(PATCH-A10/A11 2중 절차).

---

## 배포 환경 영향 추정 (PATCH-A10)

- infra.md §1·§8(plan.md:65 cross-ref): 컨테이너/NAT/docker-proxy/L4 LB/reverse proxy/firewall **없음**. 사용자 로컬 macOS 단일 환경.
- 본 spec 은 로컬 CLI 변경(tmux 세션 제어·파일 편집)이며 네트워크 미들웨어·socket level 동작에 의존하지 않음. 점검 대상 환경 특이성(컨테이너 TCP 흡수·keepalive·conntrack) 모두 비해당.
- critical 배포 환경 영향 없음 → 다중 layer 안전망 설계 트리거 미충족. infra.md 갱신 불요(GAP 미등록).

---

## 기술 선택 조사 (plan ADR cross-check)

plan.md ADR-001~010 의 채택안을 코드 사실과 cross-check — 전부 정합 확인.

- **ADR-002(set_registry_cwd 신규 awk+mktemp+mv)**: `rename_registry_line`(registry.sh:27-44) 가 동일 패턴이며 2번 컬럼만 보존(c2)·1·3·4 갱신. set_registry_cwd 는 반대로 1·3·4 보존·2번만 newcwd 치환 — 동형 안전. `sed -i` 대안은 macOS BSD `sed -i ''` 비호환·비원자라 배제(정확).
- **ADR-005(--help 중앙 디스패치)**: cc-tg.sh:99 의 top-level `help|--help|-h|""` 는 CMD 가 빈/help 일 때만 매치. CMD 확정(shift 후, cc-tg.sh:81-82) → 남은 `$@` 에 `--help` 스캔하므로 `cctg add --help`(CMD=add) 와 무충돌. 16개 cmd_* 내부 수정보다 표면 작음(P-005) — 정확.
- **ADR-006(예약어 진입부 분기)**: up_one/down_one(session.sh:62/106) 이 `lookup` 으로 시작 → 예약어는 ERR_NOT_REGISTERED. 진입부 `is_reserved_name` 분기로 우회 정확. up_one 좌표 파라미터화(리팩토링) 대안도 가능하나 하위호환·가독성상 별도 함수 권고(plan.md:250) — 채택.
- **ADR-007(2중 가드)**: is_running(session.sh:6) OR reserved_runner_alive(kill -0). stale 허용 — 영구 락아웃 회피. SC-015/016 독립 검증.
- **ADR-009(완성 리터럴 미러)**: `_cctg:8`(`CCTG_COMPLETION_CHANNELS`)·`cctg.bash:12`(`channels=`) 가 이미 리터럴 미러. mode 6종도 `_cctg:69/78`·`cctg.bash:44/54` 에 리터럴 존재 → config mode 케이스도 동일 리터럴 재사용 정확.
- **ADR-010(imessage/fakechat 미지원)**: `channel_spec`(channels.sh:34) `*) return 1` — imessage/fakechat 케이스 미정의 → `channel_spec <ch> plugin` 실패. up_reserved/status 가드(`channel_spec ... || skip/거부`) 정확.

---

## 엣지 케이스 및 한계

- **config token name 미등록**: cmd_config 진입부 `lookup ... || die ERR_NOT_REGISTERED`(commands.sh:231) 가 token/cwd 분기 도달 전 거부 — 별도 처리 불요(plan.md:422).
- **SC-025 $PWD 부재 엣지**: 삭제된 디렉터리에서 `up telegram` 호출 시 up_reserved 의 `[ -d "$cwd" ] || die ERR_NO_CWD`(up_one:67 동형) 로 거부. SC-025 본체는 정상경로(cwd=$PWD 기동)이고, 부재 케이스는 Test 보조 Error 케이스로 보강(plan.md:389).
- **FR-008 restart 예약어**: 별도 SC 없음. down_reserved+up_reserved 조합(SC-018+SC-014/025)로 검증. Test 통합 시나리오로 보강(plan.md:391).
- **`up all` 예약어 제외**: cmd_up all(commands.sh:339-340) 은 `all_names()`(레지스트리)만 순회 → 예약어는 자연 제외(전역 봇은 명시 `up telegram` 만). 의도된 설계.
- **status BROKEN 판정(예약어)**: cwd 존재 여부 무관, **토큰 부재(no-token)만** 사유(plan.md:292). 이미 실행 중 세션은 다른 디렉터리에서 기동됐을 수 있어 cwd 가드는 status 차단 사유 아님 — up_reserved(C-1) 책임.
- **fake tmux 한계**: stub 은 new-session 의 작업 디렉터리(cwd)를 추적하지 않음(state 파일에 세션명만 기록, stub:37-38). **SC-025(cwd=$PWD 기동) 단위 검증 전략 주의** — fake tmux 로는 "세션 시작 디렉터리=$PWD" 를 직접 단언 불가. 대안: up_reserved 가 생성하는 **launch 문자열에 `cd $(printf '%q' "$PWD")`(=호출시 cwd) 가 포함**되는지를 검증(stub 이 받은 인자 캡처 또는 up_reserved 가 tmux 에 넘기는 launch 문자열 점검). tasks.md D 레이어·Test Authoring Contract 에 이 검증 방식을 명시.

> 인정되는 한계 및 안전망(PATCH-A07): 단독소유자 가드의 cctg↔플러그인 러너 TOCTOU·실제 DM 응답은 단위 mock 으로 완전 재현 불가 → PROC-014 사후 운영 검증으로 흡수(plan.md:403-412). 단위 게이트는 가드 분기(SC-015/016)·세션 생성(SC-014/025)을 fake tmux 로 검증.

---

## completeness critic (pipeline-quality §7.2)

확정 직전 "무엇이 빠졌나" 점검:

- **backlog/TODO 상호작용**: docs/TODO 와 충돌 없음(편의성 패치는 신규 표면 확장).
- **decisions.md 모순**: DEC-001(cwd=$PWD) — up_reserved/status_reserved 좌표 cwd=$PWD 전부 반영. 모순 없음.
- **미검증 가정(ASM)**: ASM-001(→DEC-001 resolved)·ASM-002(완성 미러 코드 확인)·ASM-003(--help 디스패치=ADR-005 확정)·ASM-004(kill -0 확인)·ASM-005(set_registry_cwd=ADR-002 확정). 전부 해소/확정.
- **doctrine 일관성**: constitution P-001~005 전 항목 준수(위 doctrine 대조 표).
- **의도적 컷(no-silent-caps)**: spec "범위 외"(channel/allowlist/groups 사후변경, imessage/fakechat 예약어, 전역봇 add/rm/rename, bot.pid 종료) — spec.md 명시. 신규 컷 발견 0건.

**발견된 누락**: 없음. 신규 GAP 0건. context.md 갱신은 부정합이 아닌 기능 반영(6단계 Docs 위임, 위 PATCH-A11 절 가시화).
