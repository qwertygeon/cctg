---
작성: Planning Agent
버전: v1.0
최종 수정: 2026-06-17 14:59
상태: 작성중
---

# Plan: discord-channel-support

> Branch: feature/v0.4.0-001-discord | Date: 2026-06-17 | Spec: [spec.md](../spec/spec.md)

## 목차

- [사전 검증 (Constitution Gates)](#사전-검증-constitution-gates)
- [기술 컨텍스트](#기술-컨텍스트)
- [외부 라이브러리 동작 검증](#외부-라이브러리-동작-검증)
- [핵심 설계](#핵심-설계)
- [결정 기록 (ADRs)](#결정-기록-adrs)
- [인터페이스 계약](#인터페이스-계약)
- [데이터 모델](#데이터-모델)
- [테스트 전략](#테스트-전략)
- [기타 고려사항](#기타-고려사항)

---

## 사전 검증 (Constitution Gates)

> `{project}/.claude/docs/constitution.md` 가 존재하므로 그 조항(P-001~P-005)을 Gates 로 사용한다.
> constitution §3 선언: SLA·측정 대상 NFR 없음 → 성능·품질 수치화 면제(기능 모호 표현은 항상 구체화). 정량 커버리지 임계 미설정 — "변경 동작 대응 테스트 추가 + CI green" 으로 갈음.

- [x] **P-001 macOS · Bash 3.2 호환**: [Pass 기준] 변경된 모든 셸 파일이 `bash --norc --noprofile --posix -n` 통과(SC-021). 연관배열·Bash4+ 문법 미도입. → channel_spec 는 기존 `case "$1:$2"` 구조 유지(필드 4개 추가도 case 분기), `--group` 다중 파싱은 위치인자 루프 + `:` 토큰 split(파라미터 확장만)으로 연관배열 불요. groups JSON 누적은 jq 인자 전달로 구성. **PASS**
- [x] **P-002 전역 채널 봇·사용자 상태 비침해 (안전)**: [Pass 기준] 예약 이름(telegram/discord/imessage/fakechat) add 거부 유지(`is_reserved_name` — env.sh `RESERVED_NAMES`, 본 spec 미변경), 외부 상태 디렉터리 보호(`ERR_FOREIGN_STATEDIR`, 미변경). discord 봇은 사용자 지정 `<name>` 디렉터리에만 쓰며 전역 `~/.claude/channels/discord/` 를 건드리지 않음. **PASS**
- [x] **P-003 시크릿 비노출**: [Pass 기준] `DISCORD_BOT_TOKEN` 을 argv 로 받지 않고 기존 `--token-env`/`--token-stdin`/대화형 경로 그대로 사용(NFR-002, SC-022). token_key 는 descriptor 경유. **PASS**
- [x] **P-004 git/gh 변경 사용자 확인**: [Pass 기준] 본 단계는 산출물(plan.md) 작성만 수행, git 변경 없음. 구현 단계에서도 커밋·태그는 사용자 확인. **PASS (해당 없음 — 위반 가능성 없음)**
- [x] **P-005 최소 명령 표면 · 하위호환**: [Pass 기준] 신규 플래그 `--group` 1개만 추가(NFR-004, SC-029). 세부속성은 컴파운드 토큰 수식어로 표현(ADR-002). 레지스트리 스키마 불변 — 레거시 3컬럼 행은 `channel_of` 가 `DEFAULT_CHANNEL=telegram` 처리(NFR-003, SC-023). access.json 시드에서 `pending` 제거는 plugin `readAccessFile()` 가 `?? {}` 로 흡수하므로 하위호환(외부 검증 절 참조). **PASS**

예외 사항: 없음.

> Gates 전체 PASS, 예외 0건 → Design Agent 진행 가능.

---

## 기술 컨텍스트

- **언어 / 런타임**: Bash 3.2 (macOS 기본). 진입점 `cc-tg.sh` 가 `lib/*.sh` 를 런타임 source. jq(선택 — status 토폴로지·access.json 시드 구성에 사용).
- **주요 의존성**: jq(access.json groups 구성 / status 파싱 — NFR-005 graceful degradation), tmux/claude/caffeinate(기동 — 본 spec 미변경). discord 플러그인은 런타임 의존(ASM-001, cctg add 시점에는 불요).
- **테스트 프레임워크**: bats(`tests/*.bats`) — 격리 상태 트리(`HOME`/`XDG_CONFIG_HOME`/`CC_CHANNELS_DIR` 샌드박스) + stateful fake `tmux`. 정적 검증은 `bash -n` + grep/파일 존재(infra.md §6 검증 명령과 동일).
- **변경 대상 파일(신규 파일 0)**: `lib/channels.sh`, `lib/commands.sh`, `messages/en.sh`, `messages/ko.sh`, `completions/_cctg`, `completions/cctg.bash`.
- **배포 환경 영향(PROC-009)**: 본 spec 은 로컬 macOS CLI 셸 스크립트 변경. infra.md §1 "dev/staging/prod 구분 없음 · 사용자 로컬 macOS 단일 환경", §8 "컨테이너/서버 부재". 컨테이너 NAT·L4 LB·kernel keepalive 등 운영 토폴로지 영향 없음. 배포 = 사용자 머신 `install.sh` 재실행 + GitHub Release(서버측 자동) — 셸 스크립트 복사만 갱신. critical 영향 없음.

---

## 외부 라이브러리 동작 검증

> Planning 핵심원칙 §10 — spec 가정이 외부 라이브러리 API 동작에 의존하는 경우 venv 소스/공식 문서로 1회 확인.

**검증 대상 (ASM-003)**: "discord access.json 시드에서 `"pending"` 필드를 제거(생략)해도 discord 플러그인 동작에 영향이 없는가?"

**소스 인용**: `~/.claude/plugins/cache/claude-plugins-official/discord/0.0.4/server.ts`

```ts
// readAccessFile() — L151~165
const parsed = JSON.parse(raw) as Partial<Access>
return {
  dmPolicy: parsed.dmPolicy ?? 'pairing',
  allowFrom: parsed.allowFrom ?? [],
  groups: parsed.groups ?? {},
  pending: parsed.pending ?? {},   // ← 부재 시 {} 로 기본값 채움
  ...
}
```

- 타입 정의(L105~121): `Access.pending: Record<string, PendingEntry>` 는 비-optional 이지만, **로드는 `Partial<Access>` 로 파싱 후 `parsed.pending ?? {}`** 로 누락을 흡수한다.
- `defaultAccess()`(L123~130)도 `pending: {}` 로 초기화하며, 파일 부재(ENOENT) 시 이를 반환.
- **결론**: 시드 JSON 에서 `"pending"` 을 생략해도 플러그인은 첫 로드 시 `pending:{}` 로 보정한다. **가정과 실제 동작 일치** → FR-004(pending 제거)는 plugin-compatible. BLOCKED 불요.

**검증 대상 (FR-002 discord descriptor 값 — FR/매트릭스 일치)**: discord descriptor 값(plugin/statedir_env/token_key/dmPolicy 기본)이 플러그인 규약과 일치.

- `STATE_DIR = process.env.DISCORD_STATE_DIR ?? .../channels/discord`(L37) → statedir_env=`DISCORD_STATE_DIR` 일치.
- `TOKEN = process.env.DISCORD_BOT_TOKEN`(L53) → token_key=`DISCORD_BOT_TOKEN` 일치.
- `defaultAccess().dmPolicy='pairing'`(L125) → discord seed_policy=`pairing` 기본 일치(FR-002).
- `GroupPolicy = { requireMention: boolean; allowFrom: string[] }`(L100~103), `groups: Record<channelSnowflake, GroupPolicy>`(L108~109) → FR-008 `groups["<id>"]={requireMention,allowFrom}` 스키마 일치.

**인정되는 한계(PATCH-A07)**: 위 검증은 정적 스키마·로드 경로 한정. 실제 페어링 코드 발급·DM 수신·서버채널 멘션 트리거는 실제 Discord API 연결을 요구(spec "범위 외" — 통합 테스트 제외). cctg 책임은 초기 시드 JSON 생성까지이며, 런타임 동작은 플러그인 소유. 안전망: 본 spec 의 모든 access.json 시드는 unit 테스트에서 jq 로 키·값을 단언(SC-009~011, 025~032)하여 시드 구조 정확성을 보장. 런타임 결함은 spec "사후 운영 검증 피드백 사이클"(PROC-014)로 처리.

---

## 핵심 설계

> 작성 깊이: Design Agent 가 추가 설계 판단 없이 tasks.md 를 분해할 수 있는 수준. 변경 대상 모듈·인터페이스·핵심 분기 로직 포함.

### 1. `lib/channels.sh` — descriptor 8필드 + IMPLEMENTED_CHANNELS (FR-001, FR-002)

- `IMPLEMENTED_CHANNELS="telegram discord"` 로 변경 (SC-001).
- `channel_spec()` case 에 telegram·discord 각 4개 신규 필드 추가, discord 기존 4필드 활성화(주석 해제). 총 16개 case arm.
  - telegram: `display=Telegram`, `id_label="Telegram numeric ID"`, `id_required=yes`, `seed_policy=allowlist`.
  - discord: `plugin=plugin:discord@claude-plugins-official`, `statedir_env=DISCORD_STATE_DIR`, `token_key=DISCORD_BOT_TOKEN`, `token_required=yes`, `display=Discord`, `id_label="Discord user snowflake"`, `id_required=no`, `seed_policy=pairing` (SC-002, SC-004, SC-005, SC-006).
- `id_label` 영문 고정값(런타임 언어 무관 — 메시지 카탈로그가 아닌 descriptor 메타). 한국어 라벨 필요성은 spec 범위 외(현 telegram 프롬프트도 키 자체에 채널명 포함, 본 spec 은 그 채널 특정 문자열을 descriptor 경유로 일반화).
- `*) return 1` 분기 유지 — 미구현 채널의 새 필드 요청도 return 1 (ASM-006).

### 2. `lib/commands.sh` `cmd_add` — id_required / seed_policy / --group 분기 (FR-003, FR-004, FR-008)

**(a) 플래그 파싱 루프**: `--group` arm 추가. 반복 누적은 Bash 3.2 위치 변수 배열로:

```sh
# 파싱 루프에 추가 (ADR-002 컴파운드 토큰 채택 시)
--group) [ $# -ge 2 ] || die ERR_ADD_FLAG_VALUE "--group"; opt_groups="$opt_groups${opt_groups:+$GROUP_SEP}$2"; shift 2 ;;
```

- `opt_groups` 는 단일 스칼라에 구분자(예: 개행)로 누적 — 연관배열 불요(NFR-001). `--group` 미지정 시 빈 문자열 → `groups:{}`.

**(b) id_required 분기 (FR-003)**: 기존 `noninteractive=1 && --id 미제공 → die ERR_ADD_NEED_ID` 경로를 채널 분기로 감싼다.

```sh
# 현행 (commands.sh L50~57) 대체
if [ -n "$opt_id" ]; then
  TGID="$opt_id"
elif [ "$noninteractive" = 1 ]; then
  if [ "$(channel_spec "$CH" id_required)" = yes ]; then
    die ERR_ADD_NEED_ID            # telegram: 기존 동작 유지 (SC-008)
  else
    TGID=""                        # discord: --id 없이 진행 (SC-007)
  fi
else
  t ADD_PROMPT_TGID "$(channel_spec "$CH" id_label)"   # 라벨 동적 주입 (FR-005)
  read -r TGID
fi
# 숫자 검증은 TGID 비어있지 않을 때만 (discord --id 미제공 시 건너뜀)
[ -n "$TGID" ] && { printf '%s' "$TGID" | grep -qE '^[0-9]+$' || die ERR_NOT_NUMERIC_ID "$TGID"; }
```

**(c) seed_policy 분기 + access.json 시드 (FR-004)**: 현행 하드코딩 heredoc(L66~68) 을 분기 + jq 구성으로 대체.

- `pending` 필드는 어떤 경로에서도 미포함 (SC-009/010/011, ASM-003 검증 완료).
- dmPolicy 결정 규칙:
  - `seed_policy=allowlist` (telegram, --id 필수보장): `dmPolicy=allowlist`, `allowFrom=["<id>"]`.
  - `seed_policy=pairing` + `--id` 미제공 (discord): `dmPolicy=pairing`, `allowFrom=[]` (SC-009).
  - `seed_policy=pairing` + `--id` 제공 (discord): `dmPolicy=allowlist`, `allowFrom=["<id>"]` (SC-010).
- `groups` 구성: `--group` 미지정 시 `{}`. 지정 시 각 토큰을 파싱하여 `{ "<snowflake>": {"requireMention":<bool>,"allowFrom":[...]}, ... }`.

```sh
# 시드 결정 (개념)
sp="$(channel_spec "$CH" seed_policy)"
if [ -n "$TGID" ]; then policy=allowlist; allowarr="[\"$TGID\"]"; else policy="$sp"; allowarr="[]"; fi
# pairing + --id 제공 시 위 if 가 allowlist 로 승격 (FR-004)
# groups_json 은 (d) 에서 구성
# jq 로 안전 구성(권장 — JSON 주입 차단):
jq -n --arg dm "$policy" --argjson af "$allowarr" --argjson gr "$groups_json" \
  '{dmPolicy:$dm, allowFrom:$af, groups:$gr}' > "$SD/access.json"
```

> jq 부재 환경의 add: 현행 add 는 access.json heredoc 으로 jq 불요였다. groups 미지정(`{}`) + 단순 allowFrom 의 경우 heredoc 직접 작성 가능하나, `--group` 지정 시 groups 객체 구성은 jq 가 안전. **설계 결정 ADR-005 참조** — groups 미지정 경로는 heredoc 유지(jq 불요 보존), `--group` 지정 시에만 jq 필요(jq 부재 시 `need_jq` 안내). 단순화를 위해 전체 jq 경유도 후보(ADR-005).

**(d) --group 토큰 파싱 (FR-008, ADR-002 컴파운드 토큰)**: 각 `--group` 토큰을 `:` 로 split.

- 형식: `<id>[:nomention][:allow=m1,m2,...]`
- `<id>` (첫 토큰): `^[0-9]+$` 검증, 비숫자 → `die ERR_ADD_BAD_GROUP_ID`(신규 키), 등록 전 abort (SC-027).
- `nomention` 수식어: `requireMention=false` (없으면 true) (SC-030).
- `allow=...` 수식어: 콤마 split, 각 멤버 `^[0-9]+$` 검증, 비숫자 → `die ERR_ADD_BAD_GROUP_MEMBER`(신규 키) (SC-032). 없으면 `allowFrom=[]`.
- 복수 `--group` → groups 에 키 누적 (SC-025, SC-026).
- **검증 시점**: 모든 group 토큰 검증을 레지스트리 등록(`>> "$REGISTRY"`)·파일 생성 **전**에 수행. 실패 시 `mkdir -p "$SD/inbox"` 로 만든 디렉터리 정리 고려(현행 add 도 후속 die 시 SD 잔존 — 기존 동작과 정합. ADR-006 참조).

**(e) 완료 메시지**: discord(pairing, --id 미제공) 경로는 `ADD_DONE_ALLOWLIST`(allowlist 시드 안내)가 부적절 → seed_policy/정책에 맞는 안내 분기 필요. (FR 명시 없으나 정확성 — ADR-004.)

### 3. `messages/en.sh` + `messages/ko.sh` — telegram 하드코딩 제거 (FR-005)

| 키 | 변경 |
|---|---|
| `ADD_PROMPT_TGID` | `"Your numeric Telegram ID (DM @userinfobot...)"` → `"Your %s: "` 형태로 `id_label` 런타임 주입. telegram/userinfobot 문자열 제거 (SC-012). |
| `STATUS_GLOBAL` | `"...%s/telegram..."` → `/telegram` 제거. `IMPLEMENTED_CHANNELS` 기반 채널 목록 표시 또는 일반화 문구 (SC-013). |
| `STATUS_HINT_NO_TOKEN` | `"...put TELEGRAM_BOT_TOKEN= ..."` → `token_key` 를 인자(%s)로 받음. `TELEGRAM_BOT_TOKEN` 하드코딩 제거 (SC-014). |
| `DOCTOR_PLUGIN_HINT` | `"the telegram plugin must be installed...telegram@claude-plugins-official"` → IMPLEMENTED_CHANNELS 기반 동적 또는 일반화 문구. telegram 특정 문자열 제거 (SC-015). |

- en/ko 키 패리티 유지(`scripts/check-i18n-keys.sh` 통과). 호출부(cmd_add/cmd_status/status BROKEN hint/cmd_doctor)에 인자 추가.
- `STATUS_GLOBAL`/`DOCTOR_PLUGIN_HINT` 동적 목록 구성: `IMPLEMENTED_CHANNELS` 를 순회하며 `channel_spec <ch> display` 또는 plugin 값을 합쳐 표시(Bash 3.2 `for` 루프).

### 4. `completions/_cctg`(zsh) + `completions/cctg.bash`(bash) — 동적화 (FR-006, FR-008)

- `--channel` 후보: `telegram` 하드코딩 → `IMPLEMENTED_CHANNELS` 변수 참조 (SC-016, SC-017). 완성 스크립트는 lib 를 source 하지 않으므로, `IMPLEMENTED_CHANNELS` 를 완성 파일에서 직접 도출하는 방법 필요 — **ADR-003**: (후보 a) 완성 파일이 설치된 cctg 바이너리/lib 경로에서 값 추출, (후보 b) 완성 파일 내 자체 기본값 + 주석. spec 은 "변수 참조 또는 동적 목록"(SC-016/017 문구) 허용 → 정적 목록 동기화(`telegram discord`)도 SC 통과 가능하나 "동적" 의도와 거리. ADR-003 에서 방향 결정.
- `add` 플래그 후보에 `--group` 추가 (SC-029). zsh `compadd`/bash `COMPREPLY` 양쪽.

### 5. `lib/commands.sh` `cmd_status` (비JSON) — 채널 + 토폴로지 (FR-007)

- 각 봇 출력에 `channel_spec "$(channel_of "$n")" display` 결과 표시 (SC-018).
- jq 있고 access.json 있을 때: `dmPolicy` + `groups` 키 수 파싱하여 `channel=Discord (pairing, 0 groups)` 형태 (SC-019).
- jq 없을 때 / access.json 없을 때: 채널 표시명만(파싱 시도 안 함, 오류 없음) — NFR-005, SC-020.
- 신규 메시지 키(예: `STATUS_CHANNEL`, `STATUS_CHANNEL_TOPO`) 추가 또는 기존 `STATUS_PATHS`/`STATUS_MODE` 라인 옆에 채널 라인 추가. en/ko 동시.

---

## 결정 기록 (ADRs)

> spec.md "요구사항 구조화 매트릭스" FR/NFR 행을 plan 결정에 매핑. Design Agent research.md "기술 선택 조사" 절과 cross-reference.

| ADR-ID | 결정 항목 | 채택안 | 대안 (검토했으나 채택 안 함) | 근거 (spec FR/NFR 참조) | 영향 범위 |
|---|---|---|---|---|---|
| ADR-001 | descriptor 8필드 저장 방식 | 기존 `channel_spec` case `"$1:$2"` 에 arm 추가 | 연관배열 맵 / 별도 필드별 함수 | FR-002, NFR-001 (Bash 3.2) | lib/channels.sh |
| ADR-002 | `--group` 세부속성 CLI 문법 (= DEC-001) | **컴파운드 토큰** `--group <id>[:nomention][:allow=m1,m2]` | 동반 플래그 `--group <id> [--nomention] [--allow ...]` | FR-008, NFR-001, NFR-004 (최소 표면·Bash3.2 파싱) | lib/commands.sh, completions, spec 권장안 | 
| ADR-003 | 완성 스크립트 `--channel` 동적화 방식 | (Design 확정) 후보: lib 값 추출 vs 정적 동기화 | — | FR-006, SC-016/017 | completions/* |
| ADR-004 | discord pairing 경로 완료 메시지 | seed_policy 별 완료 안내 분기 (allowlist 안내 오용 방지) | 기존 `ADD_DONE_ALLOWLIST` 무분기 재사용 | FR-004 (정확성) | commands.sh, messages |
| ADR-005 | access.json 시드 구성 도구 | groups 미지정=heredoc(jq 불요 보존), `--group` 지정=jq | 전체 jq 경유(단순) / 전체 heredoc(주입 위험) | FR-004, FR-008, P-003(주입 차단) | commands.sh |
| ADR-006 | group 검증 실패 시 부분 생성 정리 | 등록·파일생성 전 전체 검증 → 실패 시 abort. SD 디렉터리 잔존은 기존 add die 동작과 정합 | 실패 시 SD rollback(rm) | SC-027/032 (등록 안 됨), 기존 동작 회귀 방지 | commands.sh |

> **DEC-001 (ADR-002) 결정 체크포인트**: spec FR-008 권장안 = 컴파운드 토큰. plan.md 도 컴파운드 토큰 채택을 권고하나, **최종 확정은 main session 의 결정 체크포인트**(사용자 확인 후 `decisions.md` DEC-001 기록). 트레이드오프 요약:
>
> | 기준 | 컴파운드 토큰 `<id>:nomention:allow=...` | 동반 플래그 `--group <id> --nomention --allow ...` |
> |---|---|---|
> | Bash 3.2 파싱 | 단일 `$2` 를 `:` split — 로컬 변수만으로 완결 | "어느 --group 에 속하나" 상태추적 필요 → 연관배열 없이 복잡 |
> | 최소 표면(NFR-004) | 플래그 1개 유지 | 플래그 3개로 증가 |
> | 사용자 가독성 | 토큰이 길어지면 가독성 저하 | 플래그 분리로 명시적 |
> | spec 권장 | ○ (FR-008 권장안) | — |
>
> ADR 미작성 결정이 design 단계에 발견되면 status: BLOCKED 로 Planning 복귀.

---

## 인터페이스 계약

- **`channel_spec <channel> <field>`**: 호출자(cmd_add/cmd_status/status_json/cmd_config/up_one 등)는 기존 4필드 외 신규 4필드(`display`/`id_label`/`id_required`/`seed_policy`)를 조회 가능. 미구현 채널·미정의 필드는 return 1(기존 계약 유지) — 호출부는 `$(channel_spec ...)` 빈값 처리 방어 유지.
- **`cmd_add` 플래그 계약**: 기존 `--id/--token-env/--token-stdin/--mode/--channel` + 신규 `--group`(반복). 미지 플래그는 `ERR_ADD_UNKNOWN_FLAG` (메시지에 `--group` 추가). 하위호환: 기존 telegram add 호출(--group 없음)은 동작 불변 (SC-008, SC-011).
- **레지스트리 스키마**: 불변(`name|cwd|state_dir|channel`). 레거시 3컬럼 행 `channel_of` → telegram (NFR-003, SC-023). 방어코드(awk $4 빈값→DEFAULT_CHANNEL) 유지.
- **access.json 스키마(plugin 계약)**: cctg 는 `{dmPolicy, allowFrom, groups}` 시드. `pending` 미포함(plugin readAccessFile 가 `?? {}` 흡수 — 외부 검증 절). `groups["<id>"]={requireMention,allowFrom}` (plugin GroupPolicy 타입 일치).
- **메시지 키 패리티**: en.sh ↔ ko.sh 키 동일 유지. 신규/시그니처 변경 키는 `scripts/check-i18n-keys.sh` 참조 검증 통과 필요.

---

## 데이터 모델

access.json 시드 구조 (채널·옵션별):

| 경로 | dmPolicy | allowFrom | groups |
|---|---|---|---|
| telegram (--id 필수) | `allowlist` | `["<id>"]` | `{}` 또는 `--group` 반영 |
| discord, --id 미제공 | `pairing` | `[]` | `{}` 또는 `--group` 반영 |
| discord, --id 제공 | `allowlist` | `["<id>"]` | `{}` 또는 `--group` 반영 |

`groups` 값 (각 `--group <id>[:nomention][:allow=...]`):

```json
"<snowflake>": { "requireMention": true|false, "allowFrom": ["<member>", ...] }
```

- `pending` 키: 모든 경로에서 부재(제거).
- 기존 운영 봇 access.json 은 미변경(add 시점에만 시드 — ASM-004).

---

## 테스트 전략

> 테스트 수준: 대부분 unit(bats) / static([env:static] 파일·구조 검증). 통합(실제 Discord API)은 spec "범위 외".

| SC | 수준 | 유형 | 시나리오 요약 | 입력 | 기대 결과 |
|---|---|---|---|---|---|
| SC-001 | static | Happy | IMPLEMENTED_CHANNELS 에 discord | channels.sh 읽기 | `discord` 포함 |
| SC-002 | static | Happy | discord descriptor 활성 case | channels.sh grep | 주석 아닌 활성 case |
| SC-003 | unit | Error→Happy | add --channel discord 가 UNSUPPORTED 아님 | `add ... --channel discord --token-stdin </dev/null` | ERR_CHANNEL_UNSUPPORTED 미출력(ERR_EMPTY_TOKEN 허용) |
| SC-004 | unit | Happy | telegram 8필드 존재 | `channel_spec telegram <8필드>` | 모두 값 출력(rc 0) |
| SC-005 | unit | Happy | discord 8필드 존재 | `channel_spec discord <8필드>` | 모두 값 출력(rc 0) |
| SC-006 | unit | Happy | discord 핵심 필드값 | `channel_spec discord display/id_required/seed_policy` | `Discord`/`no`/`pairing` |
| SC-007 | unit | Edge | discord --id 없이 비대화형 진행 | `add ... --channel discord --token-stdin`(유효토큰) | ERR_ADD_NEED_ID 미발생, access.json 단계 진입 |
| SC-008 | unit | Error | telegram --id 없이 비대화형 | `add ... --channel telegram --token-stdin`(유효토큰) | ERR_ADD_NEED_ID 발생(회귀 없음) |
| SC-009 | unit | Happy | discord --id 미제공 시드 | `add ... discord --token-stdin` | dmPolicy=pairing, allowFrom=[], groups={}, pending 없음 |
| SC-010 | unit | Happy | discord --id 제공 시드 | `add ... discord --token-stdin --id 12345` | dmPolicy=allowlist, allowFrom 에 12345, pending 없음 |
| SC-011 | unit | Happy | telegram 시드 pending 제거 | `add ... telegram --token-stdin --id 12345` | dmPolicy=allowlist, allowFrom 에 12345, pending 없음 |
| SC-012 | static | Happy | ADD_PROMPT_TGID telegram 문자열 없음 | en/ko.sh 읽기 | "Telegram"/"@userinfobot" 없음 |
| SC-013 | static | Happy | STATUS_GLOBAL /telegram 없음 | en/ko.sh 읽기 | `/telegram` 없음 |
| SC-014 | static | Happy | STATUS_HINT_NO_TOKEN 하드코딩 없음 | en/ko.sh 읽기 | `TELEGRAM_BOT_TOKEN` 리터럴 없음 |
| SC-015 | static | Happy | DOCTOR_PLUGIN_HINT telegram 특정 없음 | en/ko.sh 읽기 | telegram 특정 문자열 없음 |
| SC-016 | static | Happy | zsh --channel 동적 | _cctg 읽기 | telegram 하드코딩 대신 변수/동적 |
| SC-017 | static | Happy | bash --channel 동적 | cctg.bash 읽기 | telegram 하드코딩 대신 변수/동적 |
| SC-018 | unit | Happy | status 채널 표시명 | tg봇+dc봇 등록 후 `status` | Telegram·Discord 문자열 |
| SC-019 | unit | Happy | jq 있을 때 토폴로지 | jq O, dc access.json pairing/groups{} | `pairing`+`0 groups` |
| SC-020 | unit | Edge | jq 없을 때 degradation | jq X, dc봇 등록 | 오류 없음, `Discord` 표시 |
| SC-021 | static | Happy | bash --posix -n 통과 | 변경 5파일 | exit 0 |
| SC-022 | unit | Happy | DISCORD_BOT_TOKEN 저장 | `add ... discord --token-stdin`(유효토큰) | .env 에 `DISCORD_BOT_TOKEN=` |
| SC-023 | unit | Edge | 레거시 3컬럼 → telegram | projects.conf 3컬럼 행, `channel_of mybot` | `telegram` |
| SC-024 | unit | Happy(회귀) | 기존 88 테스트 통과 | `bats tests/` | 88개 통과 |
| SC-025 | unit | Happy | --group 1회 groups 키 | `add ... --group 846209781206941736` | groups["846..."]={requireMention:true,allowFrom:[]} |
| SC-026 | unit | Happy | --group 2회 두 키 | `--group A --group B` | groups 에 A·B |
| SC-027 | unit | Error | 비숫자 group id | `--group abc` | 에러+비0 exit, mybot 미등록 |
| SC-028 | unit | (갈음) | --group 미지정 groups{} | SC-009/010 으로 갈음 | groups={} |
| SC-029 | static | Happy | 완성에 --group | _cctg/cctg.bash 읽기 | `--group` 포함 |
| SC-030 | unit | Edge | nomention 수식어 | `--group 846...:nomention` | requireMention=false |
| SC-031 | unit | Happy | allow 수식어 | `--group 846...:allow=184...,221...` | allowFrom 에 둘 |
| SC-032 | unit | Error | allow 비숫자 멤버 | `--group 846...:allow=abc` | 에러+비0 exit, mybot 미등록 |

**SC별 Happy/Edge/Error 커버리지 점검**:
- Happy Path: SC-001/002/004/005/006/009/010/011/012~022/024/025/026/029/031 (핵심 정상 흐름).
- Edge Case: SC-007(discord --id 선택 경계), SC-020(jq 부재 degradation), SC-023(레거시 컬럼 경계), SC-030(수식어 경계값 false).
- Error Case: SC-003(UNSUPPORTED — 비활성→해소 검증), SC-008(telegram --id 누락 에러), SC-027(group id 비숫자), SC-032(멤버 id 비숫자).
- 세 유형 모두 본 spec 전반에 분포 — 테스트 전략 완성. Test Agent 는 coverage.md 에 SC 단위 유형 충족 기록.

**(PROC-010) 통합 테스트 defer — 옵션 C 채택 + 자가 점검**:
- spec "범위 외": 통합 테스트(실제 Discord API 연결)는 실제 봇 토큰·서버 필요로 본 파이프라인 범위 밖. 본 spec 은 **옵션 C(단위+정적 검증만으로 마감)** 채택.
- 1. **운영 환경 의존성 평가**: 결함 발견이 운영 환경에 의존하는가? — 부분 Y. cctg 책임 범위(시드 JSON 생성·CLI 분기)는 전부 unit/static 으로 검증 가능(N). 단 시드된 access.json 이 실제 discord 플러그인 런타임에서 의도대로 해석되는지(페어링 발급·멘션 트리거)는 실제 API 의존(Y) — 그러나 이는 **플러그인 소유 영역**(spec 범위 외 명시).
- 2. **mock 시뮬레이션 불가 시나리오**: DM 첫 메시지 페어링 코드 반환, `/discord:access pair` 승인 후 DM 응답, 서버채널 @멘션 트리거 — 모두 실제 Discord Gateway 연결 필요로 bats mock 불가. cctg 측 책임(시드 구조)은 venv 소스 정적 검증(외부 라이브러리 동작 검증 절)으로 갈음.
- 3. **권장 옵션 재검토**: 위 1·2 의 Y 항목이 모두 **플러그인 소유 영역**(cctg 책임 경계 밖)이므로 옵션 C 유지 정당. cctg 책임 범위는 unit/static 100% 커버. 운영 보완: spec "사후 운영 검증 피드백 사이클"(아래 PROC-014)로 사용자 실제 검증.

**(PROC-014) 사후 운영 검증 피드백 사이클**: spec.md "범위 외 > 사후 운영 검증 피드백 사이클"에 이미 명시됨 —
1. 파이프라인 완료 후 사용자 점검 시나리오: DM 첫 메시지(페어링 코드 확인), `/discord:access pair <code>` 승인 후 DM 응답, 서버채널 `/discord:access group add` 후 @멘션 응답, `cctg status` 토폴로지 표시 확인.
2. 결함 발견 시: spec.md "배경 및 목적" 추가 → main "spec 수정" → 1단계 재진입 또는 patch spec.

### smoke_tests (선택)

- 필요 여부: N
- 근거: 변경이 SC-001~032 로 직접 커버되며, 기존 88개 bats 회귀(SC-024)가 SC 범위 밖 경로(up/down/logs/rename/config/common/lang)의 회귀를 포착한다. 별도 smoke 경로 불요.

---

## 기타 고려사항

- **i18n 키 패리티**: 신규/변경 메시지 키는 en.sh·ko.sh 동시 변경 + `scripts/check-i18n-keys.sh` 통과(미통과 시 CI lint 실패). FR-005 호출부 인자 추가 시 양 카탈로그 시그니처 일치 확인.
- **신규 에러 키**: `ERR_ADD_BAD_GROUP_ID`(group id 비숫자), `ERR_ADD_BAD_GROUP_MEMBER`(allow 멤버 비숫자) 추가 예상 — en/ko 동시. `ERR_ADD_UNKNOWN_FLAG` 메시지에 `--group` 추가.
- **JSON 주입 방어(P-003 정합)**: group id·멤버 id 는 `^[0-9]+$` 검증 통과분만 JSON 에 주입(현 TGID 패턴과 동일). 토큰은 .env 만(argv·JSON 미노출).
- **jq 의존 경계**: status 토폴로지(FR-007)·`--group` 시드(ADR-005)는 jq 의존. jq 부재 시 status 는 graceful degradation(NFR-005, SC-020), `--group` add 는 `need_jq` 안내 후 exit(기존 common 패턴과 정합). groups 미지정 add 는 jq 불요 유지.
- **id_label 언어**: descriptor 메타로 영문 고정(런타임 언어 무관). 한국어 라벨 분리는 spec 범위 외 — 필요 시 후속 spec.
- **PATCH-A06 안전망(운영 미검증 가정)**: ASM-001(플러그인 설치)·ASM-002(토큰 발급)는 "사용자 확인 필요"이나 cctg add 시점에는 불요(런타임 의존). add 는 플러그인 부재여도 등록 성공(up 시 claude --channels 실패로 표면화) — 이는 telegram 과 동일 기존 동작. 안전망: doctor 의 `DOCTOR_PLUGIN_HINT`(FR-005 동적화)가 설치 안내, status BROKEN 이 토큰 부재 표면화. 신규 안전망 설계 불요(기존 메커니즘이 흡수).
