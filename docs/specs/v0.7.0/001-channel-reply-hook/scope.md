# Scope — v0.7.0/001-channel-reply-hook

> SPEC_ROOT: docs/specs/v0.7.0/001-channel-reply-hook · 작성: 2026-06-22
> 의도적 스코프 컷(no-silent-caps). 침묵 처리하지 않고 명시한다.

## CUT-001 — opt-out 을 `config` 서브커맨드가 아닌 "파일 비우기"로 구현

- **원 요청**: "기본 ON + config opt-out".
- **컷/대체**: 새 `cctg config`/`common` 서브커맨드를 추가하지 않고, opt-out 을 **리마인더 파일을 비우는 것**(`: > ~/.claude/channels/cctg-reply-reminder.txt`)으로 제공한다.
- **근거**: constitution P-005(최소 명령 표면). 사용자 최종 지시가 "기본 추가 + 편집 가이드"로 바뀌어 명령형 토글의 필요가 약화. 파일 편집/비우기로 편집·opt-out 이 모두 충족되고, `doctor`·README·`add` 안내로 발견성을 확보.
- **재검토 트리거**: 사용자가 토글 명령(`cctg common reply on|off`)을 명시 요청하면 추가(추가 시 1줄 액션 + 메시지 키 2개로 경량 구현 가능).

## CUT-002 — 봇별(per-bot) opt-out 미제공 (전역 단일 파일)

- **컷**: 리마인더는 전역 단일 파일로 전 봇 공통. 봇별 on/off·문구 차등은 제공하지 않는다.
- **근거**: "모든 봇" 적용이 요청 취지. 봇별 차등은 현재 수요 없음. 필요 시 `launch.env` 의 봇별 노브(`CCTG_REPLY_REMINDER=off` 등)로 확장 가능(옵션 존재 = 확장성).
- **재검토 트리거**: 봇별 차등 요구 발생 시.
