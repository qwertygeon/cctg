---
작성: Test Agent (EXECUTION)
버전: v1.0
최종 수정: 2026-06-17 15:53
상태: 확정
---

# Coverage: discord-channel-support

## 목차

- [SC × 시나리오 커버리지](#sc--시나리오-커버리지)
- [SC 환경 태그 라우팅](#sc-환경-태그-라우팅)
- [STALE_SC 정보](#stale_sc-정보)

---

## SC × 시나리오 커버리지

> `plan.md 시나리오 전체` 컬럼: 해당 SC 가 요구하는 시나리오 유형(Happy/Edge/Error)을 1개 이상 충족 테스트로 커버하면 충족.
> 단언 위치는 test-report.md 의 SC 매핑 테이블 참조.

| SC-ID | 수용 기준 | Happy Path | Edge Case | Error Case | plan.md 시나리오 전체 | 상태 |
|---|---|---|---|---|---|---|
| SC-001 | IMPLEMENTED_CHANNELS 에 discord | 충족 | — | — | 충족 | PASS |
| SC-002 | discord descriptor 활성 | 충족 | — | — | 충족 | PASS |
| SC-003 | discord ≠ UNSUPPORTED (미구현채널은 거부) | 충족 | — | 충족 | 충족 | PASS |
| SC-004 | telegram 8필드 | 충족 | — | — | 충족 | PASS |
| SC-005 | discord 8필드 | 충족 | — | — | 충족 | PASS |
| SC-006 | discord display/id_required/seed_policy 값 | 충족 | — | — | 충족 | PASS |
| SC-007 | discord --id 없이 진행 | — | 충족 | — | 충족 | PASS |
| SC-008 | telegram --id 없이 → ERR_ADD_NEED_ID | — | — | 충족 | 충족 | PASS |
| SC-009 | discord --id 미제공 시드 pairing/[]/{}/no-pending | 충족 | — | — | 충족 | PASS |
| SC-010 | discord --id 제공 시드 allowlist/no-pending | 충족 | — | — | 충족 | PASS |
| SC-011 | telegram 시드 pending 제거 | 충족 | — | — | 충족 | PASS |
| SC-012 | ADD_PROMPT_TGID telegram 문자열 없음 | 충족 | — | — | 충족 | PASS |
| SC-013 | STATUS_GLOBAL /telegram 없음 | 충족 | — | — | 충족 | PASS |
| SC-014 | STATUS_HINT_NO_TOKEN 하드코딩 없음 | 충족 | — | — | 충족 | PASS |
| SC-015 | DOCTOR_PLUGIN_HINT telegram 특정 없음 | 충족 | — | — | 충족 | PASS |
| SC-016 | zsh --channel 동적 | 충족 | — | — | 충족 | PASS |
| SC-017 | bash --channel 동적 | 충족 | — | — | 충족 | PASS |
| SC-018 | status 채널 표시명 | 충족 | — | — | 충족 | PASS |
| SC-019 | jq 있을 때 토폴로지 | 충족 | — | — | 충족 | PASS |
| SC-020 | jq 없을 때 degradation | — | 충족 | — | 충족 | PASS |
| SC-021 | --posix -n / bash -n 통과 | 충족 | — | — | 충족 | PASS |
| SC-022 | DISCORD_BOT_TOKEN 저장 | 충족 | — | — | 충족 | PASS |
| SC-023 | 레거시 3컬럼 → telegram | — | 충족 | — | 충족 | PASS |
| SC-024 | 기존 테스트 회귀 0 | 충족(회귀) | — | — | 충족 | PASS |
| SC-025 | --group 1회 groups 키 | 충족 | — | — | 충족 | PASS |
| SC-026 | --group 2회 두 키 | 충족 | — | — | 충족 | PASS |
| SC-027 | 비숫자 group id 에러·미등록 | — | — | 충족 | 충족 | PASS |
| SC-028 | --group 미지정 groups{} | 충족(SC-009/010 갈음) | — | — | 충족 | PASS |
| SC-029 | 완성에 --group | 충족 | — | — | 충족 | PASS |
| SC-030 | nomention → requireMention false | — | 충족 | — | 충족 | PASS |
| SC-031 | allow → allowFrom 멤버 포함 | 충족 | — | — | 충족 | PASS |
| SC-032 | allow 비숫자 멤버 에러·미등록 | — | — | 충족 | 충족 | PASS |

**커버리지 요약**: SC-001~032 전수(32/32) 통과 테스트로 커버. 미커버 SC 0건. deferred SC 0건.

---

## SC 환경 태그 라우팅

spec.md 의 각 SC `[env:*]` 태그 처리 결과.

| 태그 | SC | 처리 |
|---|---|---|
| `[env:static]` | SC-001, 002, 012, 013, 014, 015, 016, 017, 021, 029 (10건) | Test Agent 직접 검증 (static.bats — grep + bash -n/--posix -n) |
| `[env:unit]` | SC-003~011, 018~020, 022~028, 030~032 (22건) | Test Agent 직접 검증 (bats add/channel/status_view) |
| `[env:integration]` | 없음 | — (실제 Discord 연결 SC 는 spec "범위 외" — deferred 아님) |

- 태그 누락 SC: 0건. spec.md SC-001~032 전수 `[env:*]` 명시됨.
- deferred → Deploy Agent 항목: 0건.

---

## STALE_SC 정보

> code-is-truth 정책(비차단 정보). 본 차수 git diff 변경 파일 한정 점검.

- 신규 테스트는 함수명에 본 차수 SC 식별자(SC-001~032)만 사용. prior-spec SC prefix 잔존: count=0.
- 출처/추적성 docstring 주석 신규 추가 없음(핵심원칙 #9·#10 준수).
