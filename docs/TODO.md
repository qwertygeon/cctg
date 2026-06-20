# cctg TODO

> 향후 작업 후보. 우선순위·근거를 함께 기록한다. 착수 시 항목을 갱신하고, 완료하면 여기서 제거한다. 완료 이력은 `CHANGELOG.md`(+ git 이력)가 SoT.
> 우선순위: **P1**(높음) / **P2**(중간) / **P3**(낮음).

## 평가 렌즈 (모든 후보의 채택 기준)

각 후보는 아래 3축으로 평가하여 채택·우선순위·설계 방향을 정한다. 셋을 동시에 만족하지 못하면 방향을 재설계하거나 보류한다.

1. **확장성** — 채널·구성의 추가/일반화가 쉬워지는가(새 게이트웨이, descriptor 일반화, 모듈 경계).
2. **완성도** — "저장소에 장기 실행 어시스턴트를 붙여 둔다" 시나리오의 실제 갭(감지·복구·지속성·진단·무결성·테스트)을 닫는가.
3. **사용편의성 비저하** — 다음을 **필수 제약**으로 적용한다:
   - **기본 동작 불변**: 새 기능은 기존 사용자의 현재 흐름을 바꾸지 않는다.
   - **옵트인**: 감독/복구/통지/자동기동처럼 상주성·부작용이 있는 기능은 명시적 옵트인. 기본은 현행 유지.
   - **최소 명령 표면 · 하위호환** (constitution P-005): 정말 빈번한 것만 1급 명령/노브로 승격하고, 나머지는 기존 경로(`CLAUDE_EXTRA_ARGS` 등) 유지.
   - **마찰 없는 향상**: 진단·힌트·표시 개선은 사용자가 추가로 배워야 할 것을 늘리지 않는 방향으로.

> **현황 요약**: 핵심 기능(게이트웨이 구동·신뢰성·헬스 기반 liveness)은 이미 견고하다(최근 해결 항목은 `CHANGELOG.md` 참조 — 거짓 UP 제거·tmux/claude 가드·down/logs 검증·토큰 `.env` 원자화·rename 롤백·상태별 정렬·세션 폭 설정). 본 문서의 항목은 대부분 "상주 어시스턴트" 완성도와 확장성을 끌어올리는 **옵트인·비파괴** 작업이다.

## 목차

- [확장성](#확장성)
  - [다중 게이트웨이 — imessage](#다중-게이트웨이--imessage)
  - [(보류) lib/commands.sh 도메인 분할](#보류-libcommandssh-도메인-분할)
- [완성도 — 회복력 / 감독](#완성도--회복력--감독)
  - [P2 — 크래시 자동 복구 (restart-on-failure, 옵트인)](#p2--크래시-자동-복구-restart-on-failure-옵트인)
  - [P2 — 재부팅 지속성 (launchd 자동기동, 옵트인)](#p2--재부팅-지속성-launchd-자동기동-옵트인)
  - [P3 — 장애 통지 (옵트인)](#p3--장애-통지-옵트인)
  - [P3 — status last-activity 표기](#p3--status-last-activity-표기)
  - [P3 — liveness 신호 견고화 (claude 프로세스명 변경 대비)](#p3--liveness-신호-견고화-claude-프로세스명-변경-대비)
- [완성도 — 배포 / 운영 / CI](#완성도--배포--운영--ci)
  - [P2 — doctor 점검 심화](#p2--doctor-점검-심화)
  - [P2 — update 실패 롤백](#p2--update-실패-롤백)
  - [P2 — main 브랜치 보호 활성화 (외부 repo 설정)](#p2--main-브랜치-보호-활성화-외부-repo-설정)
  - [P3 — Homebrew tap 배포](#p3--homebrew-tap-배포)
  - [P3 — 릴리스 아티팩트 체크섬](#p3--릴리스-아티팩트-체크섬)
- [사용편의성 (마찰 없는 향상)](#사용편의성-마찰-없는-향상)
  - [P2 — 액션 명령 에러에 복구 힌트 정렬 (status 힌트와 일관)](#p2--액션-명령-에러에-복구-힌트-정렬-status-힌트와-일관)
  - [P3 — `--json` 출력 확대](#p3----json-출력-확대)
  - [P3 — 파괴적 op 확인 프롬프트 / `--dry-run`](#p3--파괴적-op-확인-프롬프트----dry-run)
  - [P3 — 타입드 설정 노브 (선별 승격)](#p3--타입드-설정-노브-선별-승격)
  - [P3 — bash 자동완성 i18n](#p3--bash-자동완성-i18n)
- [방어 코드 / 견고성 (잔여)](#방어-코드--견고성-잔여)
  - [P3 — 초기 파일 작성 비원자 (access.json / launch.env / registry append)](#p3--초기-파일-작성-비원자-accessjson--launchenv--registry-append)
  - [P3 — 동시 실행 TOCTOU](#p3--동시-실행-toctou)
  - [P3 — `claude_alive` comm 공백 경로 엣지](#p3--claude_alive-comm-공백-경로-엣지)
- [테스트 커버리지 확장 (잔여)](#테스트-커버리지-확장-잔여)

## 확장성

### 다중 게이트웨이 — imessage

telegram·discord 는 채널 descriptor(`lib/channels.sh`)로 일반화돼 구동된다(`IMPLEMENTED_CHANNELS="telegram discord"`). 남은 채널은 imessage 다(`RESERVED_NAMES` 에 예약, README 「지원 게이트웨이」 표에 "예정").

- **무엇**: imessage 채널 descriptor(plugin ID·`statedir_env`·token 정책·seed 정책) 정의 + `IMPLEMENTED_CHANNELS` 등재. `add`/`up`/`status` 배선은 descriptor 경유라 대부분 불변.
- **확장성/완성도**: 채널 "완전 커버리지"의 마지막 조각. descriptor 축 일반화가 이후 채널 추가 비용을 낮춘다.
- **사용편의성**: 기존 telegram/discord 사용자 흐름 불변(신규 채널은 추가일 뿐). 단 imessage 는 토큰이 없고 `chat.db` 의존이라 `add` 의 토큰 입력·`.env` 시드 흐름이 채널별로 분기해야 한다(`id_required`/`token_required`/`seed_policy` descriptor 축 확장) — 접근제어 모델도 다름.
- **규모**: 대형(별도 기능 차수 권장). 미착수.

### (보류) lib/commands.sh 도메인 분할

`cc-tg.sh` → `lib/*.sh` 런타임 분리는 완료(env/output/channels/config/util/registry/session/commands 8개 모듈). 잔여는 가장 큰 `lib/commands.sh`(현재 ~887줄)를 도메인별(lifecycle / config / registry-cmd 등)로 더 쪼갤지 여부다.

- **판단**: 현재 규모에서는 단일 파일이 탐색·테스트에 더 단순하다(명령군이 한곳). 명령 수가 더 늘거나 단일 파일이 유지보수 부담이 될 때 분할한다. **현재는 보류** — 분할 자체가 사용자 가치를 더하지 않고, 조기 분할은 탐색 비용만 늘린다.

## 완성도 — 회복력 / 감독

> README 의 "저장소에 장기 실행 어시스턴트를 붙여 둔다" 시나리오에서, 봇이 죽거나 멈추거나 사라졌을 때의 감지·복구·지속성이 가장 약한 영역이다. 헬스 기반 liveness(거짓 UP 제거, `DEAD` 구분)는 해결됨(`CHANGELOG.md`) — 아래는 그 감지 위에서 이어가는 **옵트인** 작업 묶음이며, 기본 동작은 현행(미재시작·수동 복귀)을 유지한다.

### P2 — 크래시 자동 복구 (restart-on-failure, 옵트인)

`claude` 가 죽으면 수동 `cctg up` 전까지 봇이 멈춘다. 감독 루프·재시작 정책이 없다.

- **무엇**: `launch.env` 옵트인 노브(예: `CCTG_RESTART_ON_FAILURE` / `CCTG_RESTART_MAX` / backoff)로 launch wrapper 가 `claude` 비정상 종료 시 제한된 횟수·backoff 로 재기동.
- **사용편의성**: **기본은 현행(미재시작) 유지** — 옵트인일 때만 동작. 재시작 중 상태는 liveness 표기와 정합.
- **주의**: API rate-limit·영구 인증 오류·즉시 종료 루프에서 **무한 재시작 폭주 방지**(backoff + 최대 횟수 + 짧은 수명 감지).
- **규모**: 중.

### P2 — 재부팅 지속성 (launchd 자동기동, 옵트인)

Mac 재부팅·로그아웃 시 tmux 세션이 전멸하고 자동 복귀 수단이 없어, 매번 수동 `cctg up` 해야 한다.

- **무엇**: 옵트인 `cctg enable-autostart` / `disable-autostart` 가 `~/Library/LaunchAgents` 에 LaunchAgent plist 를 생성/제거하여 로그인 시 지정 봇을 `up`. (또는 "재부팅 후 수동 복귀"를 명시적 한계로 문서화.)
- **사용편의성**: 옵트인 명령. 미사용 시 흐름 불변. 어떤 봇을 자동기동할지 선택 모델 필요(과도한 자동기동 방지).
- **주의**: macOS 전용(P-001, launchd). **토큰·시크릿을 plist 에 담지 않는다**(P-003 — plist 는 `cctg up <name>` 호출만).
- **규모**: 중. 단일 사용자 dev 도구 기준 "한계 문서화"로 갈음 가능.

### P3 — 장애 통지 (옵트인)

liveness/복구/재부팅 이벤트가 능동 통지되지 않는다(직접 `status`/`logs` 확인 필요).

- **무엇**: 옵트인 통지(크래시·DEAD 감지 시 macOS `osascript -e 'display notification'` 또는 사용자 지정 webhook).
- **사용편의성**: CLI 도구 모델상 항상-on 데몬 통지는 과함 → **옵트인**. 시크릿 비노출.
- **규모**: 중. P2 감지/복구 신호에 의존.

### P3 — status last-activity 표기

`status` 는 RUNNING/DEAD 상태는 보여주지만 **마지막 활동 시각**은 안 보여준다(살아있어도 멈춰있는지 구분 불가).

- **무엇**: `status`(및 `--json`)에 last-activity 표기 — `last-session.log` mtime(스냅샷터 활성 시) 또는 pane 마지막 출력 시각. RUNNING 인데 오래 무활동인 봇 식별에 도움.
- **사용편의성**: **표시 전용 — 마찰 없음.** 새 명령 학습 불필요.
- **주의**: 스냅샷터 미활성 봇은 mtime 신호 없음(부분 가용). DEAD 감지(claude 생존)와 직교한 보조 지표.
- **규모**: 저.

### P3 — liveness 신호 견고화 (claude 프로세스명 변경 대비)

`claude_alive`(`lib/session.sh`)는 pane 자손 트리에서 `comm` 이 `claude` 인 프로세스로 판정한다. claude CLI 가 프로세스명을 바꾸면(node 래퍼·`claude-code` 등) **false DEAD** 가 날 수 있다(현재는 코드 주석에만 기록).

- **무엇**: 정규식을 `claude` 단독이 아니라 launch 래퍼 `caffeinate`(이름 안정) 병행 매칭으로 확장하거나 감지 신호를 다중화. claude 프로세스명이 실제 바뀌는 시점 대응(발생 시 대응 성격).
- **사용편의성**: 내부 견고화 — 사용자 표면 불변.
- **주의**: pane 자손 한정이라 다른 caffeinate 와 충돌 없음(launch 가 유일 출처). 과대 매칭 주의.
- **규모**: 저. 발생 가능성 낮아 우선순위 낮음.

## 완성도 — 배포 / 운영 / CI

### P2 — doctor 점검 심화

현재 `doctor`(`lib/commands.sh` cmd_doctor)는 `tmux`/`claude`/`caffeinate`/`jq` 존재 + `PATH`(`~/.local/bin`) + 레지스트리/shared settings 파일을 점검한다. 흔한 실패를 사전 진단하지 못하는 영역이 남았다.

- **무엇**: 점검 추가 — (1) 사용 채널 플러그인(`telegram`/`discord`) 설치 여부, (2) `claude`/`tmux` 최소 버전, (3) `BINDIR`/libexec/share 쓰기 권한, (4) 등록 봇 `.env` 권한(600) 및 매니페스트(`~/.config/cctg/install.conf`) 경로 유효성(desync 조기 발견).
- **사용편의성**: **온보딩 실패를 줄이는 진단 — 마찰 없이 편의 향상.** 기존 doctor 흐름 그대로 항목만 추가.
- **규모**: 저비용 · 중효과.

### P2 — update 실패 롤백

`cctg update`(`lib/commands.sh` cmd_update)가 `git pull --ff-only` 성공 후 `install.sh` 실패 시(권한 거부 등) 저장소만 새 버전이고 설치는 깨진 상태로 잔존한다.

- **무엇**: pull 전 현재 ref 기록 → `install.sh` 실패 시 안내(또는 옵트인 이전 ref 복원)·전/후 검증. 매니페스트 경로 유효성 사전 점검(위 doctor 와 공유).
- **사용편의성**: 깨진 설치로부터 사용자를 보호 — 신뢰성 향상.
- **규모**: 중.

### P2 — main 브랜치 보호 활성화 (외부 repo 설정)

`release.yml` 은 `main` push **후** 게이트를 실행하므로, `main` 직접 push 를 막지 않으면 잘못된 `VERSION` bump 가 `main` 에 먼저 도달한 뒤 게이트가 실패한다. "main 직접 push 금지"는 현재 문서상 약속일 뿐 강제되지 않는다.

- **무엇**: GitHub repo Settings → Branches 에서 `main` 에 "Require a pull request before merging" + "Require status checks (CI)" 보호 규칙 활성화. **코드로 처리 불가 — 저장소 소유자 수동 설정.** `docs/RELEASING.md` 에 이 보호가 전제임을 명시.
- **주의**: 워크플로 `github.token` 태그 push 는 CI 를 재트리거하지 않는다. PR 시점 CI 가 실질 방어선.

### P3 — Homebrew tap 배포

현재 설치는 `git clone` + `./install.sh` 뿐이다. macOS CLI 표준 1줄 설치(`brew install`) 경로가 없다.

- **무엇**: Homebrew tap/formula 제공(릴리스 태그 기반). `docs/packaging.md` 는 현재 단일 셸 스크립트 단계로 의도적 보류.
- **사용편의성**: 설치 편의 **향상**(1줄 설치). 단 별도 tap repo + CI 자동 갱신 비용이 커서 사용자 규모 증가 시 재검토.
- **규모**: 대. 우선순위 낮음.

### P3 — 릴리스 아티팩트 체크섬

`release.yml` 산출물에 무결성 검증(SHA256 등)이 없어, 다운로드/클론 코드 정합을 사용자가 검증할 수 없다.

- **무엇**: 릴리스 노트/아티팩트에 SHA256 첨부(선택적 서명). `install.sh` 에 검증 옵션.
- **규모**: 중. 단일 셸 스크립트 배포 특성상 우선순위 낮음.

## 사용편의성 (마찰 없는 향상)

> 본 절은 "사용편의성 비저하"를 넘어 **편의를 적극 향상**하되, 최소 명령 표면(P-005)·하위호환을 깨지 않는 항목이다.

### P2 — 액션 명령 에러에 복구 힌트 정렬 (status 힌트와 일관)

`status` 는 BROKEN/DEAD 상태에 복구 경로 힌트를 출력(`STATUS_HINT_NO_CWD`/`NO_TOKEN`/`DEAD`)하지만, 같은 상태를 만나는 **액션 명령의 거부 메시지**는 복구 경로를 안 주거나 약하게 준다. `up` 의 DEAD 케이스(거짓 "already running")는 해결됨(`ALREADY_RUNNING_DEAD`/`ERR_RESERVED_UP_DEAD`). 잔여 동일 부류:

- **`ERR_NO_CWD`** (`up`/`up_reserved`, `lib/session.sh`): `working directory not found: <path>` 뿐 — status BROKEN 힌트("create it, or `cctg rm X` and re-add")와 달리 복구 안내 없음. **가장 명확한 잔여 케이스.** 호출부에 `PROG`/name 전달 + 메시지에 복구 경로 추가로 정렬. `up_reserved` 의 `ERR_NO_CWD` 도 `up_one` 과 메시지 형식이 불일치하므로 함께 정렬한다.
- **`ERR_NOT_REGISTERED`** (경미): `not a registered project: %s` — "`cctg add` 로 등록" 안내 없음.
- (참고) `ERR_RESERVED_UP_RUNNER`: 외부 `bot.pid` 러너라 단일 명령 복구가 모호 — 안내 문구만 보강 가능.
- **이미 양호(본보기)**: `ERR_RUNNING_DOWN_FIRST`("Stop it first with `cctg down X`"), `ERR_NOT_RUNNING`("run `cctg up X` first"), config `APPLY_RESTART`.
- **사용편의성**: 오류 시 다음 행동을 바로 안내 — 마찰 감소. 메시지 + 호출부 인자 정렬(i18n 키 en/ko).
- **규모**: 저.

### P3 — `--json` 출력 확대

현재 `--json` 은 `status` 만 지원한다(`lib/commands.sh`). `logs`/`config show`/`common show` 의 기계 판독 출력은 없다.

- **무엇**: 위 조회 명령에 `--json` 추가(자동화·통합 용도).
- **사용편의성/확장성**: 스크립팅·외부 통합 편의. 사람용 출력은 기본 유지(플래그 옵트인)이라 기존 사용 흐름 불변. 핵심 use case(status)는 이미 충족 — 나머지는 nice-to-have.
- **규모**: 저.

### P3 — 파괴적 op 확인 프롬프트 / `--dry-run`

파괴적 op(`rm --purge`, `config token`)에 dry-run·확인 프롬프트가 없다. 현재는 `--purge` 명시 플래그 + 보호 디렉터리 가드 + 마스킹 입력으로 완화돼 있다.

- **무엇**: (선택) `--dry-run`(영향 미리보기), 파괴적 op 확인 프롬프트.
- **사용편의성**: 안전성 향상이나 **과도한 프롬프트는 마찰**이 되므로, 정말 파괴적인 op 에 한정하고 기존 명시 플래그(`--purge`) 정책과 중복되지 않게 한다. 자동화 호환 위해 `--yes`/비대화 모드 보존.
- **규모**: 저. nice-to-have.

### P3 — 타입드 설정 노브 (선별 승격)

`config` 는 `mode`/`args`/`snapshot`/`cwd`/`token` 을 지원한다(`lib/commands.sh` cmd_config). 모델 선택·로그 verbosity·재시작 정책은 free-form `CLAUDE_EXTRA_ARGS` 로만 가능하다.

- **무엇**: 자주 쓰는 항목(예: `config <name> model <m>`)을 타입드 노브로 노출 검토. 재시작 정책은 "P2 크래시 자동 복구"와 연동.
- **사용편의성 (트레이드오프)**: 최소 명령 표면(P-005)과 직접 충돌 가능 — **정말 빈번한 것만 승격**하고 나머지는 `CLAUDE_EXTRA_ARGS` 유지. 무분별한 노브 추가는 표면 비대화로 오히려 편의를 해친다.
- **규모**: 저(선별 시).

### P3 — bash 자동완성 i18n

zsh 자동완성은 한/영 설명, bash 는 영어-only(`completions/cctg.bash`).

- **무엇**: bash 자동완성 설명 i18n.
- **사용편의성**: 실질 내용은 언어-중립(플래그/모드명)이라 영향 낮음.
- **규모**: 저. nice-to-have.

## 방어 코드 / 견고성 (잔여)

> 게이트웨이 신뢰성의 P1·P2 핵심은 해결됨(`CHANGELOG.md` — `tmux new-session` 실패 가드, `need_tmux`/`need_claude` 가드, `down` `kill-session` 실패 가드, `logs` 줄 수 검증, snapshotter 기동 확인, 토큰 `.env` 원자 쓰기, `rename` 롤백). 아래는 잔여 낮은-우선순위 항목으로, **단일 사용자 dev 도구 전제**상 실제 위험이 낮아 우선순위가 낮다.

### P3 — 초기 파일 작성 비원자 (access.json / launch.env / registry append)

- **위치**: `lib/commands.sh` `cmd_add`(access.json·launch.env 최초 작성, registry `>>` append), `cmd_config`(launch.env 템플릿 보강).
- **문제**: 토큰 `.env`(`write_token_env`)·키 변경(`set_env_kv`)·shared settings(`jq_inplace`)·registry remove/rename/cwd(`lib/registry.sh`)는 mktemp→mv 로 원자적이다. 잔여는 (1) access.json·launch.env **최초 작성**이 `cat >`/heredoc 직접 쓰기, (2) `cmd_add` 의 registry **append** 가 `>>` 직접 쓰기라는 점. 중단·경합 시 부분 파일/경합 쓰기 가능.
- **완화 현황**: `cmd_add` 는 각 쓰기에 `|| die ERR_ADD_WRITE` 가드 + 등록 전 EXIT trap cleanup 이 있어 부분 상태가 정리된다. registry 경합은 사전 `lookup` 검사로 대부분 차단되고 단일 사용자 전제라 위험 낮음. 비밀이 아니므로(토큰만 민감, 이미 원자화) 위험도 낮음.
- **수정 방향(선택)**: 최초 작성·append 도 tmp→mv 로 통일하면 일관성↑. 우선순위 낮음.

### P3 — 동시 실행 TOCTOU

- **위치**: `up_one`/`up_reserved` 의 `is_running` 점검 → `new-session` 생성 사이.
- **문제**: 동일 봇에 `cctg up` 이 동시에 두 번 실행되면 둘 다 `is_running`=false 를 보고 `new-session` 을 시도, 하나가 실패한다. 단일 사용자 전제라 실제 위험은 낮다.
- **완화 현황**: `new-session` 실패 가드로 실패가 정직하게 표면화된다(거짓 UP 없음). 완전 방지는 `flock` 등 잠금이 필요하나 비용 대비 우선순위 낮음.

### P3 — `claude_alive` comm 공백 경로 엣지

`claude_alive`(`lib/session.sh`)는 `ps -ax -o pid=,ppid=,comm=` 출력을 awk 로 파싱해 3번째 필드(comm)를 본다. claude 실행 **경로에 공백**이 있으면(예: `/Users/me/My Tools/claude`) comm 이 여러 필드로 쪼개져 매칭이 깨질 수 있다 → false DEAD.

- **위치**: `lib/session.sh` `claude_alive` 의 awk 필드 분해.
- **현황**: claude 경로에 공백은 드물어 수용된 엣지(`decisions.md` DEC-003 기록). 단 사용자 홈/도구 경로에 공백이 생길 여지는 있음.
- **수정 방향(선택)**: comm 대신 `command=`(전체 명령줄) 파싱 + 앵커 매칭, 또는 `ppid`/`pid` 만 awk 로 뽑고 comm 은 `ps -p <pid> -o comm=` 개별 조회. 우선순위 낮음.

## 테스트 커버리지 확장 (잔여)

`tests/` bats 스위트(현재 **217 테스트**)는 등록·명령·라이프사이클(다중 타겟·실패 가드 포함)·스냅샷 watcher·가드 로직·텍스트/JSON status(상태별 정렬·버킷 내부 최근 실행순 포함)를 격리 상태 트리 + stateful fake tmux + claude stub 으로 검증한다. 아직 안 덮은 경로:

- **`install.sh` / `uninstall.sh`** — 파일시스템·심볼릭·매니페스트 부수효과가 커서 별도 격리(HOME 샌드박스 + git 픽스처)가 필요. 현재 `bash -n`·shellcheck 만 적용. **위 "배포/운영" 의 update 롤백·doctor 심화와 함께 다룰 때 우선순위 상향 권장(P2).**
- **`attach` / `update`** — 인터랙티브·네트워크 의존이라 수동 검증 영역으로 남기는 것이 합리적(테스트 추가는 선택).
- **`launch` 문자열 내용 검증** — stub 이 세션 생성/종료는 추적하지만 `new-session` 명령 인자 본문(`--settings`·`--permission-mode`·`CLAUDE_EXTRA_ARGS` 주입)은 단언하지 않는다. stub 의 `FAKE_TMUX_LASTCMD` 기록을 활용해 확장 가능.
