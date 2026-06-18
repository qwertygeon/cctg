# CHANGES — v0.5.1/001-add-flow-hardening

> 작성: 2026-06-18 14:55 | 버전: 1.0 | 최종 수정: 2026-06-18 14:55 | 상태: 완료(검증 통과)

## 목차

- [요약](#요약)
- [동기](#동기)
- [변경 내용](#변경-내용)
- [변경 파일](#변경-파일)
- [검증 결과](#검증-결과)
- [의도적 비변경 (no-silent-caps)](#의도적-비변경-no-silent-caps)
- [하위호환·안전](#하위호환안전)

## 요약

`cctg add` 의 대화형 권한모드 입력을 **번호 선택 메뉴**로 전환하고(오타 차단 + 재입력), 모든 입력을 **파일 생성 전에 검증**(validate-before-write)하도록 재배치하여 오입력 시 남던 **반쪽 생성 상태**를 제거했다. 더해 등록 전 비정상 종료 시 **우리가 만든 상태 디렉터리만 정리**하는 EXIT trap 안전망을 추가했다.

## 동기

Discord 사용자 제보: "add 시 권한모드를 잘못 입력하면 생성이 애매하게 완료되어버린다."

코드 추적 결과 `cmd_add` 가 부작용(파일 쓰기)을 검증보다 먼저 수행했다 — `mkdir`→`.env`→`access.json` 을 쓴 **뒤에야** 대화형 권한모드를 검증하고 틀리면 `die`. 그 결과 `launch.env`·레지스트리 등록이 없는 반쪽 상태가 남았고, foreign-statedir 가드(`launch.env` 없이 `.env`/`access.json` 존재)가 같은 이름 재시도를 `ERR_FOREIGN_STATEDIR` 로 막아 막다른 길이 되었다.

## 변경 내용

### 1. 대화형 권한모드 — 번호 선택 메뉴 + 재입력 루프 (DEC-002)

- 자유 텍스트 `read` → 수동 `case` 기반 번호 메뉴로 전환. 표시 순서(사용자 지정): **1) bypassPermissions  2) acceptEdits  3) auto  4) default  5) dontAsk  6) plan  7) (공통 따름)**.
- 잘못된 입력은 죽이지 않고 재입력 요청(`te ERR_ADD_MODE_CHOICE`). 빈 입력(Enter)/`7` = 공통 따름. EOF 시에도 공통 따름으로 안전 종료. 번호 외 모드명 직접 입력도 수용.
- `select` 빌트인 대신 수동 루프 — Bash 3.2 호환·파이프 입력 테스트 결정성·Enter/번호/모드명 동시 수용 제어가 쉽다.
- 표시 순서는 검증 집합 `VALID_MODES`("acceptEdits auto bypassPermissions …") 와 독립적인 별도 순서.

### 2. validate-before-write 재배치 (DEC-003)

- 토큰·채널ID·groups·권한모드를 **모두 수집·검증한 뒤에만** `mkdir`→`.env`→`access.json`→`launch.env`→레지스트리 등록을 수행.
- `need_jq` 와 group 파싱 검증도 쓰기 이전으로 이동(기존엔 `.env` 작성 후 `need_jq` 호출 — jq 미설치 시에도 반쪽 잔존 가능했음).

### 3. 등록 전 비정상 종료 cleanup (DEC-004)

- 쓰기 구간 진입 직전 `trap '... rm -rf "$CCTG_ADD_CLEANUP_DIR"' EXIT` 설치. **사전에 존재하지 않던 SD**(`[ -e "$SD" ]` 거짓)일 때만 cleanup 대상으로 등록 → 등록 완료(point of no return) 시 변수 비우고 `trap - EXIT` 해제.
- 각 쓰기(`mkdir`/`.env`/`access.json`/`launch.env`/registry)에 `|| die ERR_ADD_WRITE "<path>"` 가드. 쓰기 실패(디스크 등) 시 die→exit→trap 으로 자동 정리.
- P-002 안전: 사전 존재 디렉터리는 절대 삭제하지 않는다.

## 변경 파일

- `lib/commands.sh` — `cmd_add` 재구성(수집·검증 구간 / 커밋 구간 분리, 권한모드 메뉴, EXIT trap).
- `messages/en.sh`, `messages/ko.sh` — `ADD_PROMPT_MODE` 제거; `ADD_MODE_MENU`·`ADD_PROMPT_MODE_PS3`·`ERR_ADD_MODE_CHOICE`·`ERR_ADD_WRITE` 추가(키 패리티 161).
- `tests/add.bats` — 신규 9건(메뉴 순서 1=bypassPermissions/2=acceptEdits, Enter/7=공통, 모드명 입력, 재입력, validate-before-write 무흔적, foreign-statedir 막다른 길 해소·재시도).
- `docs/telegram-setup.md`·`.ko.md`, `docs/discord-setup.md`·`.ko.md` — 대화형 권한모드 서술·예시 세션을 메뉴 형태로 갱신.
- `CHANGELOG.md` — [Unreleased] Changed/Fixed 항목 추가.

## 검증 결과

- `bash -n lib/commands.sh`: PASS / `bash --posix -n messages/{en,ko}.sh`: PASS
- `scripts/check-i18n-keys.sh`: PASS (en/ko 패리티 + 참조 키, 161 키)
- `bats tests/*.bats`: **176/176 PASS** (신규 9건 포함, 회귀 0)
- `shellcheck -S warning cc-tg.sh install.sh uninstall.sh scripts/*.sh` (CI 동일, external-sources 로 lib 포함): **EXIT 0**

## 의도적 비변경 (no-silent-caps)

- **완성 파일(`completions/*`) 미변경**: 셸 자동완성은 실행 중 `read` 프롬프트(대화형 메뉴)에 동작하지 않는다(셸이 아닌 cctg 가 stdin 을 읽음). `--mode` 플래그 자동완성은 이미 6개 값을 완성하며 본 변경과 무관하므로 그대로 둔다.
- **`VERSION` 파일 미변경**: `0.5.0` 유지. 버전 bump(→`0.5.1`)는 릴리스 단계(release 브랜치→main push 시 자동 태그·발행)에서 수행 — 본 작업에서 자동 변경하지 않는다(P-004 / RELEASING.md).
- **별도 spec/plan/research/tasks 산출물 미작성**: direct 모드로 본 CHANGES.md + decisions.md + pipeline-log.md 에 통합.
- **DIFF 산출물 미생성**: `git diff` 가 SoT.

## 하위호환·안전

- 비대화형(`--token-env`/`--token-stdin` + `--mode`) 경로 동작 불변.
- 대화형에서 모드명 직접 입력·빈 입력(공통 따름) 모두 보존 → 기존 스크립트 호환.
- 행동 변화 1건: 대화형에서 **잘못된 모드명 입력 후 EOF** 시 기존엔 die(반쪽 잔존), 이제는 공통 따름으로 정상 생성. 더 견고한 방향.
- constitution: P-001(Bash 3.2 — 연관배열·`select` 미사용), P-002(자가 생성 SD 만 삭제), P-003(토큰 비노출 불변), P-005(표면 최소·하위호환) 준수.
