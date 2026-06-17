---
작성: Retrospective Agent
버전: v1.0
최종 수정: 2026-06-17 18:14
상태: 적용 완료 (2026-06-17, main session — PATCH-CXT-001~005 context.md/infra.md 반영, docs-change-logs/2026-06-17-001.md)
---

# context.md / infra.md 갱신 패치 후보

> [MUST NOT] Retrospective Agent 는 context.md / infra.md 를 직접 수정하지 않는다.
> 아래는 **후보 패치**이며, main session 이 사용자 승인 후 적용한다.
> 적용 시 `{project}/.claude/docs-change-logs/YYYY-MM-DD-NNN.md` 변경 로그 동반.
> 각 PATCH 의 "코드 검증"(PROC-002): grep/Read 로 확인한 코드 위치 + 일치 여부.

## 목차

- [PATCH-CXT-001 ~ 004 — context.md (GAP-003)](#context-md-갱신-gap-003)
- [PATCH-CXT-005 — infra.md (GAP-004)](#infra-md-갱신-gap-004)
- [버전 필드 주의 (VERSION SoT)](#버전-필드-주의-version-sot)

---

## context.md 갱신 (GAP-003)

대상 파일: `/Users/sgeon_pro/Documents/Study/cctg/cctg/.claude/docs/context.md`

### PATCH-CXT-001: §1 프로젝트 개요 — telegram 한정 → telegram+discord, 현재 버전

- 대상 섹션: §1 프로젝트 개요
- 변경 내용:
  - "프로젝트별 Claude Code **Telegram** 채널 봇" → "프로젝트별 Claude Code **채널 봇(Telegram/Discord)**"
  - "현재 버전: v0.2.0" → "현재 버전: v0.3.0" (현재 상태 스냅샷 단일 필드 — 이력 아님, 허용)
  - 기술 스택 "Telegram 채널 플러그인" → "채널 플러그인(Telegram/Discord — `claude --channels plugin:<ch>@claude-plugins-official`)"
- 변경 근거: GAP-003 / spec FR-001(discord 활성화), 5b test-report 119 PASS.
- 코드 검증: `lib/channels.sh` L11 `IMPLEMENTED_CHANNELS="telegram discord"` 확인(grep). `VERSION` 파일 = `0.3.0` 확인(Read) — context "현재 버전" 은 릴리스된 v0.3.0 으로 갱신(v0.4.0 은 미릴리스 — VERSION push 시 서버측 태깅, 아래 §버전 필드 주의 참조). 일치.

### PATCH-CXT-002: §3.4 외부 시스템 연동 — telegram 하드코딩 서술 일반화

- 대상 섹션: §3.4 외부 시스템 연동
- 변경 내용:
  - "Claude Code CLI: `claude --channels plugin:telegram@claude-plugins-official ...`" → 채널별(plugin:telegram / plugin:discord) 으로 일반화. "플러그인 ID 는 `channel_spec <ch> plugin` 으로 descriptor 조회" 명시.
  - "Telegram 채널 플러그인: 상태 디렉터리(`TELEGRAM_STATE_DIR`)..." → "채널 플러그인: 상태 디렉터리(`<CH>_STATE_DIR` — telegram=`TELEGRAM_STATE_DIR`, discord=`DISCORD_STATE_DIR`)에서 `.env`(토큰)·`access.json`(allowlist/pairing) 사용".
- 변경 근거: GAP-003 / spec FR-001/FR-004(discord seed pairing), descriptor SSOT화.
- 코드 검증: `lib/channels.sh` L19 `telegram:statedir_env → TELEGRAM_STATE_DIR`, L27 `discord:statedir_env → DISCORD_STATE_DIR`, L33 `discord:seed_policy → pairing` 확인(grep). 일치.

### PATCH-CXT-003: §5 도메인 용어 — channel descriptor 4필드 → 8필드

- 대상 섹션: §5 도메인 용어 사전, `channel descriptor` 행
- 변경 내용: "채널별 속성(plugin/statedir_env/token_key/...) 조회" → "채널별 속성 8필드(plugin/statedir_env/token_key/token_required + display/id_label/id_required/seed_policy) 조회 — `channel_spec`". (사용 금지 동의어 열 불변.)
- 변경 근거: GAP-003 / spec FR-002(4→8필드 확장).
- 코드 검증: `lib/channels.sh` L14~15 주석 `field: plugin|statedir_env|token_key|token_required | display|id_label|id_required|seed_policy`, L18~25 telegram 8필드, L26~33 discord 8필드 모두 활성 확인(grep). 일치.

### PATCH-CXT-004: §6 알려진 제약 — "구현 채널 telegram 한정" 행 정정 + 신규 제약 2건

- 대상 섹션: §6 알려진 제약 및 기술 부채 (표 행 정정 — 이력 행 추가 아님; PROC-003/PROC-R02 정합)
- 변경 내용:
  - "구현 채널 telegram 한정" 행 → "구현 채널 telegram + discord. imessage/fakechat 는 미구현(descriptor 케이스 추가 + `IMPLEMENTED_CHANNELS` 등재로 활성화)". (telegram 한정 서술 제거 — 더 이상 사실 아님.)
  - 신규 제약 행 추가 (현재 시점 미해소 구조 제약):
    - **완성 채널 미러 수동 동기화**: `completions/_cctg`(`CCTG_COMPLETION_CHANNELS`)·`completions/cctg.bash`(`channels=`) 는 `lib/channels.sh` 를 source 하지 않고 `IMPLEMENTED_CHANNELS` 를 로컬 리터럴로 **미러**(ADR-003). 채널 추가 시 3곳을 함께 갱신해야 함(자동 동기화 아님). | 영향: completions | 관련 spec: v0.4.0/001
    - **`--group` 파싱 Bash 3.2 제약**: 연관배열 불가로 컴파운드 토큰(`<id>[:nomention][:allow=...]`)을 스칼라 누적 + `:` split 으로 처리(DEC-001). | 영향: lib/commands.sh | 관련 spec: v0.4.0/001
- 변경 근거: GAP-003 / CHANGES.md 후속 주의사항(완성 미러·`--group` 검증), ADR-003/006, DEC-001.
- 코드 검증: `completions/_cctg` L8 `CCTG_COMPLETION_CHANNELS="telegram discord"`, `completions/cctg.bash` L12 `channels="telegram discord"`(둘 다 리터럴 미러, source 없음) 확인(grep). `lib/channels.sh` L1~11 IMPLEMENTED_CHANNELS 단일 SoT 확인. 일치.

> **§6 처리 메모(PROC-R02/PROC-003)**: 본 §6 갱신은 모두 **기존 행 정정 + 현재 미해소 구조 제약 추가**이며, 버저닝 이력/changelog 성 행 추가가 아니다. context.md 에 변경 이력 섹션은 존재하지 않으며 추가하지 않는다(변경 추적 SoT = git history + docs-change-logs/).

---

## infra.md 갱신 (GAP-004)

대상 파일: `/Users/sgeon_pro/Documents/Study/cctg/cctg/.claude/docs/infra.md`

### PATCH-CXT-005: telegram 한정 표기 일반화 (단일 게이트웨이 제약 해소 반영)

- 대상 섹션: §2 인프라 토폴로지, §5 연결 실패 재시도, §8 알려진 인프라 제약
- 변경 내용:
  - §2: "`claude --channels plugin:telegram@claude-plugins-official` 프로세스" → "`claude --channels plugin:<ch>@claude-plugins-official` 프로세스(채널별 descriptor 조회 — telegram/discord)". "외부 의존: Telegram Bot API" → "외부 의존: 채널 플러그인이 통신하는 채널 API(Telegram Bot API / Discord Gateway)".
  - §5: "Telegram API 연결·재시도는 Claude Code Telegram 플러그인 책임" → "채널 API 연결·재시도는 Claude Code 채널 플러그인(telegram/discord) 책임" (CCTG 자체 재시도 미보유 불변).
  - §8 "단일 게이트웨이 / Telegram 플러그인 하드코딩" 행 → 제약 **해소** 반영: "다중 게이트웨이(telegram/discord) 지원. 플러그인 ID 는 descriptor(`channel_spec <ch> plugin`) 경유 — 하드코딩 제거. imessage/fakechat 는 미구현." (또는 행 제거 후 context.md §6 으로 일원화).
- 변경 근거: GAP-004(PATCH-A18 cross-check) / spec FR-001. **배포 메커니즘(install.sh / .github/workflows / 매니페스트)은 본 spec 미변경**(selection-phases Deploy=N) → §1 환경구성·§3 배포 방식·§7 체크리스트는 영향 없음(변경 후보 아님).
- 코드 검증: `lib/channels.sh` L18 `telegram:plugin → plugin:telegram@claude-plugins-official`, L26 `discord:plugin → plugin:discord@claude-plugins-official` 확인(grep) — 플러그인 ID descriptor 조회 일치. install 매니페스트·workflow 미변경(DIFF 변경파일 = lib/messages/completions/tests 한정, 6단계 DIFF 근거). 일치.

> infra.md 패치 작성 원칙 준수: 현재 상태만 / 변경된 부분만 / 민감정보 0 / 환경변수 0. 배포 환경 dev·staging·prod 구분 부재(infra §1 단일 환경) — 본 spec 무관.

---

## 버전 필드 주의 (VERSION SoT)

- `VERSION` 파일 = `0.3.0`(현재 working tree). 본 spec(v0.4.0/001) 변경은 working tree 에 있으나 **VERSION bump·커밋·릴리스 미수행**(파이프라인 git 미변경 정책 — baseCommit 3480eb1).
- v0.4.0 릴리스는 `main` 에 `VERSION` 변경 push 시 `.github/workflows/release.yml` 이 **서버측 자동** 태깅·발행(infra.md §3). 따라서 context.md "현재 버전" 은 **현재 릴리스된 v0.3.0** 으로 갱신함(PATCH-CXT-001) — v0.4.0 으로 선행 표기하지 않음(미릴리스 = 사실 아님, 코드 기반 문서화 원칙).
- 사용자가 v0.4.0 을 릴리스한 **후** "현재 버전: v0.4.0" 으로 재갱신하는 것이 정확(별도 시점).
