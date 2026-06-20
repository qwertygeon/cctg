# scope — v0.6.0/003-defensive-hardening

> 의도적 스코프 컷의 append-only 로그 (no-silent-caps).

## CUT-001 — doctor 플러그인 설치 탐지 · 도구 최소버전 강제 (검토분석 deferred)

- **무엇**: 검토분석에서 doctor 의 채널 플러그인 설치 여부 탐지, claude/tmux 최소버전 강제는 미반영.
- **사유**: 플러그인 설치는 안정적 탐지 수단(공식 CLI 질의)이 없고, 최소버전은 비자명한 기준선이 필요. 잘못된 탐지/임의 기준선은 오진단 위험.
- **대체**: 플러그인은 기존 `DOCTOR_PLUGIN_HINT` 안내로 갈음. 잔여는 `docs/TODO.md` "P2 — doctor 점검 심화" 에 보류 항목으로 유지.

## CUT-002 — tmux-absent 경고 테스트 결정성 강화 (검토분석 nit)

- **무엇**: `tests/misc.bats` 의 tmux-absent 경고 테스트가 호스트 PATH 의존(self-skip)이라는 nit 은 이번 차수에서 미반영.
- **사유**: 현재 테스트는 CI(러너에 tmux 미설치)에서 정상 동작하며, 결정성 강화(전용 심링크 dir)는 가치 대비 우선순위 낮음.
- **대체**: `docs/TODO.md` 테스트 커버리지 잔여로 이관(선택).
