---
작성: Planning Agent
버전: v1.0
최종 수정: 2026-06-17 14:59
상태: 작성중
---

# selection-phases.md

## 목차

- [선택 단계 활성화 결정](#선택-단계-활성화-결정)
- [신규 PyPI 의존성 자가 점검 (PATCH-A15)](#신규-pypi-의존성-자가-점검-patch-a15)

---

## 선택 단계 활성화 결정

선택 단계 활성화 결정 (spec.md FR/NFR 의 **명시적** 요구사항 기준):

- **Database Design Agent: N**
  근거: FR/NFR 에 DB 스키마 변경·생성 명시 없음. 본 spec 은 순수 Bash 셸 스크립트 변경(lib/*.sh, messages/*.sh, completions/*). 상태는 파일(access.json·projects.conf·.env)로만 관리하며 DB 부재(context.md §6 "컨테이너/DB/서버 부재"). 레지스트리 스키마도 불변(NFR-003).

- **Deploy Agent: N**
  근거: FR/NFR 에 배포 환경 구성·컨테이너화·CI/CD 변경 명시 없음. 본 spec 은 lib/*.sh 등 기존 파일 수정만 — install.sh / docker / .github/workflows 변경 없음. infra.md §3 배포 = 사용자 머신 install.sh 재실행(셸 스크립트 복사) + 서버측 자동 릴리스(VERSION push). 배포 메커니즘 자체는 본 spec 미변경. 신규 파일 0개로 install 매니페스트 변경도 없음.

- **Security Agent: N**
  근거: FR/NFR 에 인증·인가·개인정보·결제·보안 신규 요구 명시 없음. 토큰 처리(NFR-002)는 기존 `--token-env`/`--token-stdin`/대화형 패턴을 그대로 사용(신규 시크릿 표면 없음, P-003 정합). access.json group id·멤버 id 의 `^[0-9]+$` JSON 주입 방어는 기존 TGID 패턴 답습(신규 보안 영역 아님). 암묵적 보안 연관만으로 활성화하지 않음(02-planning 금지사항).

- **Performance Agent: N**
  근거: NFR 에 성능 목표 수치 없음. constitution §3 명시 선언 — "SLA·측정 대상 NFR 없음(개발자용 로컬 CLI)". 본 spec 변경은 add/status 시점의 셸 분기·jq 호출 정도로 성능 측정 대상 아님.

활성화된 단계 실행 순서: 없음 (모두 N). 4단계 Development + 5a Test(AUTHORING) PPG-1 병렬 → 5b → 6단계 Docs → 7단계 Retrospective 표준 경로.

결정 일시 및 결정자: 2026-06-17 14:59, Planning Agent (spec.md FR-001~008 / NFR-001~005 의 명시적 요구사항 분석 기반).

---

## 신규 PyPI 의존성 자가 점검 (PATCH-A15)

자가 점검: 본 spec 에 신규 PyPI 의존성 추가가 있는가?

- **해당 없음 (N/A)**: 본 프로젝트는 순수 Bash 셸 스크립트 도구로 패키지 매니저(PyPI/npm/cargo) 미사용(context.md §1 "패키지 매니저 없음(순수 셸)"). `pyproject.toml` 부재. 신규 의존성 추가 없음 → 본 항목 무관. `[env:e2e-docker]` 태그 SC 도 부재(모든 SC 는 static/unit).
