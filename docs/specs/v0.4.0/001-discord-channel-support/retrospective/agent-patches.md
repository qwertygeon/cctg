---
작성: Retrospective Agent
버전: v1.0
최종 수정: 2026-06-17 18:14
상태: 작성중
---

# Agent Patches: discord-channel-support (v0.4.0/001)

> 본 spec 은 cctg 프로젝트 코드 변경(순수 Bash 셸)이므로 전역 Agent/rule 패치 후보는 최소다.
> context.md/infra.md 갱신 패치(PATCH-CXT)는 `context-infra-updates.md` 에 분리 작성했다(본 spec Task output 분리 요청).
> process(흐름 제어) 개선은 `process-patches.md` 에 작성했다.

## 목차

- [전역 Agent·규칙·문서 패치 후보](#전역-agent규칙문서-패치-후보)
- [spec.md 정정 권고 (프로젝트 산출물 — 후속 spec 후보)](#specmd-정정-권고-프로젝트-산출물--후속-spec-후보)

---

## 전역 Agent·규칙·문서 패치 후보

전역 문서(`~/.claude/agents/`·`rules/`·`docs/`·`skills/`) 대상 신규 패치: **없음**.

근거:
- agent-observations.md 가 생성되지 않았다(main session 이 OBS trigger a~e 해당 없음으로 판단). PATCH-A18(Docs Agent infra/context cross-check)·PROC-003(context.md 이력행 추가 금지) 등 기존 전역 패치는 본 차수에서 **정상 동작**했다(아래 분석 2 효과 측정 참조) — 신규 보강 불요.
- 본 차수에서 관찰된 결함(PPG 직렬 spawn SHOULD 위반, Design 1차 spawn 모델 unavailable)은 전역 Agent **정의**가 아닌 **흐름 제어(main session) 실행** 차원의 문제이므로 process-patches.md 로 라우팅한다(아래 패치 대상 적합성 게이트 결과 참조).

### 패치 대상 적합성 검토 (오염 방지 게이트 — 기각 후보 기록)

본 차수에서 전역 등재를 검토했으나 게이트 미통과로 **재배치**한 후보:

| 후보 내용 | 1차 검토 대상 | 적합성 판정 | 재배치 |
|---|---|---|---|
| "PPG 를 동일 turn 2-spawn 으로 강제" 보강 | `~/.claude/agents/` Agent 정의 | 범용 O / 역할정합 **X** — 이미 `agent-rules.md §0 PPG 운용규칙 1` 에 명문화됨(정의 미흡 아님, 실행 누락) | 재배치: 전역패치→process-patches.md PROC-001 (main session 실행 체크리스트) |
| "Phase Agent spawn 모델 unavailable 시 fallback 절차" | `~/.claude/docs/pipeline-recovery.md` | 범용 O / 역할정합 **△** — 0-token 실패는 cctg 환경 특정(fable-5 모델 미가용)일 수 있어 범용 단정 보류 | 재배치: process-patches.md PROC-002 (관찰 1회 — 보수적, 전역 승격 보류) |

---

## spec.md 정정 권고 (프로젝트 산출물 — 후속 spec 후보)

> spec.md 는 1단계 Spec Agent 산출물이며 전역 패치 대상이 아니다. 본 절은 GAP-002 후속·GAP-005 의 처리 방향만 기록한다(Retrospective 는 spec.md 를 직접 수정하지 않음 — 책임 경계).

### REC-001: SC-021 Given 절 문구 정정 (GAP-002 후속 — 비차단)

- 대상: `SPEC_ROOT/spec/spec.md` SC-021 Given
- 현재: `bash --norc --noprofile --posix -n <파일>` 대상에 `lib/commands.sh` 포함.
- 문제: `commands.sh` 는 사전 존재 process substitution(`done < <(...)`)으로 `--posix -n` 이 syntax error(GAP-002 코드 확정). 실제 검증은 static.bats 가 분리(`--posix -n` 4파일 + `commands.sh` 는 `bash -n`)했고 양 테스트 PASS.
- 처리 방향: spec 문구를 "channels.sh/en.sh/ko.sh/cctg.bash 는 `--posix -n`, commands.sh 는 `bash -n`(non-posix; process substitution 사용)" 으로 정정. **본 spec 은 확정(상태:확정) 상태이므로 소급 수정보다 후속 patch spec 또는 사용자 승인 하 1단계 재호출로 처리** 권고. 코드·테스트는 이미 정합(정정은 문서 일치성 목적, 게이트 영향 0).

### REC-002: `CCTG_MSG_USAGE` 에 `--channel`/`--group` 노출 (GAP-005 — 비차단, 후속 spec)

- 대상: `messages/en.sh`/`messages/ko.sh` `CCTG_MSG_USAGE`
- 현재: `cctg help` add 줄이 `--channel`(v0.3.0)·`--group`(본 spec) 미노출. 자동완성에는 둘 다 후보 포함 → 비대칭.
- 문제: 본 spec FR/NFR 에 USAGE 문자열 갱신 요구가 없어 SCOPE 보존을 위해 미변경(GAP-005). README synopsis 도 코드 USAGE 와 일치 유지(임의 추가 안 함).
- 처리 방향: **후속 spec 후보로 제안.** "USAGE 문자열에 `--channel`/`--group` 반영 + README synopsis 동기화" 를 묶은 소형 spec. 본 spec 에서는 변경하지 않음(처리 완료 — SCOPE 보존 결정 정당).
