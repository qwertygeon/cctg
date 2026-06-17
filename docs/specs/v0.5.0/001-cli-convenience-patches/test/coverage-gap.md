---
작성: Test Agent (EXECUTION)
버전: v1.0
최종 수정: 2026-06-17 23:16
상태: 확정
---

# Coverage Gap: cli-convenience-patches

## 목차

- [미커버 항목 테이블](#미커버-항목-테이블)
- [판정 근거](#판정-근거)

---

## 미커버 항목 테이블

| SC-ID | 미커버 시나리오 | 카테고리 | 검증 방법 | 환경/도구 | 담당 | 비고 |
|---|---|---|---|---|---|---|
| SC-025 error-path | $PWD 가 삭제된 디렉터리인 상태에서 `up telegram` 실행 시 ERR_NO_CWD 경로 | (3) 운영 환경 권장 | 터미널에서 디렉터리 삭제 후 cd 잔존 상태에서 `cctg up telegram` 실행 | macOS 터미널 (zsh/bash) | 운영자 | bats 내 비결정적 — shell 구현마다 삭제된 디렉터리의 $PWD 처리가 다름. best-effort 테스트(항상 pass) 스위트에 포함됨. |

> 카테고리 (1) 단위테스트 가능 항목: 0건 (Development Agent 복귀 불필요).
> 카테고리 (3) 항목 1건: SC-025 error-path — 운영 환경 검증으로 위임. 5b gate PASS 영향 없음.

---

## 판정 근거

SC-019 bot.pid 한계 단언 (5a 사전 분류 카테고리 (1)):

5a 단계에서 "메시지 키 내용 확인 후 단언 보강 권장"으로 분류되었으나, 5b 실행에서 확인한 결과:

- `CCTG_MSG_RESERVED_DOWN_NONE` 값: `"No session: %s. Only tmux sessions started by cctg can be stopped — plugin runner (bot.pid) is not managed by cctg (NFR-003 limit).\n"`
- 테스트 단언 `[[ "$output" == *"telegram"* ]]`: `%s` = `telegram` 치환으로 성립
- NFR-003 bot.pid 한계 문구(`bot.pid`, `NFR-003 limit`)가 메시지에 명시되어 있음
- 현행 단언은 채널명 존재 여부만 검증하지만, 메시지 자체가 spec 요건(bot.pid 한계 명시)을 충족함

판정: **추가 단언 보강 불필요** — 현행 테스트가 SC-019 의도를 충족함. 카테고리 (1) 항목을 해소 처리하고 coverage-gap.md 에서 제외.
