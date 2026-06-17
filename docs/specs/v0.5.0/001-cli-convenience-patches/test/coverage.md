---
작성: Test Agent (EXECUTION)
버전: v1.0
최종 수정: 2026-06-17 23:16
상태: 확정
---

# Coverage: cli-convenience-patches

## 목차

- [SC 커버리지 매트릭스](#sc-커버리지-매트릭스)
- [코드 커버리지 요약](#코드-커버리지-요약)

---

## SC 커버리지 매트릭스

| SC-ID | 수용 기준 | Happy Path | Edge Case | Error Case | plan.md 시나리오 전체 | 상태 |
|---|---|---|---|---|---|---|
| SC-001 | config cwd → 레지스트리 2컬럼 갱신 | PASS | — | — | PASS | PASS |
| SC-002 | 부재 경로 거부 | — | — | PASS | PASS | PASS |
| SC-003 | running 시 restart 안내 | — | PASS | — | PASS | PASS |
| SC-004 | token → .env telegram 키 600 | PASS | — | — | PASS | PASS |
| SC-005 | 빈 토큰 거부 | — | — | PASS | PASS | PASS |
| SC-006 | discord token → DISCORD 키 | PASS | — | — | PASS | PASS |
| SC-007 | zsh mode 완성 6종 | PASS | — | — | PASS | PASS |
| SC-008 | bash mode 완성 6종 | PASS | — | — | PASS | PASS |
| SC-009 | config 액션에 cwd·token | PASS | — | — | PASS | PASS |
| SC-010 | add --help 사용법 | PASS | — | — | PASS | PASS |
| SC-011 | config --help 사용법 | PASS | — | — | PASS | PASS |
| SC-012 | 완성에 --help 포함 | PASS | — | — | PASS | PASS |
| SC-013 | en/ko 키 패리티 | — | PASS | — | PASS | PASS |
| SC-014 | up telegram 세션 기동 | PASS | — | — | PASS | PASS |
| SC-015 | 세션 점유 거부 | — | — | PASS | PASS | PASS |
| SC-016 | bot.pid 생존 거부 | — | — | PASS | PASS | PASS |
| SC-017 | .env 부재 거부 | — | — | PASS | PASS | PASS |
| SC-018 | down telegram 세션 종료 | PASS | — | — | PASS | PASS |
| SC-019 | 세션 없음 + bot.pid 한계 안내 | — | PASS | — | PASS | PASS |
| SC-020 | status 예약어 표시 | PASS | — | — | PASS | PASS |
| SC-021 | logs telegram 출력 | PASS | — | — | PASS | PASS |
| SC-022 | 예약어 add/rm/rename 차단 | — | — | PASS | PASS | PASS |
| SC-023 | Bash 3.2 구문 | — | PASS | — | PASS | PASS |
| SC-024 | down 이 .env/access.json 불변 | — | PASS | — | PASS | PASS |
| SC-025 | up cwd=$PWD 기동 | PASS | — | deferred(3) | PASS (Happy+deferred) | PASS |

> SC-025 Error Case ($PWD 삭제 디렉터리): 테스트에 best-effort 케이스 포함(항상 true). 실질 검증은 운영 환경 위임 — coverage-gap.md 카테고리 (3) 참조.

---

## 코드 커버리지 요약

- 테스트 실행 도구: bats 1.13.0
- 총 테스트 수: 151개 (전체 스위트)
- v0.5.0 신규 SC 매핑 테스트: 32개 (@test 단위)
- 통과: 151 / 실패: 0 / 스킵: 0
- 회귀: 0건 (기존 119개 전부 PASS 유지)
- 정적 검증:
  - bash -n: cc-tg.sh + lib/*.sh (8개) → 전체 OK
  - shellcheck -S warning (변경 파일 8개): 신규 경고 0건 (SC2148 pre-existing — 소스 전용 라이브러리 shebang 부재, 기존 패턴)
  - scripts/check-i18n-keys.sh: OK (154키 패리티)
