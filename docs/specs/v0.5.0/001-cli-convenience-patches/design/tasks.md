---
작성: Design Agent
버전: v1.0
최종 수정: 2026-06-17 22:39
상태: 확정
---

# Tasks: cli-convenience-patches

> Branch: feature/v0.5.0-001-cli-convenience-patches | Date: 2026-06-17 | Plan: [plan.md](../planning/plan.md) | Research: [research.md](research.md)

## 목차

- [전제 조건](#전제-조건)
- [레이어 정의](#레이어-정의)
- [태스크 목록](#태스크-목록)
- [Test Authoring Contract](#test-authoring-contract)
- [태스크 입도 가이드](#태스크-입도-가이드)
- [구현 완료 기준](#구현-완료-기준)

---

## 전제 조건

- [x] spec.md 의 모든 [NEEDS CLARIFICATION] 항목이 해소되었는가? — 0건(spec.md "미결 사항: 없음").
- [x] plan.md 의 Constitution Gates 가 모두 통과(또는 예외 기재) 되었는가? — P-001~005 + 기본 Gates 전부 [x], 예외 없음.
- [x] CHANGES.md 에서 이전 작업의 "후속 작업 시 주의사항" 을 확인했는가? — 버전 폴더 루트 CHANGES.md 부재(신규 v0.5.0). context.md §6 제약(완성 미러 수동 동기화·Bash 3.2) 확인.

---

## 레이어 정의

> 기본 의존 순서: A → B → C → D. 의존 없는 태스크는 [P] 로 병렬 가능.
> **4단계 Development = A·B·C 레이어**, **5a Test(AUTHORING) = D 레이어**. 양 Agent 는 PPG-1 으로 동일 turn 동시 spawn(병렬). 산출물 충돌 없음 — A·B·C 는 production(`lib/`·`cc-tg.sh`·`completions/`·`messages/`), D 는 테스트(`tests/*.bats`).

| 레이어 | 본 spec 대상 (프로젝트 아키텍처 = 셸 모듈 계층) |
|---|---|
| A. 데이터/레지스트리 계층 | `lib/registry.sh` 레지스트리 조작 함수 + `lib/session.sh` 예약어 헬퍼 + `messages/*` i18n 키 |
| B. 도메인/명령 계층 | `lib/commands.sh` cmd_config 확장(cwd/token) + `lib/util.sh` sub_usage + 예약어 명령 분기 |
| C. 인터페이스 계층 | `cc-tg.sh` --help 선검사 디스패치 + `completions/*` 미러 갱신 |
| D. 테스트 계층 | `tests/*.bats` 단위·정적 테스트 (SC-001~025 전수) |

> 레이어 재정의 근거: 본 프로젝트는 레이어드 DB/API 아키텍처가 아닌 셸 모듈 계층(env→channels→config→util→registry→session→commands→dispatcher, cc-tg.sh:60-74). 의존 방향은 dispatcher(C) → commands(B) → registry/session/config/channels(A). 따라서 A=하위 헬퍼(registry/session/messages), B=명령 로직(commands/util), C=진입점·완성(dispatcher/completions)으로 매핑.

---

## 태스크 목록

> [P] = 이전 태스크와 병렬 실행 가능. i18n 키는 A 레이어에서 일괄 추가하여 B·C 가 참조.

### Step 1. 기반 작업 (레이어 A)

- [x] **T001 — 신규 i18n 메시지 키 일괄 추가 (en/ko 패리티)**
    - 레이어: A
    - 구현 파일: `messages/en.sh`, `messages/ko.sh`
    - 관련 요구사항: NFR-007 / SC-013
    - 상세: 아래 신규 `CCTG_MSG_*` 키를 en.sh·ko.sh 양쪽에 동일 키로 추가(값만 언어별). 기존 키 미수정.
      - 그룹 A: `ERR_CONFIG_CWD_USAGE`(Usage: %s config %s cwd <path>), `ERR_NO_SUCH_DIR`(존재하지 않는 디렉터리: %s), `CFG_CWD_SET`(%s cwd: %s), `ERR_CONFIG_TOKEN_USAGE`(Usage: %s config %s token [--token-env VAR|--token-stdin]), `CFG_TOKEN_SET`(%s token updated).
      - 그룹 C: `RESERVED_UP`(UP %s (global bot, tmux=%s)), `ERR_RESERVED_UP_OCCUPIED`(이미 실행 중: %s), `ERR_RESERVED_UP_RUNNER`(전역 봇 플러그인 러너 실행 중(bot.pid): %s), `ERR_RESERVED_UNSUPPORTED`(예약어 런타임 미지원 채널: %s), `RESERVED_DOWN_NONE`(세션 없음: %s. cctg 가 띄운 tmux 세션만 종료 가능 — 플러그인 자체 러너(bot.pid)는 종료하지 않음 [NFR-003 한계]), `STATUS_RESERVED_HEADER`(선택 — --- global channel bots ---).
      - 그룹 B: `USAGE_ADD`/`USAGE_RM`/`USAGE_RENAME`/`USAGE_CONFIG`/`USAGE_COMMON`/`USAGE_UP`/`USAGE_DOWN`/`USAGE_RESTART`/`USAGE_STATUS`/`USAGE_LOGS`/`USAGE_ATTACH`/`USAGE_LANG`/`USAGE_DOCTOR`/`USAGE_UPDATE`/`USAGE_VERSION`/`USAGE_HELP` (16개 서브커맨드 사용법, `%s`=PROG).
    - 기존 재사용(추가 불요, 참조만): `ERR_EMPTY_TOKEN`·`ADD_PROMPT_TOKEN`·`ERR_ADD_FLAG_VALUE`·`ERR_ADD_BAD_ENVNAME`·`APPLY_RESTART`·`ERR_REGISTRY_UPDATE`·`ERR_NO_TOKEN`·`ERR_NO_CWD`·`DOWN_OK`·`STATUS_*`·`LOGS_*`·`ERR_NOT_REGISTERED`.
    - 완료 기준: `bash scripts/check-i18n-keys.sh` exit 0 (패리티·참조 키 정상). en/ko 키 집합 동일.

- [x] **T002 — `set_registry_cwd <name> <newcwd>` 레지스트리 cwd 갱신 함수 신설** [P]
    - 레이어: A
    - 구현 파일: `lib/registry.sh`
    - 관련 요구사항: FR-001 / NFR-005 / SC-001 / ADR-002
    - 상세: `rename_registry_line`(registry.sh:27-44) 동형 awk+mktemp+mv. 매치 행의 **2번 컬럼(cwd)만** newcwd 로 치환, 1·3·4 컬럼·주석·빈 줄 보존. 4번 컬럼 빈 경우 `$DEFAULT_CHANNEL` 보강(레거시 3컬럼 행 처리). plan.md:101-116 시그니처 사용.
    - 완료 기준: `bash -n lib/registry.sh` 통과. 함수 정의 존재. SC-001 테스트(T013)에서 2번 컬럼 갱신·1·3·4 보존 확인.

- [x] **T003 — `up_reserved`/`reserved_runner_alive` 예약어 기동 헬퍼 신설** [P]
    - 레이어: A
    - 구현 파일: `lib/session.sh`
    - 관련 요구사항: FR-006 / NFR-002 / DEC-001 / SC-014/025/015/016/017 / ADR-006/007/010
    - 상세: plan.md C-1(plan.md:227-247) 사양.
      - `up_reserved <ch>`: `channel_spec "$ch" plugin >/dev/null 2>&1 || { te ERR_RESERVED_UNSUPPORTED "$ch"; return 1; }`(imessage/fakechat 거부). `sd="$CHANNELS_DIR/$ch"; cwd="$PWD"`(DEC-001). `[ -d "$cwd" ] || { te ERR_NO_CWD "$cwd"; return 1; }`(SC-025 부재 가드, up_one:67 동형). `[ -f "$sd/.env" ] || { te ERR_NO_TOKEN "$sd/.env"; return 1; }`(SC-017). 단독소유자 2중 가드: `is_running "$ch"` → `ERR_RESERVED_UP_OCCUPIED`(SC-015), `reserved_runner_alive "$sd"` → `ERR_RESERVED_UP_RUNNER`(SC-016). 기동: up_one(session.sh:81-95)과 동형 launch(단 `cwd=$PWD`, `cd $(printf '%q' "$cwd")`, ch 고정, statedir_env/plugin descriptor 경유, shared_arg 동일, launch.env 부재 허용 `[ -f ... ] && source || true`). `tmux new-session -d -s "$(sess_of "$ch")" "bash -lc $(printf '%q' "$launch")"`. 성공: `t RESERVED_UP "$ch" "$(sess_of "$ch")"`.
      - `reserved_runner_alive <sd>`: `pidf="$1/bot.pid"`; `[ -f "$pidf" ] || return 1`; `pid="$(head -n1 "$pidf" 2>/dev/null)"`; `[ -n "$pid" ] && kill -0 "$pid" 2>/dev/null`(stale=false=기동허용).
    - 완료 기준: `bash -n lib/session.sh` 통과. up_one 미수정. SC-014/025/015/016/017 테스트에서 각 분기 검증.

- [x] **T004 — `down_reserved` 예약어 정지 헬퍼 신설** [P]
    - 레이어: A
    - 구현 파일: `lib/session.sh`
    - 관련 요구사항: FR-007 / NFR-002 / NFR-003 / SC-018 / SC-019 / SC-024 / ADR-008
    - 상세: plan.md C-2(plan.md:258-266). `down_reserved <ch>`: `is_running "$ch"` 면 `tmux kill-session -t "$(sess_of "$ch")"` + `t DOWN_OK "$ch"`(SC-018); 아니면 `t RESERVED_DOWN_NONE "$ch"`(SC-019 — bot.pid 한계 명시). **stop_snapshotter/take_snapshot 호출 금지**(전역 봇 watcher 없음, ADR-008). `.env`/`access.json` 미접근(SC-024 P-002).
    - 완료 기준: `bash -n lib/session.sh` 통과. SC-018/019/024 테스트 검증. down_one 미수정.

### Step 2. 핵심 구현 (레이어 B — A 의존)

- [x] **T005 — `cmd_config` 에 `cwd)` 액션 분기 추가**
    - 레이어: B (T002·T001 의존)
    - 구현 파일: `lib/commands.sh`
    - 관련 요구사항: FR-001 / SC-001/002/003 / ADR-001
    - 상세: plan.md A-1(plan.md:88-95). `cmd_config` `case "$ACTION"`(commands.sh:251)에 `cwd)` arm 추가. cwd 는 진입부에서 `cut -f1 <<<"$row"` 로 확보(현 232행은 sd=cut -f2 만). `NEWCWD="${3-}"`; 빈값→`die ERR_CONFIG_CWD_USAGE "$PROG" "$NAME"`; `[ -d "$NEWCWD" ] || die ERR_NO_SUCH_DIR "$NEWCWD"`(SC-002); `set_registry_cwd "$NAME" "$NEWCWD" || die ERR_REGISTRY_UPDATE`(SC-001); `t CFG_CWD_SET "$NAME" "$NEWCWD"`; `is_running "$NAME" && t APPLY_RESTART "$PROG" "$NAME"`(SC-003). 기존 arm·`*)` fallthrough 불변.
    - 완료 기준: `bash -n lib/commands.sh` 통과. SC-001/002/003 테스트 PASS. 기존 config.bats 회귀 PASS.

- [x] **T006 — `cmd_config` 에 `token)` 액션 분기 추가**
    - 레이어: B (T001 의존)
    - 구현 파일: `lib/commands.sh`
    - 관련 요구사항: FR-002 / NFR-004 / P-003 / SC-004/005/006 / ADR-003/004
    - 상세: plan.md A-2(plan.md:126-148). `token)` arm 추가. `shift 2`(name·action 소비) 후 `--token-env <VAR>`/`--token-stdin` 파싱(argv 토큰 금지 — 그 외 `die ERR_CONFIG_TOKEN_USAGE "$PROG" "$NAME"`). 입력: stdin(`IFS= read -r NEWTOK`)/env(`${!t_env-}`, envname 검증 `grep -qE '^[A-Za-z_][A-Za-z0-9_]*$' || die ERR_ADD_BAD_ENVNAME`)/대화형(`t ADD_PROMPT_TOKEN; read -rs NEWTOK; echo`). `[ -z "$NEWTOK" ] && die ERR_EMPTY_TOKEN`(SC-005). 토큰 키: `tk="$(channel_spec "$(channel_of "$NAME")" token_key)"`(SC-006 discord=DISCORD_BOT_TOKEN). `.env` 재작성: **`printf '%s=%s\n' "$tk" "$NEWTOK" > "$sd/.env" && chmod 600 "$sd/.env"`**(SC-004 — cmd_add commands.sh:69 와 동일 무따옴표 형식, research.md "token 분기 .env 형식 주의" 참조 — set_env_kv 금지). `t CFG_TOKEN_SET "$NAME"`; `is_running "$NAME" && t APPLY_RESTART`. `--token-env` 값 누락 시 `die ERR_ADD_FLAG_VALUE "--token-env"`.
    - 완료 기준: `bash -n lib/commands.sh` 통과. SC-004(.env=TELEGRAM_BOT_TOKEN, 600)·SC-005(빈토큰 거부, .env 불변)·SC-006(discord 키) PASS.

- [x] **T007 — `sub_usage <subcmd>` 함수 신설 (16개 서브커맨드 USAGE 라우팅)**
    - 레이어: B (T001 의존)
    - 구현 파일: `lib/util.sh`
    - 관련 요구사항: FR-005 / SC-010/011 / ADR-005
    - 상세: plan.md B-3(plan.md:187-195). `sub_usage() { case "$1" in add) t USAGE_ADD "$PROG";; rm) t USAGE_RM "$PROG";; ... (16개 전부) *) usage;; esac; }`. 각 arm 은 T001 의 `USAGE_<SUBCMD>` 키 호출. `version`/`help` 의 --help 도 USAGE_VERSION/USAGE_HELP 출력(또는 자기 출력 갈음 — Design 권고: 16개 키 전부 정의했으므로 일관되게 t USAGE_* 사용).
    - 완료 기준: `bash -n lib/util.sh` 통과. 함수 정의 존재. SC-010(add)·SC-011(config) 테스트에서 USAGE 출력·exit 0 확인.

- [x] **T008 — 예약어 명령 진입부 분기 (`cmd_up/down/restart/status/logs`)**
    - 레이어: B (T003·T004 의존)
    - 구현 파일: `lib/commands.sh`
    - 관련 요구사항: FR-006/007/008/009/010 / SC-014~021/024/025 / ADR-006
    - 상세: plan.md C-1/C-2/C-3/C-4/C-5.
      - `cmd_up`(commands.sh:337): `TARGET` 확정 후 `is_reserved_name "$TARGET" && { up_reserved "$TARGET"; return; }`. 기존 all/단일 경로 뒤로(plan.md:218-222).
      - `cmd_down`(commands.sh:346): `is_reserved_name "$TARGET" && { down_reserved "$TARGET"; return; }`.
      - `cmd_restart`(commands.sh:355): `is_reserved_name "$TARGET" && { down_reserved "$TARGET"; up_reserved "$TARGET"; return; }`(FR-008, FR-007→FR-006 순서).
      - `cmd_status`(commands.sh:364): 프로젝트 봇 순회(commands.sh:371-411) 전/후에 예약어 섹션 추가 — `for ch in $RESERVED_NAMES; do channel_spec "$ch" plugin >/dev/null 2>&1 || continue; sd="$CHANNELS_DIR/$ch"; [ -d "$sd" ] || continue; cwd="$PWD"(DEC-001); issues; [ -f "$sd/.env" ] || issues=no-token; is_running→STATUS_RUNNING / issues→STATUS_BROKEN / else→STATUS_STOPPED; STATUS_PATHS "$cwd" "$sd"; STATUS_CHANNEL; done`(plan.md:281-291). BROKEN 판정은 토큰 부재만(cwd 무관, plan.md:292). 선택: STATUS_RESERVED_HEADER 헤더.
      - `cmd_logs`(commands.sh:451): 진입부 `is_reserved_name "$NAME" && { is_running→capture-pane|tail / last-session.log 스냅샷 / die LOGS_STOPPED; return; }`(plan.md:298-303).
      - 비예약어 인자는 기존 경로 100% 보존(early return 후 분기). `up all` 등 `all` 은 예약어 아님 → 기존 분기.
    - 완료 기준: `bash -n lib/commands.sh` 통과. SC-014/025/015/016/017/018/019/020/021/024 PASS. 기존 up_down.bats·status_view.bats 회귀 PASS(비예약어 mybot 경로 불변).

### Step 3. 인터페이스 (레이어 C — B 의존)

- [x] **T009 — `cc-tg.sh` `--help`/`-h` 선검사 디스패치 추가**
    - 레이어: C (T007 의존)
    - 구현 파일: `cc-tg.sh`
    - 관련 요구사항: FR-005 / SC-010/011 / ADR-005
    - 상세: plan.md B-3(plan.md:176-181). `case "$CMD"`(cc-tg.sh:83) 직전, CMD 확정(cc-tg.sh:81-82 shift) 후: `case "$CMD" in add|rm|rename|config|common|up|down|restart|status|logs|attach|lang|doctor|update|version|help) for a in "$@"; do case "$a" in --help|-h) sub_usage "$CMD"; exit 0;; esac; done;; esac`. 기존 top-level `help|--help|-h|""`(cc-tg.sh:99)와 무충돌(CMD=add 면 add case 매치).
    - 완료 기준: `bash -n cc-tg.sh` 통과. `cctg add --help`=USAGE_ADD exit 0(SC-010), `cctg config --help`=USAGE_CONFIG exit 0(SC-011), `cctg --help`(CMD="")=top-level usage(기존 동작 보존).

- [x] **T010 — `completions/_cctg` (zsh) 미러 갱신**
    - 레이어: C (T001 참조값 동기)
    - 구현 파일: `completions/_cctg`
    - 관련 요구사항: FR-003/004/005 / SC-007/009/012 / NFR-006 / ADR-009
    - 상세: plan.md B-1/B-2(plan.md:162-168, 198).
      - config 액션(`_cctg:60`): `compadd -- show edit mode args snapshot cwd token`(SC-009 — cwd·token 추가).
      - mode 값(SC-007): config 케이스에 `CURRENT == 5` 이고 `${words[4]} == mode` 일 때 `compadd -- acceptEdits auto bypassPermissions default dontAsk plan`(또는 `_describe`/`_values` 로 hint 포함). VALID_MODES env.sh:13 리터럴 미러(lib source 금지, NFR-006). 주석에 "env.sh VALID_MODES 미러" 명시.
      - 서브커맨드 `--help`(SC-012): 각 서브커맨드 플래그 후보에 `--help` 추가(예 add 케이스 `*) compadd -- ... --help`, config·up·down 등 플래그 위치).
    - 완료 기준: `bash --norc --noprofile --posix -n` 통과(또는 zsh 문법은 grep 검증). SC-007/009/012 정적 테스트(grep)에서 6모드·cwd token·--help 존재 확인.

- [x] **T011 — `completions/cctg.bash` (bash) 미러 갱신**
    - 레이어: C (T010 와 [P], T001 참조값 동기)
    - 구현 파일: `completions/cctg.bash`
    - 관련 요구사항: FR-003/004/005 / SC-008/009/012 / NFR-006 / ADR-009
    - 상세: plan.md B-1/B-2(plan.md:163, 168, 198).
      - config 액션(`cctg.bash:30`): `compgen -W "show edit mode args snapshot cwd token"`(SC-009).
      - mode 값(SC-008): config 케이스에 `[ "$COMP_CWORD" -eq 4 ]` 이고 `${COMP_WORDS[3]} == mode` 일 때 `compgen -W "acceptEdits auto bypassPermissions default dontAsk plan"`. 리터럴 미러(NFR-006). 주석 명시.
      - 서브커맨드 `--help`(SC-012): 각 서브커맨드 플래그 후보에 `--help` 추가(add `*) compgen -W "... --help"` 등).
    - 완료 기준: `bash --norc --noprofile --posix -n completions/cctg.bash` 통과. SC-008/009/012 정적 테스트에서 6모드·cwd token·--help 존재 확인.

### Step 4. 테스트 (레이어 D — 5a Test Agent AUTHORING 담당)

> 본 Step(레이어 D)은 **5a 단계 Test Agent (AUTHORING)** 가 PPG-1 시작 시 수행한다. 4단계 Development Agent 는 A·B·C(T001~T011)만 진행한다. 양 Agent 는 동일 turn 동시 spawn 병렬. 아래 태스크는 [Test Authoring Contract](#test-authoring-contract) 의 SC 별 파일·시나리오를 구현한다.

- [ ] **T012 — 그룹 A 사후변경 테스트 (config cwd/token)** — SC-001/002/003/004/005/006
    - 레이어: D
    - 테스트 파일: `tests/config.bats` 확장(기존 파일에 추가)
    - 검증 대상: SC-001(cwd 갱신)·SC-002(부재경로 거부)·SC-003(running restart 안내)·SC-004(token .env telegram 키 600)·SC-005(빈 토큰 거부)·SC-006(discord 키)
- [ ] **T013 — 그룹 C 예약어 런타임 테스트 (up/down/restart/status/logs)** — SC-014/025/015/016/017/018/019/020/021/024
    - 레이어: D
    - 테스트 파일: `tests/reserved.bats`(신규)
    - 검증 대상: SC-014(up 세션기동)·SC-025(cwd=$PWD)·SC-015(세션 점유 거부)·SC-016(bot.pid 거부)·SC-017(.env 부재)·SC-018(down 종료)·SC-019(세션없음 한계)·SC-020(status 예약어 표시)·SC-021(logs)·SC-024(down .env/access.json 불변)
- [ ] **T014 — 그룹 B --help 테스트** — SC-010/011
    - 레이어: D
    - 테스트 파일: `tests/help.bats`(신규) 또는 `tests/misc.bats` 확장
    - 검증 대상: SC-010(add --help USAGE 출력 exit 0)·SC-011(config --help)
- [ ] **T015 — 정적 검증 테스트 (완성·i18n·Bash 3.2·예약어 차단)** — SC-007/008/009/012/013/022/023
    - 레이어: D
    - 테스트 파일: `tests/static.bats` 확장 + `tests/config.bats`/`tests/add.bats`(SC-022 차단)
    - 관련 요구사항: FR-003/004/005 / NFR-007 / FR-011(SC-022) / NFR-001(SC-023)
    - 검증 대상: SC-007(zsh mode 6종)·SC-008(bash mode 6종)·SC-009(config 액션 cwd token)·SC-012(--help 후보)·SC-013(check-i18n-keys exit 0)·SC-022(예약어 add/rm/rename ERR_RESERVED, FR-011)·SC-023(Bash 3.2 구문)

---

## Test Authoring Contract

> **PPG-1 의 5a 단계 Test Agent (AUTHORING) 입력 contract**. 각 SC 별 테스트 파일·함수명 후보 + 시나리오 유형. main 이 `ExternalAuthoring: YES` 시 외부 충족 산출물 존재를 확인 후 5b 진입.

| SC-ID | 수용 기준 | 유형 | 테스트 함수명 후보 (bats @test 설명) | 테스트 파일 | 비고 |
|---|---|---|---|---|---|
| SC-001 | config cwd → 레지스트리 2컬럼 갱신 | Happy | "config cwd: updates registry column 2 (SC-001)" | tests/config.bats | seed_bot mybot; mkdir new; `cctg config mybot cwd $new`; registry grep `mybot \| $new`. [env:unit] |
| SC-002 | 부재 경로 거부 | Error | "config cwd: rejects non-existent dir (SC-002)" | tests/config.bats | `cctg config mybot cwd /nope`; status≠0; 출력 no such dir; registry 불변. [env:unit] |
| SC-003 | running 시 restart 안내 | Edge | "config cwd: hints restart when running (SC-003)" | tests/config.bats | mark_running mybot; `cctg config mybot cwd $new`; 출력 "to apply". [env:unit] |
| SC-004 | token → .env telegram 키 600 | Happy | "config token: rewrites .env with telegram key, mode 600 (SC-004)" | tests/config.bats | seed_bot mybot(telegram); `printf newtok \| cctg config mybot token --token-stdin`; `.env` grep `TELEGRAM_BOT_TOKEN=newtok`; file_mode=600. [env:unit] |
| SC-005 | 빈 토큰 거부 | Error | "config token: rejects empty token (SC-005)" | tests/config.bats | `printf '' \| cctg config mybot token --token-stdin`; status≠0; 출력 empty; .env 불변(기존 tok 유지). [env:unit] |
| SC-006 | discord token → DISCORD 키 | Happy | "config token: uses DISCORD_BOT_TOKEN for discord (SC-006)" | tests/config.bats | seed_bot dbot --channel discord; `printf newtok \| cctg config dbot token --token-stdin`; `.env` grep `DISCORD_BOT_TOKEN=newtok`, 600. [env:unit] |
| SC-007 | zsh mode 완성 6종 | Happy(static) | "completions/_cctg: config mode offers 6 modes (SC-007)" | tests/static.bats | grep _cctg: mode 값 케이스에 6 모드 리터럴 + cwd/token 액션. [env:static] |
| SC-008 | bash mode 완성 6종 | Happy(static) | "completions/cctg.bash: config mode offers 6 modes (SC-008)" | tests/static.bats | grep cctg.bash: compgen 6모드 + config COMP_CWORD==4 mode 케이스. [env:static] |
| SC-009 | config 액션에 cwd·token | Happy(static) | "completions: config actions include cwd and token (SC-009)" | tests/static.bats | _cctg·cctg.bash 양쪽 config 액션 리터럴에 cwd·token. [env:static] |
| SC-010 | add --help 사용법 | Happy | "add --help: prints usage, exit 0 (SC-010)" | tests/help.bats | `cctg add --help`; status 0; 출력에 add usage 토큰(예 "<name>"/"--id"). [env:unit] |
| SC-011 | config --help 사용법 | Happy | "config --help: prints usage, exit 0 (SC-011)" | tests/help.bats | `cctg config --help`; status 0; 출력에 config usage 토큰. [env:unit] |
| SC-012 | 완성에 --help 포함 | Happy(static) | "completions: subcommand flags include --help (SC-012)" | tests/static.bats | _cctg·cctg.bash 에 `--help` 후보 grep. [env:static] |
| SC-013 | en/ko 키 패리티 | Edge | "i18n: en/ko key parity (SC-013)" | tests/static.bats | `run bash scripts/check-i18n-keys.sh`; status 0. [env:unit] |
| SC-014 | up telegram 세션 기동 | Happy | "up telegram: starts cctg-telegram session (SC-014)" | tests/reserved.bats | mkdir+`.env`(TELEGRAM_BOT_TOKEN) in $CC_CHANNELS_DIR/telegram; no session/pid; `cctg up telegram`; status 0; grep cctg-telegram in FAKE_TMUX_STATE. [env:unit] |
| SC-025 | up cwd=$PWD 기동 | Happy | "up telegram: session launch uses \$PWD as cwd (SC-025)" | tests/reserved.bats | .env 존재; `cd $somedir; cctg up telegram`. **검증 방식(research 엣지)**: fake tmux 가 cwd 미추적 → up_reserved 가 tmux 에 넘기는 launch 문자열에 `cd <$PWD quoted>` 포함을 확인. stub 인자 캡처(예 FAKE_TMUX_LASTCMD 파일) 또는 launch 문자열 직접 점검. [env:unit] |
| SC-015 | 세션 점유 거부 | Error | "up telegram: refuses when session exists (SC-015)" | tests/reserved.bats | mark_running telegram; .env 존재; `cctg up telegram`; status≠0; 출력 occupied; 신규 세션 없음. [env:unit] |
| SC-016 | bot.pid 생존 거부 | Error | "up telegram: refuses when bot.pid alive (SC-016)" | tests/reserved.bats | `echo $$ > telegram/bot.pid`(살아있는 PID=현재 셸); .env 존재; `cctg up telegram`; status≠0; 출력 runner. [env:unit] |
| SC-017 | .env 부재 거부 | Error | "up telegram: refuses when .env missing (SC-017)" | tests/reserved.bats | mkdir telegram(no .env); `cctg up telegram`; status≠0; 출력 token. [env:unit] |
| SC-018 | down telegram 세션 종료 | Happy | "down telegram: kills cctg-telegram session (SC-018)" | tests/reserved.bats | mark_running telegram; `cctg down telegram`; status 0; 출력 DOWN; FAKE_TMUX_STATE 에 cctg-telegram 없음. [env:unit] |
| SC-019 | 세션 없음 한계 안내 | Edge | "down telegram: reports none + bot.pid limit note (SC-019)" | tests/reserved.bats | no session; `cctg down telegram`; status 0; 출력 RESERVED_DOWN_NONE(세션없음 + bot.pid 한계). [env:unit] |
| SC-020 | status 예약어 표시 | Happy | "status: includes reserved bot state (SC-020)" | tests/reserved.bats | mkdir telegram (no session); `cctg status`; 출력에 telegram + [stopped] 또는 [BROKEN]. [env:unit] |
| SC-021 | logs telegram 출력 | Happy | "logs telegram: prints capture-pane (SC-021)" | tests/reserved.bats | mark_running telegram; `cctg logs telegram`; 출력에 fake pane line(stub capture-pane). [env:unit] |
| SC-022 | 예약어 add/rm/rename 차단 | Error | "reserved: add telegram still rejected (SC-022)" | tests/add.bats(또는 config.bats) | `cctg add telegram /some/path`; status≠0; 출력 reserved. [env:unit] |
| SC-023 | Bash 3.2 구문 | Edge(static) | "syntax: no associative arrays / Bash4+ in new code (SC-023)" | tests/static.bats | grep `declare -A` 0건 in lib/*.sh·cc-tg.sh; `bash -n`(commands.sh)·`--posix -n`(나머지) 통과. [env:static] |
| SC-024 | down 이 .env/access.json 불변 | Edge | "down telegram: leaves .env/access.json untouched (SC-024)" | tests/reserved.bats | telegram/.env + access.json 작성; mtime/내용 기록; `cctg down telegram`; mtime·내용 불변. [env:unit] |

> **테스트 헬퍼 확장 권고(Test Agent 결정)**: (1) 예약어 봇은 레지스트리에 없으므로 `seed_bot` 미사용 — `mkdir -p $CC_CHANNELS_DIR/telegram` + `printf 'TELEGRAM_BOT_TOKEN=tok\n' > .env` 직접 시드. (2) SC-025 의 launch cwd 검증을 위해 fake tmux stub(`tests/stubs/tmux`)에 new-session 의 마지막 인자(bash -lc 문자열)를 파일로 기록하는 캡처 추가 또는 up_reserved launch 문자열을 함수 단위로 점검. (3) SC-016 살아있는 PID 는 `$$`(현재 bats 셸) 사용 — 확실히 alive. stub·헬퍼 변경 시 기존 81개 스위트 회귀 영향 0 확인.

---

## 태스크 입도 가이드

- 1 태스크 ≈ 구현 파일 1~3개 + 대응 테스트. 본 spec 은 파일별 분리(T001 i18n, T002 registry, T003/004 session, T005~008 commands, T009 cc-tg, T010/011 completions)로 산출물 충돌 회피.
- T008(cmd_up/down/restart/status/logs 5함수 진입부)은 단일 파일·단일 패턴(is_reserved_name 분기) 반복이라 1 태스크 유지. 호출측 영향은 진입부 early branch 라 비예약어 경로 불변(분할 불요).
- D 레이어는 SC 그룹별 4 태스크(T012~T015)로 분할 — 5a Test Agent 가 파일별 병렬 작성 가능.

---

## 구현 완료 기준

- [ ] 모든 태스크(T001~T015) 체크박스 완료.
- [ ] `bats tests/` 전체 PASSED (기존 81개 + 신규 SC-001~025 대응).
- [ ] `bash scripts/check-i18n-keys.sh` exit 0 (en/ko 패리티·참조 키).
- [ ] `shellcheck -S warning` 변경 파일 통과(기존 disable 주석 정합 유지).
- [ ] `bash -n`(commands.sh) + `bash --norc --noprofile --posix -n`(channels/messages/completions/registry/session/util/config/cc-tg) 통과.
- [ ] `git status` 의도치 않은 파일 없음(변경 대상: lib/registry.sh·lib/session.sh·lib/commands.sh·lib/util.sh·cc-tg.sh·completions/_cctg·completions/cctg.bash·messages/en.sh·messages/ko.sh + tests/).
- [ ] spec.md 범위 외 변경 0건(전역봇 add/rm/rename·channel/allowlist 사후변경·imessage/fakechat 예약어·bot.pid 종료 미구현 유지).
