# cctg TODO

> 향후 작업 후보. 우선순위·근거를 함께 기록한다. 착수 시 항목을 갱신하고, 완료하면 여기서 제거한다. 완료 이력은 `CHANGELOG.md`(+ git 이력)가 SoT.
> 우선순위: **P1**(높음) / **P2**(중간) / **P3**(낮음).
>
> **2026-06-18 전면 재정리**: 2026-06-16 감사에서 도출했던 다수 항목(0.2.0 발행·README 버전·CONTRIBUTING 브랜치 정책·.shellcheckrc·.editorconfig·.gitignore·rm/rename 자동완성·remove/mv 별칭·lib/ 런타임 분리·discord 게이트웨이·release.yml VERSION 하드닝·uninstall 잔여물/bindir·텍스트 status 테스트)이 v0.1~v0.5.1 에서 모두 해결되어 제거했다. 게이트웨이 신뢰성 견고성 핵심(거짓 UP, tmux/claude 가드, down/logs 검증, 토큰 .env 원자화, rename 롤백)은 v0.5.1/002·003 에서 해결했다. 아래는 잔여 유효 항목이다.

## 목차

- [구조 / 확장성](#구조--확장성)
  - [다중 게이트웨이 — imessage](#다중-게이트웨이--imessage)
  - [(선택) lib/commands.sh 도메인 분할](#선택-libcommandssh-도메인-분할)
- [CI / 브랜치 보호](#ci--브랜치-보호)
  - [P2 — main 브랜치 보호 활성화 (외부 repo 설정)](#p2--main-브랜치-보호-활성화-외부-repo-설정)
- [방어 코드 / 견고성 (잔여)](#방어-코드--견고성-잔여)
  - [P3 — access.json / launch.env 초기 작성 비원자](#p3--accessjson--launchenv-초기-작성-비원자)
  - [P3 — 동시 실행 TOCTOU](#p3--동시-실행-toctou)
- [테스트 커버리지 확장 (잔여)](#테스트-커버리지-확장-잔여)

## 구조 / 확장성

### 다중 게이트웨이 — imessage

telegram·discord 는 채널 descriptor(`lib/channels.sh`)로 일반화돼 구동된다. 남은 채널은 imessage 다(README 「지원 게이트웨이」 표에 "예정"으로 예약).

- **무엇**: imessage 채널 descriptor(plugin ID·statedir_env·token 정책·seed 정책) 정의 + `add`/`up`/`status` 분기 일반화.
- **주의**: imessage 는 토큰이 없고 `chat.db` 에 의존하므로 `add` 의 토큰 입력·`.env` 시드 흐름이 채널별로 분기해야 한다(현재 `id_required`/`token_required`/`seed_policy` descriptor 축을 확장). 접근제어 모델도 다름.
- **규모**: 대형(별도 기능 차수 권장). 본 TODO 정리 시점 기준 미착수.

### (선택) lib/commands.sh 도메인 분할

`cc-tg.sh` → `lib/*.sh` 런타임 분리는 완료됐다(env/output/channels/config/util/registry/session/commands 8개 모듈). 잔여는 가장 큰 `lib/commands.sh`(~770줄)를 도메인별(lifecycle / config / registry-cmd 등)로 더 쪼갤지 여부다.

- **판단**: 현재 규모에서는 단일 파일이 탐색·테스트에 더 단순하다(명령군이 한곳). 명령 수가 더 늘거나 단일 파일이 유지보수 부담이 될 때 분할한다. **현재는 보류.**

## CI / 브랜치 보호

### P2 — main 브랜치 보호 활성화 (외부 repo 설정)

`release.yml` 은 `main` push **후** 게이트를 실행하므로, `main` 직접 push 를 막지 않으면 잘못된 `VERSION` bump 가 `main` 에 먼저 도달한 뒤 게이트가 실패한다. "main 직접 push 금지"는 현재 문서상의 약속일 뿐 강제되지 않는다.

- **무엇**: GitHub repo Settings → Branches 에서 `main` 에 "Require a pull request before merging" + "Require status checks (CI)" 보호 규칙 활성화. **코드로 처리 불가 — 저장소 소유자 수동 설정.**
- **문서**: `docs/RELEASING.md` 에 이 보호가 전제임을 명시.
- **주의**: 워크플로의 `github.token` 태그 push 는 CI 를 재트리거하지 않는다. PR 시점 CI 가 실질 방어선이다.

## 방어 코드 / 견고성 (잔여)

> 게이트웨이 신뢰성 견고성의 P1·P2 핵심은 v0.5.1/003 에서 해결됐다(거짓 UP 방지=`tmux new-session` 실패 가드, `need_tmux`/`need_claude` 가드, `down` `kill-session` 실패 가드, `logs` 줄 수 검증, snapshotter 기동 확인). 토큰 `.env` 원자 쓰기·`rename` 롤백은 v0.5.1/002. 아래는 잔여 낮은-우선순위 항목.

### P3 — access.json / launch.env 초기 작성 비원자

- **위치**: `lib/commands.sh` `cmd_add`(access.json·launch.env 최초 작성), `cmd_config`(launch.env 템플릿 보강).
- **문제**: 토큰 `.env` 는 `write_token_env`(mktemp→mv)로 원자화됐고, 키 변경은 `set_env_kv`(mktemp→mv)·shared settings 는 `jq_inplace`(mktemp→mv)로 이미 원자적이다. 남은 것은 access.json·launch.env 의 **최초 작성**이 `cat >`/heredoc 직접 쓰기라는 점. 중단 시 부분 파일 가능.
- **완화 현황**: `cmd_add` 는 각 쓰기에 `|| die ERR_ADD_WRITE` 가드 + 등록 전 EXIT trap cleanup 이 있어 부분 상태가 정리된다. 비밀이 아니므로(토큰만 민감) 위험도 낮음.
- **수정 방향(선택)**: 최초 작성도 tmp→mv 로 통일하면 일관성↑. 우선순위 낮음.

### P3 — 동시 실행 TOCTOU

- **위치**: `up_one`/`up_reserved` 의 `is_running` 점검 → `new-session` 생성 사이.
- **문제**: 동일 봇에 `cctg up` 이 동시에 두 번 실행되면 둘 다 `is_running`=false 를 보고 `new-session` 을 시도, 하나가 실패한다. 단일 사용자 전제라 실제 위험은 낮다.
- **완화 현황**: v0.5.1/003 의 `new-session` 실패 가드로 실패가 정직하게 표면화된다(거짓 UP 없음). 완전 방지는 `flock` 등 잠금이 필요하나 비용 대비 우선순위 낮음.

## 테스트 커버리지 확장 (잔여)

`tests/` bats 스위트(182 테스트)는 등록·명령·라이프사이클(다중 타겟·실패 가드 포함)·스냅샷 watcher·가드 로직·텍스트/JSON status 를 격리 상태 트리 + stateful fake tmux + claude stub 으로 검증한다. 아직 안 덮은 경로:

- **`attach` / `update`** — 인터랙티브·네트워크 의존이라 수동 검증 영역으로 남기는 것이 합리적(테스트 추가는 선택).
- **`launch` 문자열 내용 검증** — stub 이 세션 생성/종료는 추적하지만 `new-session` 명령 인자 본문(`--settings`·`--permission-mode`·`CLAUDE_EXTRA_ARGS` 주입)은 단언하지 않는다. stub 의 `FAKE_TMUX_LASTCMD` 기록을 활용해 확장 가능.
- **`install.sh` / `uninstall.sh`** — 파일시스템·심볼릭·매니페스트 부수효과가 커서 별도 격리(HOME 샌드박스 + git 픽스처)가 필요. 현재 `bash -n`·shellcheck 만 적용.
