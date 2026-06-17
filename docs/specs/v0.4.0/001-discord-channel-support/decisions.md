---
작성: main session (Pipeline Orchestration)
버전: v1.0
최종 수정: 2026-06-17 15:24
상태: 활성
---

# decisions.md — discord-channel-support 결정 기록

## 목차

- [DEC-001 — `--group` CLI 문법](#dec-001----group-cli-문법)

---

## DEC-001 — `--group` CLI 문법

- **결정 일시**: 2026-06-17 15:24
- **결정자**: 사용자 (Telegram 확인) + main session 기록
- **연관**: spec FR-008, plan.md ADR-002, NFR-001(Bash 3.2)·NFR-004(최소 표면)

**결정**: **컴파운드 토큰** 방식 채택.

```
--group <채널snowflake>[:nomention][:allow=<멤버1>,<멤버2>,...]
```

- `--group 846209781206941736` → requireMention=true, allowFrom=[]
- `--group 846209781206941736:nomention` → requireMention=false
- `--group 846209781206941736:allow=184695080709324800,221773638772129792` → 지정 멤버만 트리거
- `--group ...:nomention:allow=...` → 두 수식어 조합 가능
- `--group` 반복 시 각 채널 독립 시드.

**근거**:
- Bash 3.2 파싱 용이 — 단일 `$2` 인자를 `:` split 으로 로컬 변수만으로 완결. 동반 플래그 방식은 "어느 `--group` 에 속하는가" 상태추적이 필요해 연관배열 없는 Bash 3.2 에서 복잡(NFR-001).
- 최소 표면 — 신규 플래그 1개(`--group`) 유지. 동반 플래그는 3개로 증가(NFR-004).
- spec FR-008 권장안 및 plan.md ADR-002 권고와 일치.

**대안(채택 안 함)**: 동반 플래그 `--group <id> [--nomention] [--allow m1,m2]` — 가독성은 높으나 위 근거로 기각.

**영향 범위**: lib/commands.sh(cmd_add 파싱), completions/_cctg·completions/cctg.bash(`--group` 후보), spec SC-030~032 의 Given 예시. 3단계 Design 이 본 문법으로 tasks.md 를 확정한다.
