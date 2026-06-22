# Decisions — v0.7.0/001-channel-reply-hook

> SPEC_ROOT: docs/specs/v0.7.0/001-channel-reply-hook · 작성: 2026-06-22

append-only 결정 로그. 비자명 결정만 기록한다.

## DEC-001 — 기본 ON (옵트인 doctrine override)

- **결정**: reply 리마인더 훅을 **기본 활성(ON)** 으로 시드하고, 사용자가 끄는 **opt-out** 으로 제공한다.
- **맥락**: 전역 doctrine(`feature-optionality-and-os-portability.md §1`)은 상주·부작용 기능을 기본 OFF 옵트인으로 권한다.
- **근거(override)**: cctg는 chat gateway이며 "채널로 답한다"는 곁다리 부작용이 아니라 **제품 본질**이다. 봇이 채널 메시지에 답하지 않으면 무용하다. 따라서 기본 ON이 정당. 부작용은 cctg 봇 세션에 한정되고(아래 DEC-004), opt-out 경로를 제공한다. 사용자 명시 확인(Discord 2026-06-22: "기본으로 추가하고, 사용자가 편집할 수 있게 가이드를 추가한다").

## DEC-002 — 메커니즘: `--append-system-prompt` (UserPromptSubmit 훅 기각)

- **결정**: 봇 기동 시 `claude --channels ... --append-system-prompt "$(cat <리마인더 파일>)"` 로 reply 지시를 주입한다. UserPromptSubmit 훅 방식은 **기각**.
- **기각 사유(안전)**: `--settings` 의 `hooks` 키가 사용자 전역 `~/.claude/settings.json` hooks 와 병합되는지 대체되는지 **공식 문서 미명시**(조사 결론: replace 가능성 높음). replace 라면 cctg-shared.settings.json 에 `hooks` 를 추가하는 순간 모든 cctg 봇 세션에서 사용자 전역 **git-guard PreToolUse 훅**이 무력화됨 — 봇은 `bypassPermissions` 로 돌기 때문에 심각한 안전 회귀. `--append-system-prompt` 는 `hooks` 키를 건드리지 않아 이 리스크가 없다.
- **부수 이점**: 공식 문서가 정적 불변 지시에는 append-system-prompt 가 "더 단순·신뢰적"이라 평가(JSON 파싱 실패 경로 없음·compaction 생존).
- **사용자 결정**: Discord 2026-06-22 — (A) append-system-prompt 전환 채택.

## DEC-003 — 리마인더 본문: 편집 가능한 텍스트 파일

- **결정**: 리마인더 텍스트는 cctg 시드 파일 `$CHANNELS_DIR/cctg-reply-reminder.txt` (평문). 봇 기동 시 그 내용을 `--append-system-prompt` 인자로 전달.
- **근거**: 평문 파일이라 이스케이프 없이 편집 가능(편집성 요구 충족). cctg-shared.settings.json 과 co-located 관리 파일 1개 추가 — 일관적.
- **런타임 전달**: launch 문자열에서 `set -- --append-system-prompt "$(cat <file>)"; ... caffeinate -is claude ... "$@" ...` — 다단어·개행 내용을 단일 argv 로 안전 전달(Bash 3.2 호환). 파일 경로는 cctg 가 `printf '%q'` 로 임베드.

## DEC-004 — 적용 범위: cctg 봇 세션 한정

- **결정**: 리마인더는 cctg 봇 기동 launch 에서만 주입. 사용자의 일반 `claude` 사용에는 영향 없음.
- **근거**: 부작용을 봇 컨텍스트로 격리. P-002(사용자 상태 비침해) 정합.

## DEC-005 — 기본 ON 시딩 + opt-out (마커 불필요)

- **결정**: seed-if-absent 모델.
  - 파일 부재 → 기본 리마인더 텍스트 작성(시드). `ensure_reply_reminder` 가 `up`/`add` 진입에서 수행.
  - **opt-out = 파일을 비운다**(`: > file`). 파일 존재(크기 0) → 주입 안 함(`[ -s ]` false). 존재하므로 재시드 안 됨.
  - **편집** = 텍스트 수정 → 존재하므로 덮어쓰지 않음(보존).
  - 파일을 **삭제**하면 다음 기동에 재시드됨(문서: "끄려면 삭제 말고 비워라").
- **마커·새 서브커맨드 없음**(P-005 최소 표면). install.sh 미변경 — 설치/업데이트 후 다음 `up`/`add` 가 시드.

## DEC-006 — 사용자 인지(awareness)

- **결정**: (1) README 섹션, (2) `cctg add` 완료 시 1줄 안내(리마인더 ON·경로·끄는 법), (3) `cctg doctor` 에 reply-reminder 상태 줄(ON/OFF + 경로). 사용자 요구(Discord 2026-06-22: "README와 add 등의 상황에서 안내문구 추가").
