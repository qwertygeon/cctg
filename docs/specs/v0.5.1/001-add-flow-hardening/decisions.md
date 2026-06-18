# decisions — v0.5.1/001-add-flow-hardening

> 작성: 2026-06-18 14:42 | 버전: 0.1 | 최종 수정: 2026-06-18 14:42 | 상태: 확정

## DEC-001 — 버전 v0.5.1 (PATCH)

- **결정**: 본 작업을 v0.5.1 (PATCH) 사이클의 첫 스펙(001)으로 둔다.
- **맥락**: VERSION=0.5.0 이 이미 릴리스 확정(CHANGELOG)되어 새 폴더 필요. 변경 성격이 혼합 — 반쪽 생성 방지·cleanup(방어코드)이 핵심 동기, select 메뉴는 그 수단(대화형 UX, 비호환 없음).
- **근거**: 사용자가 Discord 에서 A(v0.5.1) 선택. SemVer(docs/RELEASING.md): 하위호환 버그수정·방어코드 = PATCH.

## DEC-002 — 대화형 권한모드 입력: 번호 선택 메뉴 + 재입력 루프

- **결정**: 대화형 add 의 권한모드 입력을 자유 텍스트 `read` 에서 **번호 선택 메뉴**(수동 case 루프)로 전환한다. 표시 순서: 1)bypassPermissions 2)acceptEdits 3)auto 4)default 5)dontAsk 6)plan 7)공통 따름. 잘못된 입력은 죽이지 않고 재입력 요청. 빈 입력(Enter) 또는 7 = 공통 설정 따름. 편의상 모드명 직접 타이핑도 허용.
- **근거**: 셸 자동완성은 실행 중 `read` 프롬프트에 동작 불가(셸이 아닌 cctg 가 stdin 읽음). 정해진 값 중 선택이므로 번호 메뉴가 오타를 원천 차단. `select` 빌트인 대신 수동 case 루프 — Bash 3.2 호환·파이프 입력 테스트 결정성·Enter/번호/모드명 동시 수용 제어가 쉬움.
- **표시 순서 사유**: 사용자 지정(bypassPermissions=1, acceptEdits=2). 검증 집합 VALID_MODES("acceptEdits auto bypassPermissions default dontAsk plan") 와 별개의 표시 순서.

## DEC-003 — validate-before-write 재배치

- **결정**: 모든 입력(token·id·groups·mode)을 **파일 생성 전에** 수집·검증한다. 검증 통과 후에만 mkdir→.env→access.json→launch.env→레지스트리 등록을 수행.
- **근거**: 기존 흐름은 mkdir·.env·access.json 을 먼저 쓰고 권한모드를 나중에 검증 → 오입력 시 launch.env·등록 없는 반쪽 상태. 게다가 foreign-statedir 가드(launch.env 없이 .env/access.json 존재)가 같은 이름 재시도를 ERR_FOREIGN_STATEDIR 로 막아 막다른 길. 검증 선행으로 반쪽 상태를 원천 제거.

## DEC-004 — 등록 전 비정상 종료 cleanup (EXIT trap, 안전망)

- **결정**: 쓰기 구간 진입 직전 EXIT trap 을 걸고, **우리가 새로 만든 SD**(쓰기 전 미존재)일 때만 레지스트리 등록 전 비정상 종료 시 `rm -rf "$SD"`. 등록 완료(point of no return) 후 trap 해제. 각 쓰기에 `|| die` 가드.
- **근거**: DEC-003 으로 검증 실패발 반쪽 상태는 사라지지만, 쓰기 자체 실패(디스크·jq 등 예기치 못한 중단)는 남는다. trap 으로 등록 전 실패를 정리해 막다른 길까지 자동 해소. P-002(안전): 사전 존재 디렉터리는 절대 삭제하지 않음 — 우리가 만든 SD 만 제거.
