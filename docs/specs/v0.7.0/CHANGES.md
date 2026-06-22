# CHANGES — v0.7.0

> 버전 폴더 누적 변경 요약. 차수별로 `## [{NNN-spec-name}] 구현 완료` 섹션을 append 한다.

## [001-channel-reply-hook] 구현 완료

> 작성: 2026-06-22 · 모드: direct(경량) · 상태: 구현·검증 완료

### 무엇을 / 왜

cctg 봇이 채널 메시지에 **반드시 채널 reply 도구로(quote-reply 포함)** 답하도록, 모든 봇 기동 시
짧은 reply 리마인더를 `claude --append-system-prompt` 로 주입한다. 봇의 터미널/전사 출력은
사용자에게 전달되지 않으므로, 리마인더가 없으면 봇이 "혼잣말"만 하고 답장을 안 보내는 일이 생긴다.
**기본 ON**, 사용자 편집 가능, opt-out 제공.

### 어떻게 (메커니즘)

- 리마인더 텍스트: 평문 파일 `~/.claude/channels/cctg-reply-reminder.txt` (env `CC_TG_REPLY_REMINDER_FILE`).
  `ensure_reply_reminder()` 가 **부재 시에만** 기본 문구로 시드(편집 보존). `add`/`up` 진입에서 호출.
- 주입: `up_one`/`up_reserved` launch 에서 `{ [ -s <file> ] && set -- --append-system-prompt "$(cat <file>)" || set --; }`
  후 `caffeinate -is claude ... "$@" ...`. 다단어·개행 텍스트를 단일 argv 로 안전 전달(Bash 3.2 호환).
- opt-out = 파일을 **비움**(`: > file`): 존재(크기 0) → 주입 skip, 재시드 안 됨. 삭제 시 다음 기동에 재시드.
- 적용 범위: cctg 봇 세션 한정(`--settings` 가 아닌 launch 인자). 사용자 일반 `claude` 사용 불변.
- 인지(awareness): `cctg add` 완료 시 ON 안내 1줄, `cctg doctor` 에 ON/OFF 상태 줄, README(en/ko) 콜아웃.

### 메커니즘 선택 근거 (DEC-002)

UserPromptSubmit 훅(`cctg-shared.settings.json` 의 `hooks`)을 **기각**. Claude Code 가 `--settings` 의
`hooks` 키를 사용자 전역 `~/.claude/settings.json` hooks 와 병합하는지 대체하는지 **문서 미명시**(조사:
replace 가능성 높음). replace 라면 모든 봇 세션(`bypassPermissions`)에서 사용자 전역 git-guard PreToolUse
훅이 무력화되는 안전 회귀. `--append-system-prompt` 는 hooks 를 건드리지 않아 위험이 없고, 공식 문서도
정적 불변 지시에는 더 단순·신뢰적이라 평가. 상세: `001-channel-reply-hook/decisions.md`.

### 변경 파일

- `lib/env.sh` — `REPLY_REMINDER_FILE` 추가.
- `lib/util.sh` — `ensure_reply_reminder()` 추가.
- `lib/session.sh` — `up_one`/`up_reserved` 에 시드 + launch 주입.
- `lib/commands.sh` — `cmd_add` 시드+안내, `cmd_doctor` 상태 줄.
- `messages/{en,ko}.sh` — REPLY_REMINDER_SEEDED / ADD_DONE_REPLY_REMINDER / DOCTOR_REPLY_REMINDER_ON·OFF (키 패리티).
- `docs/configuration{,.ko}.md`, `README{,.ko}.md`, `CHANGELOG.md` — 문서.
- `tests/reply_reminder.bats` — 신규 8 테스트.

### 검증 결과

- `bats tests/` : **250/250 PASS, 0 FAIL** (신규 8 포함).
- `bash scripts/check-i18n-keys.sh` : 키 패리티 OK (198 키).
- `shellcheck -S warning cc-tg.sh install.sh uninstall.sh scripts/*.sh` (CI 동일) : EXIT 0.
- launch 주입 메커니즘 독립 검증: non-empty → `--append-system-prompt` + 단일 argv, empty → 미주입.

### 주의사항 (다음 작업자용)

- VERSION 파일은 0.6.0 유지 — 릴리스 준비(VERSION→0.7.0)는 별도 단계(`docs/RELEASING.md`).
- 기존 설치 업데이트 시 reminder 는 install.sh 가 아니라 **다음 `up`/`add`** 에서 시드된다.
