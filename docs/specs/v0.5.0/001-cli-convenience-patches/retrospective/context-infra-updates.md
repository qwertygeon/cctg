---
작성: Retrospective Agent
버전: v1.0
최종 수정: 2026-06-18 07:14
상태: 적용 완료 (2026-06-18, main session) — CXT-001(§5)·CXT-002(§6) 적용. CXT-003(§1)은 사용자 결정으로 변형 적용: 버전 하드코딩 대신 VERSION 파일(SoT) 참조로 변경. 변경로그: {project}/.claude/docs-change-logs/2026-06-18-001.md
---

# context.md / infra.md 갱신 패치 후보

> [MUST NOT] Retrospective Agent 는 context.md / infra.md 를 직접 수정하지 않는다.
> 아래는 **후보 패치**이며, main session 이 사용자 승인 후 적용한다.
> 적용 시 `{project}/.claude/docs-change-logs/YYYY-MM-DD-NNN.md` 변경 로그 동반.
> 각 PATCH 의 "코드 검증"(PROC-002): grep/Read 로 확인한 코드 위치 + 일치 여부.

## 목차

- [context.md 갱신 (GAP-001)](#contextmd-갱신-gap-001)
  - [PATCH-CXT-001 — §5 예약 이름 런타임 동사 허용](#patch-cxt-001--5-예약-이름-런타임-동사-허용)
  - [PATCH-CXT-002 — §6 DEC-001 전역봇 cwd=$PWD 제약](#patch-cxt-002--6-dec-001-전역봇-cwdpwd-제약)
  - [PATCH-CXT-003 — §1 현재 버전](#patch-cxt-003--1-현재-버전)
- [infra.md 갱신](#inframd-갱신)

---

## context.md 갱신 (GAP-001)

대상 파일: `/Users/sgeon_pro/Documents/Study/cctg/cctg/.claude/docs/context.md`

### PATCH-CXT-001 — §5 예약 이름 런타임 동사 허용

- **대상 파일**: `{project}/.claude/docs/context.md`
- **대상 섹션**: §5 도메인 용어 사전 (Glossary) — `reserved name (예약 이름)` 행 (현재 97행)
- **변경 내용**: 해당 행의 정의를 런타임 동사 허용/거부 구분을 반영하도록 갱신.

  현재 (97행):
  ```
  | reserved name (예약 이름) | 전역 채널 봇 이름(telegram/discord/imessage/fakechat) — 봇 이름으로 거부 | |
  ```

  변경 후:
  ```
  | reserved name (예약 이름) | 전역 채널 봇 이름(telegram/discord/imessage/fakechat). 레지스트리 동사(add/rm/rename)는 ERR_RESERVED 로 거부하나, 런타임 동사(up/down/restart/status/logs)는 전역 봇 디렉터리(`~/.claude/channels/<ch>/`)를 상태 디렉터리로 사용하여 허용(v0.5.0/001) | |
  ```
- **변경 근거**: GAP-001(Docs Agent 등록). v0.5.0/001 그룹 C 구현으로 telegram/discord 에 대해 up/down/restart/status/logs 가 레지스트리 없는 전용 경로로 라우팅됨. CHANGES.md 후속 주의사항.
- **코드 검증** (PROC-002):
  - `lib/commands.sh:369` — `if is_reserved_name "$TARGET"; then up_reserved "$TARGET"; return; fi` (cmd_up 예약어 라우팅)
  - `lib/commands.sh:379` — `down_reserved "$TARGET"` (cmd_down)
  - `lib/commands.sh:389` — `down_reserved ...; up_reserved ...` (cmd_restart)
  - `lib/commands.sh:449-452` — `for ch in $RESERVED_NAMES; do ... STATUS_RESERVED_HEADER` (cmd_status 예약어 섹션)
  - `lib/commands.sh:30` — `is_reserved_name "$NAME" && die ERR_RESERVED` (cmd_add 거부 유지), `:204` (cmd_rename 거부 유지)
  - **일치 여부**: 일치 — add/rm/rename 거부 + up/down/restart/status/logs 허용 사실이 코드와 정합.

### PATCH-CXT-002 — §6 DEC-001 전역봇 cwd=$PWD 제약

- **대상 파일**: `{project}/.claude/docs/context.md`
- **대상 섹션**: §6 알려진 제약 및 기술 부채 — 테이블에 신규 행 추가 (현재 105~110행 테이블)
- **변경 내용**: §6 테이블에 다음 행을 추가(`구현 채널` 행 아래 권장).
  ```
  | 전역 봇 cwd = $PWD | 예약어 전역 봇(telegram/discord) 런타임 기동/상태표시의 cwd 는 레지스트리에 없으므로 cctg 호출 시점 현재 작업 디렉터리(`$PWD`)를 사용(DEC-001). 프로젝트 봇은 레지스트리 2번 컬럼 cwd 사용 — 전역 봇만 $PWD. $PWD 가 삭제된 디렉터리이면 ERR_NO_CWD 로 기동 거부(up_one 동형 가드) | `lib/session.sh`·`lib/commands.sh` | v0.5.0/001 |
  ```
- **변경 근거**: GAP-001 + DEC-001(decisions.md). 전역 봇과 프로젝트 봇의 cwd 결정 방식 차이는 현재상태 묘사에 필요한 구조적 사실.
- **코드 검증** (PROC-002):
  - `lib/session.sh:137` — `cwd="$PWD"` + 주석 `# DEC-001: cctg 호출 시점 현재 작업 디렉터리` (up_reserved)
  - `lib/session.sh:138` — `[ -d "$cwd" ] || { te ERR_NO_CWD "$cwd"; return 1; }` (up_one:67 동형 $PWD 부재 가드)
  - `lib/commands.sh:453` — `cwd="$PWD"   # DEC-001: 상태 표시용 — 전역 봇은 레지스트리에 cwd 없음` (cmd_status)
  - **일치 여부**: 일치 — cwd=$PWD(DEC-001) + ERR_NO_CWD 가드가 코드 주석까지 정합.

### PATCH-CXT-003 — §1 현재 버전

- **대상 파일**: `{project}/.claude/docs/context.md`
- **대상 섹션**: §1 프로젝트 개요 — `현재 버전` 단일 필드 (현재 18행)
- **변경 내용**:
  - 현재: `- **현재 버전**: v0.3.0`
  - 변경 후: `- **현재 버전**: v0.5.0`
- **변경 근거**: 본 spec 이 v0.5.0. context.md §1 의 "현재 버전" 은 단일 상태 스냅샷 필드(이력표 아님)이므로 갱신 허용(PROC-R02 — 이력 행 추가 금지에 비해촉). 단, **VERSION SoT 와 정합 필요** — 아래 주의 참조.
- **VERSION SoT 주의**: context.md §1 "현재 버전" 은 `VERSION` 파일(버전 단일 소스)을 반영하는 스냅샷이다. v0.5.0 태그/Release 는 `main` 에 `VERSION` 변경 push 시 CI(`release.yml`)가 자동 발행한다(infra.md §3). context.md §1 갱신은 `VERSION` 이 실제 v0.5.0 으로 bump 된 시점(또는 그와 동기)에 적용해야 SoT 와 어긋나지 않는다. **현재 `VERSION` 파일 값이 아직 v0.5.0 이 아니면 본 PATCH-CXT-003 적용을 VERSION bump 이후로 보류**한다(코드 검증 — main session 이 적용 직전 `cat VERSION` 확인).
- **코드 검증** (PROC-002): VERSION 파일 값은 적용 시점 가변이므로 main session 적용 직전 `cat /Users/sgeon_pro/Documents/Study/cctg/cctg/VERSION` 으로 직접 확인 후 일치 시에만 적용. (Retrospective 시점 단정 보류 — status: 검토중 — VERSION bump 시점 의존)

> **PROC-R02 자가 점검**: 위 3개 PATCH 모두 context.md 의 **정의된 섹션**(§5 Glossary 행 / §6 제약 테이블 행 / §1 현재버전 단일필드)만 갱신하며, 버저닝 이력/changelog 성 섹션에 신규 spec 행을 추가하지 않는다. context.md 에 버저닝 이력표 레거시 섹션은 부재(제거 패치 불요). §6 제약 테이블의 `관련 spec` 컬럼은 changelog 가 아니라 제약별 출처 표기이므로 행 추가 허용.

---

## infra.md 갱신

대상 파일: `/Users/sgeon_pro/Documents/Study/cctg/cctg/.claude/docs/infra.md`

**갱신 불요**.

근거:
- 본 spec 은 배포 방식·컨테이너 구성·CI/CD·인프라 토폴로지를 변경하지 않는다(코드 변경 spec — selection-phases Deploy=N).
- 예약어 런타임(up/down)도 기존 tmux 세션 토폴로지(`cctg-<name>`)를 그대로 사용한다(infra.md §2 이미 기재). 전역 봇 세션 `cctg-telegram`/`cctg-discord` 도 동일 `cctg-<name>` 규칙의 인스턴스이므로 §2 의 기존 서술이 이미 포괄.
- GAP-001 도 context.md 갱신만 요구(infra.md 갱신 필요 항목 0건).
- Deploy Agent `[infra.md 갱신 필요]` 기록 없음(Deploy 비활성).
</content>
