---
작성: Planning Agent
버전: v1.0
최종 수정: 2026-06-17 21:18
상태: 확정
---

# selection-phases.md

선택 단계 활성화 결정:

- **Database Design Agent: N**
  근거: FR/NFR 어디에도 DB 스키마 변경·생성 없음. 본 프로젝트는 DB·서버 부재(context.md §6, infra.md §8). 데이터는 평문 레지스트리(`projects.conf`)·`.env`·`access.json` 파일뿐이며 본 spec 은 스키마 변경 없이 기존 값만 갱신(plan.md 데이터 모델 절). 비활성.

- **Deploy Agent: N**
  근거: FR/NFR 에 배포 환경 구성·컨테이너화·CI/CD 변경 명시 없음. 컨테이너/서버 부재(infra.md §8). 신규 PyPI/패키지 의존성 없음 — 순수 Bash, 외부 패키지 매니저 미사용(plan.md 기술 컨텍스트). `[env:e2e-docker]` 태그 SC 부재(전 SC 가 unit/static). PATCH-A15 자가 점검: 신규 패키지 의존성 추가 없음 → 본 항목 무관. 비활성.

- **Security Agent: N**
  근거: 보안 관점(P-003 토큰 비노출·`.env` 600·access.json 보호·주입 방어)을 신중히 검토한 결과, 본 spec 은 **신규 보안 표면을 만들지 않고 기존 보안 패턴을 재사용**한다:
    - token 재작성(FR-002): `cmd_add` 의 검증된 토큰 입력 경로(argv 금지, 대화형 마스킹/`--token-env`/`--token-stdin`, .env 600)를 그대로 재사용. 신규 입력 표면 없음. NFR-004/P-003 으로 spec 에 명시 포함되어 plan.md Gate P-003 통과.
    - access.json: 본 spec 은 access.json 을 **읽지도 쓰지도 않는다**(channel 사후 변경·allowlist 편집은 명시적 "범위 외"). 그룹 C `down`/`status` 는 access.json 비접근(SC-024 로 불변 검증). P-002.
    - 주입 방어: 신규 사용자 입력 중 JSON·셸 주입 경로 없음(cwd 는 `-d` 디렉터리 검증, token 은 .env 평문 1줄, 예약어는 고정 RESERVED_NAMES case). 외부 표면(네트워크·HTTP API) 부재.
  보안 검토 항목이 모두 spec FR/NFR 와 plan Constitution Gates(P-002/P-003) 에 흡수되어 별도 Security Agent 활성 사유 부재. 비활성.

- **Performance Agent: N**
  근거: NFR 에 성능 목표 수치 없음. constitution §3 에서 "SLA·측정 대상 NFR 없음 — 로컬 CLI 도구, 성능 수치화 면제"를 명시 선언(no-silent-caps). 비활성.

활성화된 단계 실행 순서: 없음 (필수 파이프라인 단계만 진행 — Design → PPG-1(Development ∥ Test-Authoring) → Test-Execution → Docs → Retrospective).

결정 일시 및 결정자: 2026-06-17 21:18 / Planning Agent
