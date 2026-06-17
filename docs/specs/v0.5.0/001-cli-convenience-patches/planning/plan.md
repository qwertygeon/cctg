---
작성: Planning Agent
버전: v1.1
최종 수정: 2026-06-17 22:14
상태: 확정
---

# Plan: cli-convenience-patches

> Branch: feature/v0.5.0-001-cli-convenience-patches | Date: 2026-06-17 | Spec: [spec.md](../spec/spec.md)

## 목차

- [사전 검증 (Constitution Gates)](#사전-검증-constitution-gates)
- [기술 컨텍스트](#기술-컨텍스트)
- [핵심 설계](#핵심-설계)
  - [그룹 A: 사후 변경 커맨드 (config cwd/token)](#그룹-a-사후-변경-커맨드-config-cwdtoken)
  - [그룹 B: 자동완성 보강 + 서브커맨드 --help](#그룹-b-자동완성-보강--서브커맨드---help)
  - [그룹 C: 예약어 런타임 지원](#그룹-c-예약어-런타임-지원)
- [결정 기록 (ADRs)](#결정-기록-adrs)
- [인터페이스 계약](#인터페이스-계약)
- [데이터 모델](#데이터-모델)
- [테스트 전략](#테스트-전략)
- [기타 고려사항](#기타-고려사항)

---

## 사전 검증 (Constitution Gates)

> constitution.md(P-001~P-005) 가 존재하므로 해당 조항을 우선 적용한다. spec.md NFR 은 constitution 의 인스턴스이며 완화하지 않는다.

- [x] **P-001 (macOS · Bash 3.2 호환)**: [Pass 기준: 신규 코드에 연관 배열(`declare -A`)·Bash 4+ 전용 문법 0건. case/스칼라/awk 기반.] — 그룹 A/B/C 모두 기존 스칼라·case 패턴 준용. SC-023(static) 으로 검증.
- [x] **P-002 (전역 봇 비침해)**: [Pass 기준: 전역 채널 디렉터리 `~/.claude/channels/<reserved>/` 의 `.env`·`access.json` 을 신규 코드가 write/삭제하지 않음.] — 그룹 C `up/down/status/logs` 는 읽기·tmux 세션 제어만. `down` 은 cctg 가 만든 `cctg-<ch>` tmux 세션만 kill(NFR-003). SC-024(unit) 로 `.env`·`access.json` mtime 불변 검증.
- [x] **P-003 (시크릿 비노출)**: [Pass 기준: `config <name> token` 이 토큰을 argv 로 받지 않음 — 대화형 마스킹 / `--token-env <VAR>` / `--token-stdin` 만. .env 600 저장.] — `cmd_add` 의 토큰 입력 블록(commands.sh:42-51) 재사용. SC-004/SC-005/SC-006 검증.
- [x] **P-004 (git/gh 변경 사용자 확인)**: [Pass 기준: 본 단계 산출물은 문서뿐. 코드 구현·커밋은 후속 단계 사용자 확인.] — 해당 없음(설계 단계).
- [x] **P-005 (최소 명령 표면 · 하위호환)**: [Pass 기준: 신규 표면은 기존 `config <name>` 서브액션 확장(cwd/token) + 기존 서브커맨드의 `--help` 플래그 + 예약어로의 기존 동사(up/down/restart/status/logs) 허용. 신규 top-level 명령 0건. 레지스트리 스키마 불변(컬럼 추가 없음).] — Q-A2 채택안(config 액션 확장). 레지스트리 컬럼 `name|cwd|state_dir|channel` 그대로, cwd 변경은 기존 2번 컬럼 값만 갱신.

### 기본 Gates (constitution 위에 추가 적용)

- [x] **성능 원칙**: [Pass 기준: SLA·측정 NFR 없음 — constitution §3 에서 명시 선언(no-silent-caps). 성능 수치화 면제.] — 로컬 CLI, 성능 게이트 없음.
- [x] **호환성 원칙**: [Pass 기준: 영향 인터페이스 = `config` 디스패처(commands.sh:251 case), `cc-tg.sh` 디스패처(83-106), `completions/*`, `messages/*`. 기존 액션(show/edit/mode/args/snapshot)·기존 봇 워크플로 불변.] — 신규 액션은 case 추가, 기존 분기 미수정.
- [x] **테스트 원칙**: [Pass 기준: SC 없는 FR 0건.] — FR-001~011 전부 SC 매핑(FR-008 은 SC-014+SC-018 조합 — 매트릭스 명시).
- [x] **스펙 범위 원칙**: [Pass 기준: spec.md 범위 외 변경 파일 0건. 변경 대상은 lib/commands.sh·lib/session.sh·completions/_cctg·completions/cctg.bash·messages/en.sh·messages/ko.sh·cc-tg.sh 로 한정.] — "범위 외" 절(channel/allowlist/groups 사후변경, imessage/fakechat 예약어, 전역봇 add/rm/rename, bot.pid 종료) 미구현 유지.

예외 사항: 없음. 모든 Gate 통과.

---

## 기술 컨텍스트

- **언어 / 런타임**: Bash 3.2 (macOS 기본). 단일 진입점 `cc-tg.sh` + 런타임 source 되는 `lib/*.sh` 모듈. 연관 배열 미사용(스칼라·case·awk).
- **주요 의존성**: tmux(세션 제어·`has-session`/`new-session`/`kill-session`/`capture-pane`), jq(access.json 토폴로지 표시 — 그룹 C status 에서 기존 코드 재사용, 신규 jq 의존 추가 없음), `awk`+`mktemp`+`mv`(레지스트리 원자적 갱신), `chmod`/`kill -0`(BSD/POSIX 표준). **신규 외부 패키지·라이브러리 의존 0건**(순수 셸).
- **테스트 프레임워크**: `bats`(`tests/*.bats`) — 격리 상태 트리(`HOME`/`XDG_CONFIG_HOME`/`CC_CHANNELS_DIR` 샌드박스) + stateful fake `tmux`(`tests/stubs/tmux`). 정적 검증: `bash -n`, `shellcheck -S warning`, `scripts/check-i18n-keys.sh`.
- **외부 라이브러리 동작 검증 (핵심원칙 §10)**: 신규 외부 라이브러리 API 의존이 없으므로 §10/§13/§14(public/private API)·PROC-013(private lifecycle 4시나리오)은 **해당 없음**. 사용하는 외부 명령은 모두 OS 표준(tmux/awk/mktemp/mv/chmod/kill)이며 동작은 기존 코드(session.sh·registry.sh)에서 이미 검증된 패턴을 재사용한다. `kill -0 <pid>` 의 macOS Bash 3.2 지원은 ASM-004 로 확정(POSIX 표준 시그널 0).

### 위험 완화 설계 (PATCH-A06 — 운영 검증 미완료 가정 안전망)

assumptions.md ASM-001~005 는 모두 "확인 필요 여부: 불필요"(사용자 확정 / 코드 확인 / 범위 내 / OS 기본)로, 운영 검증 defer 항목이 없다. 다만 그룹 C 의 단독소유자 가드는 운영 환경(실제 전역 봇 기동 상태)에서만 완전히 드러나므로 다음 안전망을 설계에 포함한다.

- **단독소유자 가드 2중 체크(FR-006)**: tmux 세션 존재(`cctg-<reserved>`) **OR** `bot.pid` 생존(`kill -0`) 중 하나라도 참이면 기동 거부. 한쪽만 검사 시 발생할 수 있는 이중 기동(409)을 양쪽 검사로 차단. SC-015/SC-016 으로 각 경로 독립 검증.
- **bot.pid stale 처리**: `bot.pid` 파일이 있으나 PID 가 죽은 경우(`kill -0` 실패)는 거부하지 않고 기동 허용 — stale pid 로 인한 영구 기동 불가를 방지. (cctg 는 bot.pid 를 쓰지 않으므로 정리는 플러그인 책임 — P-002 비침해.)

### 배포 환경 영향 (PROC-009)

infra.md §1·§8: 컨테이너/NAT/LB/L4/firewall **없음**. 사용자 로컬 macOS 단일 환경. 본 spec 은 로컬 CLI 변경이며 배포 토폴로지·네트워크 미들웨어 영향 없음(spec-input.md Q19 cross-reference 와 일치). critical 영향 없음 → PATCH-A06 안전망 절차 추가 트리거 없음.

---

## 핵심 설계

> 작성 깊이: Design Agent 가 추가 설계 판단 없이 tasks.md 를 분해할 수 있는 수준. 변경 대상 모듈·신규 시그니처·핵심 분기 로직 포함.

### 레지스트리·lookup 구조 사실 (전 그룹 공통 전제)

- 레지스트리 행 형식: `name | cwd | state_dir | channel` (`|` 구분, 4컬럼; 3컬럼 레거시 행은 channel=telegram).
- `lookup "$name"`(registry.sh:50) 은 매치 행에서 **`cwd<TAB>state_dir`** 를 출력한다(awk `$2"\t"$3`). 따라서 호출측에서 `cut -f1 <<<"$row"` = cwd, `cut -f2 <<<"$row"` = state_dir. (cmd_config:232 가 `cut -f2` 로 state_dir 를 얻는 것이 이 이유다 — cwd 변경 설계 시 혼동 금지.)
- 레지스트리 갱신은 `awk -F'|' ... > tmp && mv tmp "$REGISTRY"` 패턴(registry.sh:15-44)을 표준으로 한다(NFR-005).

### 그룹 A: 사후 변경 커맨드 (config cwd/token)

**변경 대상**: `lib/commands.sh` (`cmd_config` case 확장), `lib/registry.sh` (cwd 갱신 함수 신설), `messages/en.sh`·`messages/ko.sh`.

#### A-1. `config <name> cwd <path>` (FR-001 / SC-001~003)

`cmd_config` 의 `case "$ACTION"` 에 `cwd)` 분기 추가. `cmd_config` 진입부(commands.sh:230-232)에서 이미 `row=lookup`, `sd=cut -f2` 를 확보하므로 cwd 는 `cut -f1 <<<"$row"` 로 추가 확보.

```
cwd)
  NEWCWD="${3-}"
  [ -z "$NEWCWD" ] && die ERR_CONFIG_CWD_USAGE "$PROG" "$NAME"        # 사용법
  [ -d "$NEWCWD" ] || die ERR_NO_SUCH_DIR "$NEWCWD"                    # SC-002: 존재 검증
  set_registry_cwd "$NAME" "$NEWCWD" || die ERR_REGISTRY_UPDATE       # SC-001: 2번 컬럼 원자 갱신
  t CFG_CWD_SET "$NAME" "$NEWCWD"
  if is_running "$NAME"; then t APPLY_RESTART "$PROG" "$NAME"; fi      # SC-003: 실행 중이면 restart 안내
  ;;
```

- 신규 함수 `set_registry_cwd <name> <newcwd>` (registry.sh) — `rename_registry_line` 와 동형 awk+mktemp+mv. 매치 행의 2번 컬럼만 newcwd 로 치환, 1·3·4 컬럼·주석·빈 줄 보존:

```
set_registry_cwd() {
  local name="$1" newcwd="$2" tmp
  tmp="$(mktemp)" || return 1
  awk -F'|' -v n="$name" -v nc="$newcwd" -v dc="$DEFAULT_CHANNEL" '
    /^[[:space:]]*#/ {print; next}
    /^[[:space:]]*$/ {print; next}
    { c1=$1; gsub(/^[ \t]+|[ \t]+$/,"",c1)
      if (c1==n) {
        c3=$3; gsub(/^[ \t]+|[ \t]+$/,"",c3)
        c4=$4; gsub(/^[ \t]+|[ \t]+$/,"",c4); if (c4=="") c4=dc
        printf "%s | %s | %s | %s\n", c1, nc, c3, c4; next
      }
      print
    }
  ' "$REGISTRY" > "$tmp" && mv "$tmp" "$REGISTRY"
}
```

> 설계 노트: `APPLY_RESTART` 키는 기존(commands.sh:274 mode 분기에서 사용)이라 재사용. restart 안내는 별도 신규 키 불필요. `ERR_REGISTRY_UPDATE` 도 기존 키.

#### A-2. `config <name> token` (FR-002 / SC-004~006)

`cmd_config` 의 `case` 에 `token)` 분기 추가. `cmd_add` 의 토큰 입력 블록(commands.sh:41-51)을 동일 로직으로 적용하되 argv 토큰 금지(P-003). 토큰 인자는 `${4-}` 이후로 `--token-env <VAR>` / `--token-stdin` 플래그를 파싱하고, 둘 다 없으면 대화형 마스킹 입력.

```
token)
  # $3 이후를 플래그로 파싱: --token-env <VAR> | --token-stdin (argv 토큰 직접 전달 금지)
  shift 2  # $1=name $2=action(token) 소비 → 남은 $@ 가 토큰 플래그
  local t_env="" t_stdin=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --token-env)   [ $# -ge 2 ] || die ERR_ADD_FLAG_VALUE "--token-env"; t_env="$2"; shift 2 ;;
      --token-stdin) t_stdin=1; shift ;;
      *)             die ERR_CONFIG_TOKEN_USAGE "$PROG" "$NAME" ;;
    esac
  done
  if [ "$t_stdin" = 1 ]; then IFS= read -r NEWTOK || true
  elif [ -n "$t_env" ]; then
    printf '%s' "$t_env" | grep -qE '^[A-Za-z_][A-Za-z0-9_]*$' || die ERR_ADD_BAD_ENVNAME "$t_env"
    NEWTOK="${!t_env-}"
  else t ADD_PROMPT_TOKEN; read -rs NEWTOK; echo; fi
  [ -z "$NEWTOK" ] && die ERR_EMPTY_TOKEN                              # SC-005
  # 채널 토큰 키 결정 → .env 재작성 + 600
  local tk; tk="$(channel_spec "$(channel_of "$NAME")" token_key)"     # SC-006: discord=DISCORD_BOT_TOKEN
  printf '%s=%s\n' "$tk" "$NEWTOK" > "$sd/.env" && chmod 600 "$sd/.env" # SC-004
  t CFG_TOKEN_SET "$NAME"
  if is_running "$NAME"; then t APPLY_RESTART "$PROG" "$NAME"; fi
  ;;
```

> 설계 노트 / Design Agent 결정 포인트(ASM-003/005 위임):
> - `ERR_EMPTY_TOKEN`·`ERR_ADD_FLAG_VALUE`·`ERR_ADD_BAD_ENVNAME`·`ADD_PROMPT_TOKEN` 는 기존 키 재사용.
> - `${!var}` 간접 확장은 Bash 3.2 지원(cmd_add 가 이미 사용 — commands.sh:46). P-001 안전.
> - `.env` 재작성은 기존 키만 덮어쓰는 게 아니라 **파일 전체를 토큰 키 1줄로 재작성**한다 — cmd_add 와 동일 동작(commands.sh:69). `.env` 에 토큰 키 외 다른 키가 있을 수 있는지: cmd_add 가 토큰 키 1줄만 쓰므로 현 구조상 .env 는 토큰 전용. (만약 향후 .env 에 다른 키가 추가되면 set_env_kv 류 upsert 로 전환해야 하나, 현 spec 범위에선 전체 재작성이 cmd_add 와 정합.) SC-004 의 기대(`.env` 에 `TELEGRAM_BOT_TOKEN=<new>`)와 일치.

### 그룹 B: 자동완성 보강 + 서브커맨드 --help

**변경 대상**: `completions/_cctg`, `completions/cctg.bash` (FR-003/004/012), `cc-tg.sh` 또는 각 `cmd_*`(FR-005 --help), `messages/en.sh`·`messages/ko.sh` (USAGE_<SUBCMD> 키).

#### B-1. mode 값 완성 (FR-003 / SC-007~008)

- zsh(`completions/_cctg:55-61`) `config` 케이스: `CURRENT == 5` 이고 `${words[4]} == mode` 일 때 6개 모드를 `compadd`(설명 포함은 `_values`/`_describe` 로). 기존 `common`/`add --mode` 케이스가 이미 6모드 리터럴(`acceptEdits auto bypassPermissions default dontAsk plan`)을 쓰므로 동일 리터럴 사용.
- bash(`completions/cctg.bash:29-30`) `config` 케이스: `COMP_CWORD -eq 4` 이고 `${COMP_WORDS[3]} == mode` 일 때 `compgen -W "acceptEdits auto bypassPermissions default dontAsk plan"`.

#### B-2. config 액션에 cwd·token 추가 (FR-004 / SC-009)

- zsh `_cctg:60`: `compadd -- show edit mode args snapshot cwd token`.
- bash `cctg.bash:30`: `compgen -W "show edit mode args snapshot cwd token"`.

#### B-3. 서브커맨드별 `--help` (FR-005 / SC-010~012)

**디스패치 패턴(ASM-003 — Design 확정 권고안)**: `cc-tg.sh` 디스패처에서 각 `cmd_*` 호출 **전에** 인자에 `--help`/`-h` 가 있으면 해당 서브커맨드 USAGE 를 출력하고 exit 0. 중앙 1곳 처리가 16개 cmd_* 함수 내부 수정보다 표면·중복이 작다(P-005).

```
# cc-tg.sh case 디스패치 직전, CMD 확정 후:
case "$CMD" in
  add|rm|rename|config|common|up|down|restart|status|logs|attach|lang|doctor|update|version|help)
    for a in "$@"; do
      case "$a" in --help|-h) sub_usage "$CMD"; exit 0 ;; esac
    done ;;
esac
```

`sub_usage <subcmd>` (신규, util.sh 또는 commands.sh): `case` 로 `t USAGE_<SUBCMD> "$PROG"` 호출. 예:

```
sub_usage() {
  case "$1" in
    add)    t USAGE_ADD "$PROG" ;;
    config) t USAGE_CONFIG "$PROG" ;;
    up)     t USAGE_UP "$PROG" ;;
    ...     # 16개 서브커맨드 전부
    *)      usage ;;
  esac
}
```

- 완성 파일: 각 서브커맨드 플래그 후보에 `--help` 추가(zsh `_cctg`·bash `cctg.bash`). 예 add 케이스의 플래그 `compadd`/`compgen -W` 목록에 `--help` 추가. config·up·down 등도 적절 위치에.

> Design Agent 결정 포인트: USAGE_<SUBCMD> 메시지 16개를 en.sh/ko.sh 에 신규 키로 추가. 본 spec 의 명시 SC 는 add(SC-010)·config(SC-011) 2개이나 FR-005 는 16개 서브커맨드 전체를 요구 → 16개 키 모두 추가(패리티 SC-013 으로 검증). `version`/`help` 의 --help 는 자기 출력으로 갈음 가능(Design 판단).

### 그룹 C: 예약어 런타임 지원

**변경 대상**: `lib/commands.sh`(`cmd_up`/`cmd_down`/`cmd_restart`/`cmd_status`/`cmd_logs` 예약어 분기), `lib/session.sh`(예약어 전용 up/down 경로), `messages/*`.

#### 핵심 설계 결정: 예약어 전용 경로 분기 (레지스트리 우회)

예약어는 레지스트리에 없으므로 `lookup` 이 실패한다. up_one/down_one(session.sh:64,108)이 `lookup` 으로 시작하므로 그대로는 ERR_NOT_REGISTERED. 따라서 **명령 진입부(cmd_up/down/restart/status/logs)에서 `is_reserved_name` 분기**하여 예약어 전용 헬퍼로 라우팅한다. 비예약어는 기존 경로 불변(하위호환 P-005).

전역 봇 좌표(예약어 `<ch>` 공통):
- cwd = `$PWD` (cctg 호출 시점 현재 작업 디렉터리, DEC-001) — 레지스트리에 없는 전역 봇은 lookup 으로 cwd 를 조회할 수 없으므로 호출 시점의 셸 현재 디렉터리를 그대로 사용한다. `$PWD` 는 일반적으로 존재하나 삭제된 디렉터리에서 호출될 수 있으므로, up 경로에서 up_one 과 동형의 `[ -d "$cwd" ]` 가드를 적용한다(아래 C-1·SC-025).
- state_dir = `$CHANNELS_DIR/<ch>` (= `~/.claude/channels/<ch>/`)
- 세션명 = `cctg-<ch>` (`sess_of "<ch>"` 그대로 동작 — SESS_PREFIX 적용)
- channel = `<ch>` 자체(telegram/discord) → `channel_spec` descriptor 직접 사용

#### C-1. `up <reserved>` (FR-006 / SC-014~017)

`cmd_up` 진입부:
```
TARGET="${1:?...}"
if is_reserved_name "$TARGET"; then up_reserved "$TARGET"; return; fi
# 기존 all/단일 경로 …
```

신규 `up_reserved <ch>` (session.sh) — up_one 의 예약어판. lookup 대신 고정 좌표 사용:
```
up_reserved() {
  local ch="$1" sd cwd
  # imessage/fakechat 는 channel_spec 미정의 → 미지원(범위 외). descriptor 조회 실패면 거부.
  channel_spec "$ch" plugin >/dev/null 2>&1 || { te ERR_RESERVED_UNSUPPORTED "$ch"; return 1; }
  sd="$CHANNELS_DIR/$ch"; cwd="$PWD"                                   # DEC-001: cctg 호출 시점 현재 작업 디렉터리
  [ -d "$cwd" ] || { te ERR_NO_CWD "$cwd"; return 1; }                 # SC-025: $PWD 가 삭제된 경우 거부(up_one 과 동형 가드)
  [ -f "$sd/.env" ] || { te ERR_NO_TOKEN "$sd/.env"; return 1; }       # SC-017
  # 단독소유자 가드 (SC-015 / SC-016)
  if is_running "$ch"; then te ERR_RESERVED_UP_OCCUPIED "$ch"; return 1; fi    # cctg-<ch> 세션
  if reserved_runner_alive "$sd"; then te ERR_RESERVED_UP_RUNNER "$ch"; return 1; fi  # bot.pid 생존
  # 기동 — up_one 의 tmux new-session 패턴 재사용(cwd=$PWD, descriptor 경유 plugin/statedir_env)
  ... tmux new-session -d -s "$(sess_of "$ch")" ...
  t RESERVED_UP "$ch" "$(sess_of "$ch")"
}

reserved_runner_alive() {  # bot.pid 존재 + PID 생존(kill -0). stale 이면 false(기동 허용)
  local pidf="$1/bot.pid" pid
  [ -f "$pidf" ] || return 1
  pid="$(head -n1 "$pidf" 2>/dev/null)"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null  # ASM-004: kill -0 macOS Bash 3.2 지원
}
```

> 설계 노트: up_reserved 의 tmux 기동 launch 문자열은 up_one(session.sh:86-95)과 동형이되 `cwd=$PWD`(DEC-001 — `cd $(printf '%q' "$cwd")` 로 호출 시점 현재 디렉터리에서 기동, SC-025), `ch` 고정, `shared_arg`(ensure_shared_settings) 동일 주입. up_one 이 `[ -d "$cwd" ]` 가드(session.sh:67)를 갖는 것과 동형으로 up_reserved 도 위 가드를 선행한다. launch.env 는 전역 봇 디렉터리에 cctg 가 안 만들 수 있으므로 `[ -f launch.env ] && source || true` 가드(up_one 에 이미 있음)로 부재 허용. 중복 최소화를 위해 up_one 을 좌표 파라미터화하는 리팩토링도 가능하나(Design 판단), 하위호환·가독성상 별도 함수 권고.

#### C-2. `down <reserved>` (FR-007 / NFR-003 / SC-018~019)

```
# cmd_down 진입부
if is_reserved_name "$TARGET"; then down_reserved "$TARGET"; return; fi

down_reserved() {  # cctg-<ch> tmux 세션만 kill. bot.pid 러너는 종료 대상 아님(NFR-003)
  local ch="$1"
  if is_running "$ch"; then
    tmux kill-session -t "$(sess_of "$ch")"
    t DOWN_OK "$ch"
  else
    t RESERVED_DOWN_NONE "$ch"   # SC-019: "세션 없음" + bot.pid 한계 명시 메시지
  fi
}
```

> NFR-003 한계는 `RESERVED_DOWN_NONE`(또는 별도 `RESERVED_DOWN_LIMIT`) 메시지에 "cctg 가 띄운 tmux 세션만 종료 가능, 플러그인 자체 러너(bot.pid)는 종료하지 않음"을 명시. SC-024: down_reserved 는 `.env`·`access.json` 미접근(스냅샷도 전역 봇엔 미적용 — take_snapshot 호출 안 함). P-002 안전.
> 설계 노트: 전역 봇은 cctg launch.env·스냅샷 watcher 가 없으므로 down_reserved 는 stop_snapshotter/take_snapshot 를 호출하지 않는다(프로젝트 봇 down_one 과 분기되는 이유).

#### C-3. `restart <reserved>` (FR-008)

`cmd_restart` 진입부에 `is_reserved_name` 분기 → `down_reserved "$TARGET"; up_reserved "$TARGET"`. (FR-007 → FR-006 순서.) 별도 SC 없음(SC-018+SC-014 조합으로 충분 — 매트릭스 명시).

#### C-4. `status` 에 예약어 봇 표시 (FR-009 / SC-020)

`cmd_status` 는 이미 `STATUS_GLOBAL "$CHANNELS_DIR"` 헤더를 출력(commands.sh:368)한 뒤 프로젝트 봇만 순회. 여기에 **예약어 봇 섹션**을 추가: `RESERVED_NAMES` 중 `channel_spec <ch> plugin` 이 정의되고 `$CHANNELS_DIR/<ch>/` 디렉터리가 존재하는 것을 순회하여 프로젝트 봇과 동일 형식(RUNNING/stopped/BROKEN)으로 출력.
```
# 프로젝트 봇 순회 전/후에 예약어 섹션:
for ch in $RESERVED_NAMES; do
  channel_spec "$ch" plugin >/dev/null 2>&1 || continue
  sd="$CHANNELS_DIR/$ch"; [ -d "$sd" ] || continue
  cwd="$PWD"   # DEC-001: cctg(status) 호출 시점 현재 작업 디렉터리
  issues=""; [ -f "$sd/.env" ] || issues="$(t ISSUE_NO_TOKEN)"
  if is_running "$ch"; then ... STATUS_RUNNING ...
  elif [ -n "$issues" ]; then STATUS_BROKEN
  else STATUS_STOPPED; fi
  ... STATUS_PATHS "$cwd" "$sd" / STATUS_CHANNEL ...
done
```
> 설계 노트: status 의 cwd=$PWD 는 status 호출 시점 현재 디렉터리를 **표시용**으로 보여주는 값이다(레지스트리에 없는 전역 봇이라 영속 cwd 가 없음 — DEC-001). status 의 BROKEN 판정은 cwd 존재 여부와 무관하며 **토큰 부재(no-token)만**을 사유로 한다 — cwd 디렉터리 존재 가드는 기동(up)을 실제로 시도하는 up_reserved 의 책임이지(C-1·SC-025), 상태 조회를 차단할 사유가 아니다(이미 실행 중인 세션은 다른 디렉터리에서 기동되었을 수 있음). status_json(--json) 도 동일 정책 반영 권고(SC-020 은 사람용 출력만 검증하나 형식 일관성). Design 판단: 예약어 표시를 `STATUS_PROJECT_HEADER` 와 구분되는 헤더(`STATUS_RESERVED_HEADER`)로 둘지 여부.

#### C-5. `logs <reserved> [N]` (FR-010 / SC-021)

`cmd_logs` 진입부에 `is_reserved_name` 분기:
```
if is_reserved_name "$NAME"; then
  if is_running "$NAME"; then tmux capture-pane -p -S -2000 -t "$(sess_of "$NAME")" | tail -n "$N"; return; fi
  snap="$CHANNELS_DIR/$NAME/last-session.log"
  [ -f "$snap" ] && { t LOGS_SNAPSHOT "$NAME"; tail -n "$N" "$snap"; return; }
  die LOGS_STOPPED "$NAME" "$PROG" "$NAME"
fi
```
기존 비예약어 경로 불변.

#### C-6. `add`/`rm`/`rename` 예약어 차단 유지 (FR-011 / SC-022)

변경 없음 — cmd_add(commands.sh:30)·cmd_rename(204) 이 `is_reserved_name && die ERR_RESERVED` 이미 보유. cmd_rm 은 `lookup` 실패로 ERR_NOT_REGISTERED(예약어는 레지스트리에 없음) → 차단 효과 동일. SC-022 는 add 기준 검증.

---

## 결정 기록 (ADRs)

> spec.md "요구사항 구조화 매트릭스" 의 FR/NFR 를 plan 결정에 매핑. Design Agent 의 research.md "기술 선택 조사" 절과 cross-reference 한다.

| ADR-ID | 결정 항목 | 채택안 | 대안 (검토했으나 채택 안 함) | 근거 (spec FR/NFR 참조) | 영향 범위 |
|---|---|---|---|---|---|
| ADR-001 | cwd/token 사후 변경 커맨드 표면 | 기존 `config <name>` 의 서브액션(cwd/token)으로 확장 | 신규 top-level 명령 `cctg setcwd`/`settoken` 신설 | FR-001/FR-002, P-005(최소 표면), Q-A2 채택 | `cmd_config` case |
| ADR-002 | 레지스트리 cwd 갱신 방식 | `set_registry_cwd` 신규 함수 — `rename_registry_line` 동형 awk+mktemp+mv (2번 컬럼만 치환) | 기존 함수 재활용(컬럼 의미 불일치) / `sed -i`(macOS BSD 비호환·비원자) | FR-001, NFR-005(원자 갱신), ASM-005 | `lib/registry.sh` |
| ADR-003 | token 입력 경로 | `cmd_add` 토큰 블록 재사용 — 대화형 마스킹 / `--token-env` / `--token-stdin`, argv 금지 | argv 토큰 인자 허용(편의) | FR-002, NFR-004/P-003(시크릿 비노출) | `cmd_config` token 분기 |
| ADR-004 | .env 재작성 방식 | 토큰 키 1줄로 파일 전체 재작성 + chmod 600 (cmd_add 와 정합) | `set_env_kv` upsert(다른 키 보존) | FR-002/SC-004, 현 .env 는 토큰 전용 | `cmd_config` token 분기 |
| ADR-005 | 서브커맨드 --help 디스패치 | `cc-tg.sh` 중앙 디스패처에서 `--help`/`-h` 선검사 → `sub_usage` 출력 후 exit 0 | 16개 cmd_* 함수 내부 각각 처리(중복·표면 증가) | FR-005, P-005 | `cc-tg.sh`, 신규 `sub_usage` |
| ADR-006 | 예약어 런타임 경로 | 명령 진입부 `is_reserved_name` 분기 → 예약어 전용 헬퍼(up_reserved/down_reserved/...) | up_one/down_one 에 예약어 좌표 주입(레지스트리 lookup 분기 삽입 — 기존 경로 침습) | FR-006~010, P-005(하위호환), DEC-001(cwd=$PWD) | `cmd_up/down/restart/status/logs`, `session.sh` |
| ADR-007 | 단독소유자 가드 | tmux 세션 존재 OR bot.pid 생존(`kill -0`) 2중 체크. stale bot.pid 는 기동 허용 | tmux 세션만 체크(러너 이중기동 미방지) / bot.pid stale 도 거부(영구 기동 불가) | FR-006/SC-015/SC-016, ASM-004 | `up_reserved`, `reserved_runner_alive` |
| ADR-008 | 예약어 down 의 스냅샷·watcher | 호출하지 않음(전역 봇엔 cctg launch.env·watcher 없음, P-002 비침해) | down_one 그대로 사용(stop_snapshotter/take_snapshot 호출) | FR-007/NFR-002/NFR-003, P-002 | `down_reserved` |
| ADR-009 | 완성 파일 채널·모드 리터럴 | 기존 로컬 리터럴 미러 유지 — lib source 안 함 | 완성 파일에서 `lib/channels.sh` source | FR-003/FR-004, NFR-006(ADR-003 준용) | `completions/*` |
| ADR-010 | imessage/fakechat 예약어 런타임 | `channel_spec <ch> plugin` 미정의 → 미지원(거부/skip) | 임의 plugin 추정 기동 | spec "범위 외", FR-006 전제 | `up_reserved`/`cmd_status` 가드 |

---

## 인터페이스 계약

- **`cmd_config` (commands.sh:228)**: 기존 액션(show/edit/mode/args/snapshot) 분기 **불변**. 신규 `cwd)`/`token)` case 만 추가. `*)` fallthrough(ERR_CONFIG_UNKNOWN) 유지 → 기존 호출자 영향 없음.
- **`cmd_up/down/restart/status/logs` (commands.sh)**: 진입부에 `is_reserved_name` 분기 추가. 비예약어 인자는 기존 코드 경로 100% 보존(하위 호환). `all` 인자는 예약어가 아니므로 기존 분기 그대로(예약어는 `up all` 대상에 미포함 — 의도).
- **`cc-tg.sh` 디스패처 (83-106)**: `--help`/`-h` 선검사 블록을 case 직전 추가. 기존 top-level `help|--help|-h` 처리(99행)는 CMD 가 빈/help 일 때만이므로 충돌 없음(`cctg --help` = top-level usage, `cctg add --help` = add usage).
- **`lib/registry.sh`**: `set_registry_cwd` 신규 추가(기존 함수 미수정).
- **`lib/session.sh`**: `up_reserved`/`down_reserved`/`reserved_runner_alive` 신규 추가(기존 up_one/down_one 미수정).
- **`completions/*`**: config 케이스 액션 목록 확장 + mode 값 케이스 추가 + 각 서브커맨드 `--help` 후보 추가. 다른 케이스 불변.
- **`messages/en.sh`·`ko.sh`**: 신규 `CCTG_MSG_*` 키 추가. 기존 키 미수정. en/ko 패리티 유지(check-i18n-keys.sh).
- **하위 호환성**: 레지스트리 스키마(`name|cwd|state_dir|channel`) 불변. launch.env·access.json·shared settings 스키마 불변. 기존 등록 봇·워크플로 영향 0.

---

## 데이터 모델

데이터 구조 **변경 없음**. 기존 엔티티 값만 갱신/조회:
- 레지스트리 행: cwd(2번 컬럼) 값만 변경(FR-001). 컬럼 추가·스키마 변경 없음.
- 상태 디렉터리 `.env`: 토큰 키 값 재작성(FR-002), 권한 600 유지. 키 이름은 `channel_spec <ch> token_key`.
- 전역 봇 좌표(예약어): cwd=`$PWD`(호출 시점 현재 디렉터리, DEC-001 — 영속 저장 없이 기동 시점에만 사용), state_dir=`$CHANNELS_DIR/<ch>`, session=`cctg-<ch>` — 새 영속 데이터 생성 없음(tmux 세션은 런타임 상태).

---

## 테스트 전략

> 테스트 수준: 그룹 A/C 의 [env:unit] SC 는 bats(격리 상태 트리 + fake tmux)로 단위 검증. 그룹 B 의 [env:static] SC 는 완성 파일·소스 정적 검증(grep/bash -n/check-i18n-keys.sh).
> 단위로 검증 불가능한 SC 없음 — 외부 봇/실 tmux 무접촉(fake tmux stub). 통합·E2E defer 항목 없음.

| SC | 수준 | 유형 | 시나리오 요약 | 입력 | 기대 결과 |
|---|---|---|---|---|---|
| SC-001 | 단위 | Happy | cwd 변경 → 레지스트리 2번 컬럼 갱신 | `config mybot cwd /new`(존재) | projects.conf mybot 2컬럼=/new, 성공 메시지 |
| SC-002 | 단위 | Error | 존재하지 않는 cwd 거부 | `config mybot cwd /nope` | ERR_NO_SUCH_DIR, exit≠0, 레지스트리 불변 |
| SC-003 | 단위 | Edge | 실행 중 cwd 변경 → restart 안내 | 봇 running + `config mybot cwd /new` | 레지스트리 갱신 + APPLY_RESTART 메시지 |
| SC-004 | 단위 | Happy | token 변경 → .env(telegram 키) 600 | `config mybot token --token-stdin`+토큰 | .env=`TELEGRAM_BOT_TOKEN=<new>`, perm 600 |
| SC-005 | 단위 | Error | 빈 토큰 거부 | `config mybot token --token-stdin`+빈입력 | ERR_EMPTY_TOKEN, exit≠0, .env 불변 |
| SC-006 | 단위 | Happy | discord 봇 token → DISCORD 키 | `config discordbot token --token-stdin` | .env=`DISCORD_BOT_TOKEN=<new>`, 600 |
| SC-007 | 정적 | Happy | zsh mode 완성 6종 | `config mybot mode <TAB>` | _cctg 에 6모드 리터럴 존재 |
| SC-008 | 정적 | Happy | bash mode 완성 6종 | `config mybot mode <TAB>` | cctg.bash compgen 6모드 |
| SC-009 | 정적 | Happy | config 액션에 cwd·token | `config mybot <TAB>` | 두 파일 액션 목록에 cwd token 포함 |
| SC-010 | 단위 | Happy | `add --help` 사용법 출력 | `cctg add --help` | USAGE_ADD 출력, exit 0 |
| SC-011 | 단위 | Happy | `config --help` 사용법 출력 | `cctg config --help` | USAGE_CONFIG 출력, exit 0 |
| SC-012 | 정적 | Happy | 완성에 --help 포함 | `add <TAB>`(플래그) | 완성 후보에 --help |
| SC-013 | 단위 | Edge | en/ko 키 패리티 | `bash scripts/check-i18n-keys.sh` | exit 0 |
| SC-014 | 단위 | Happy | `up telegram` 세션 기동 | .env 존재, 세션·pid 없음 | cctg-telegram 세션 생성, 성공 메시지 |
| SC-025 | 단위 | Happy | `up telegram` cwd=$PWD 기동 | `/some/project` 에서 호출, .env 존재, 세션 없음 | cctg-telegram 세션 시작 디렉터리=`/some/project`(DEC-001) |
| SC-015 | 단위 | Error | 가드: 세션 이미 존재 | cctg-telegram 세션 존재 | ERR_RESERVED_UP_OCCUPIED, exit≠0, 신규 세션 없음 |
| SC-016 | 단위 | Error | 가드: bot.pid 생존 | bot.pid 살아있는 PID | ERR_RESERVED_UP_RUNNER, exit≠0 |
| SC-017 | 단위 | Error | .env 없음 거부 | telegram/.env 없음 | ERR_NO_TOKEN, exit≠0 |
| SC-018 | 단위 | Happy | `down telegram` 세션 종료 | cctg-telegram 실행 중 | 세션 종료, DOWN_OK |
| SC-019 | 단위 | Edge | down: 세션 없음(pid 러너만) | cctg-telegram 세션 없음 | RESERVED_DOWN_NONE 메시지, bot.pid kill 시도 없음 |
| SC-020 | 단위 | Happy | status 에 예약어 봇 표시 | telegram/ 디렉터리 존재, 세션 없음 | telegram [stopped] 또는 [BROKEN] 출력 |
| SC-021 | 단위 | Happy | `logs telegram` 출력 | cctg-telegram 실행 중 | capture-pane 결과 출력 |
| SC-022 | 단위 | Error | 예약어 add/rm/rename 차단 | `cctg add telegram /p` | ERR_RESERVED, exit≠0 |
| SC-023 | 정적 | Edge | Bash 3.2 구문 | 신규 코드 정적 스캔 | declare -A·Bash4+ 0건 (bash -n + grep) |
| SC-024 | 단위 | Edge | down 이 .env/access.json 불변 | telegram down 실행 | 두 파일 내용·mtime 불변 |

**SC별 시나리오 유형 커버리지**: Happy(SC-001/004/006/007/008/009/010/011/012/014/025/018/020/021), Edge(SC-003/013/019/023/024), Error(SC-002/005/015/016/017/022). 세 유형 모두 포함 — 그룹별 정상/경계/오류 균형 확보.

**SC-025($PWD 기동) 의 디렉터리 부재 엣지**: SC-025 는 정상 경로(현재 디렉터리에서 기동) 검증이다. `$PWD` 가 삭제된 디렉터리에서 호출되는 비정상 케이스는 up_reserved 의 `[ -d "$cwd" ] || die ERR_NO_CWD`(C-1, up_one:67 동형) 가드로 처리되며 ERR_NO_CWD 로 거부된다. 이 가드 경로(ERR_NO_CWD)는 SC-002(config cwd 비존재 거부)와 동일한 `[ -d ]` 검증 패턴이므로 Test Agent 가 SC-025 의 Error 보조 케이스(삭제된 cwd 에서 `up telegram` → ERR_NO_CWD, 세션 미생성)로 보강 권고.

**FR-008(restart 예약어)**: 별도 SC 없음. SC-018(down) + SC-014(up) 조합으로 검증(매트릭스 명시). Test Agent 가 통합 시나리오(restart → down then up 호출 순서)로 보강 권고.

### smoke_tests

- 필요 여부: N
- 근거: 변경이 모두 SC 매핑 범위 내(config 액션 추가·완성 파일·예약어 분기). 기존 SC 밖 중요 경로(add/up_one 핵심 흐름)에 회귀 유발 가능성은 진입부 `is_reserved_name` 분기 추가가 비예약어 경로를 우회하지 않도록 설계됨(하위호환 보장). 기존 bats 81개 스위트가 회귀 안전망으로 충분.

### 통합/운영 검증 defer (PATCH-A08 / PROC-010)

- 본 spec 은 통합 테스트·운영 검증을 **defer 하지 않는다** — 모든 SC 가 bats 단위(fake tmux) 또는 정적으로 자동 검증 가능. 옵션 A/B/C 선택 불요.
- 다만 실제 전역 봇 DM 응답·bot.pid 러너 상호작용은 단위 mock 으로 완전 재현 불가 → 사후 운영 검증 시나리오는 아래 PROC-014 로 명시.

### 사후 운영 검증 피드백 사이클 (PROC-014)

본 파이프라인 종료 후 사용자가 로컬 운영에서 점검할 시나리오(spec.md "범위 외 — 사후 운영 검증 피드백 사이클" 와 일치):
1. `up telegram` 후 실제 Telegram DM 응답 정상 확인.
1-a. 특정 프로젝트 디렉터리에서 `up telegram` 기동 후, 전역 봇 세션의 cwd 가 그 디렉터리로 설정되어 해당 프로젝트 컨텍스트로 동작하는지 확인(DEC-001/SC-025).
2. bot.pid 생존 상태에서 `up telegram` → 거부 안내 메시지 확인(실 플러그인 러너 동시 실행 시).
3. `config mybot cwd /new` 후 `up mybot` 으로 새 경로 기동 확인.
4. `config mybot token` 후 `restart mybot` 으로 새 토큰 적용 확인.

결함 발견 시 처리: 결함 정보를 spec.md "배경 및 목적" 또는 별도 hotfix spec 입력으로 → main session "spec 수정" 이벤트 → 1단계 재진입(cycle N+1) 또는 patch spec, 직전 cycle 산출물은 `_ai-workspace/cycle-N-archive/` 백업 보존. 사후 검증 결과는 Retrospective Agent(PROC-008) 가 확인.

---

## 기타 고려사항

- **`up all` 과 예약어**: `cmd_up all` 은 `all_names()`(레지스트리)만 순회하므로 예약어 봇은 `all` 대상에서 제외된다(의도 — 전역 봇은 명시적 `up telegram` 만). 설계상 자연 분리.
- **동시성/공유 상태**: 예약어 단독소유자 가드는 cctg 측 이중 기동을 막지만, cctg 와 플러그인 러너의 진정한 상호배제는 OS 레벨 lock 이 아님(bot.pid 는 플러그인 소유). stale bot.pid 허용 정책(ADR-007)으로 영구 락아웃은 회피. 한계는 사용자 안내 메시지로 명시(NFR-003).
- **i18n 신규 키 목록(초안 — Design/Test 가 확정)**: `ERR_CONFIG_CWD_USAGE`, `ERR_NO_SUCH_DIR`, `CFG_CWD_SET`, `ERR_CONFIG_TOKEN_USAGE`, `CFG_TOKEN_SET`, `RESERVED_UP`, `ERR_RESERVED_UP_OCCUPIED`, `ERR_RESERVED_UP_RUNNER`, `ERR_RESERVED_UNSUPPORTED`, `RESERVED_DOWN_NONE`(NFR-003 한계 명시), `STATUS_RESERVED_HEADER`(선택), `USAGE_ADD`~`USAGE_HELP`(16개 서브커맨드). en/ko 동시 추가(SC-013). 기존 재사용: `ERR_EMPTY_TOKEN`/`ADD_PROMPT_TOKEN`/`ERR_ADD_FLAG_VALUE`/`ERR_ADD_BAD_ENVNAME`/`APPLY_RESTART`/`ERR_REGISTRY_UPDATE`/`ERR_NO_TOKEN`/`ERR_NO_CWD`(up_reserved 의 $PWD 부재 가드 — up_one 과 동일 키, SC-025)/`DOWN_OK`/`STATUS_*`/`LOGS_*`.
- **매직 넘버 회피**: 6모드 목록은 `VALID_MODES`(env.sh:13)가 SoT 이나 완성 파일은 lib source 안 함(ADR-009/NFR-006) → 리터럴 미러 불가피. 완성 파일 주석에 "env.sh VALID_MODES 미러" 명시 권고(채널 미러 주석 패턴과 동일).
- **Edge: `config <name> token` 의 name 이 미등록**: cmd_config 진입부 `lookup ... || die ERR_NOT_REGISTERED`(commands.sh:231)가 이미 처리 → token/cwd 분기 도달 전 거부. 별도 처리 불요.
