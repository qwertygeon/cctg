# decisions — v0.6.0/001-multi-target-lifecycle

> 작성: 2026-06-18 13:12 / 상태: ACTIVE

- **DEC-001 (에러 처리·출력)**: continue-on-error 채택 — 한 타겟 실패해도 나머지 계속. 처리 ≥2건일 때 성공/실패 요약 1줄 출력, 실패 있으면 비0 종료. fail-fast 미채택.
  - 근거: 사용자 확정("1. continue-on-error, 실행 성공/실패에 대한 정보들 출력"). "여러 봇 한 번에 기동" UX 에서 한 봇 실패로 전체 중단은 비효율.
- **DEC-002 (범위)**: 다중 타겟은 up/down/restart 에만 적용. logs/attach 제외(attach=단일 interactive 세션, logs=단일 조회), status/config 불변.
  - 근거: 사용자 확정("2. logs/attach 제외").
- **DEC-003 (구현 형태)**: 세 명령 공통 분기를 `_lifecycle_apply`/`_lifecycle_run` 헬퍼로 추출(중복 제거). 비자명도 낮아 사용자 확인 불요(직접 채택).
