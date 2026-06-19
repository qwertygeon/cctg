# cctg TODO

> 향후 작업 후보. 우선순위·근거를 함께 기록한다. 착수 시 항목을 갱신하고, 완료하면 여기서 제거한다. 완료 이력은 `CHANGELOG.md`(+ git 이력)가 SoT.
> 우선순위: **P1**(높음) / **P2**(중간) / **P3**(낮음).
>
> **2026-06-18 전면 재정리**: 2026-06-16 감사에서 도출했던 다수 항목(0.2.0 발행·README 버전·CONTRIBUTING 브랜치 정책·.shellcheckrc·.editorconfig·.gitignore·rm/rename 자동완성·remove/mv 별칭·lib/ 런타임 분리·discord 게이트웨이·release.yml VERSION 하드닝·uninstall 잔여물/bindir·텍스트 status 테스트)이 v0.1~v0.5.1 에서 모두 해결되어 제거했다. 게이트웨이 신뢰성 견고성 핵심(거짓 UP, tmux/claude 가드, down/logs 검증, 토큰 .env 원자화, rename 롤백)은 v0.5.1/002·003 에서 해결했다.
>
> **2026-06-18 완성도 검토 반영**: "Claude Code + tmux 게이트웨이" 완성도 관점의 코드 동작 검토에서 도출한 갭을 아래에 우선순위와 함께 추가했다. 가장 큰 갭은 **런타임 회복력/감독**(거짓 UP·자동복구·재부팅 지속성)이다. 핵심 기능 자체는 견고하며 본 항목들은 "상주 어시스턴트" 사용 시나리오의 완성도를 끌어올리는 작업이다.

## 목차

- [게이트웨이 회복력 / 감독](#게이트웨이-회복력--감독)
  - [P2 — 크래시 자동 복구 (restart-on-failure, 옵트인)](#p2--크래시-자동-복구-restart-on-failure-옵트인)
  - [P2 — 재부팅 지속성 (launchd 자동기동, 옵트인)](#p2--재부팅-지속성-launchd-자동기동-옵트인)
  - [P3 — 장애 통지](#p3--장애-통지)
  - [P3 — status last-activity 표기](#p3--status-last-activity-표기)
  - [P3 — liveness 신호 견고화 (claude 프로세스명 변경 대비)](#p3--liveness-신호-견고화-claude-프로세스명-변경-대비)
- [배포 / 운영 / CI](#배포--운영--ci)
  - [P2 — doctor 점검 심화](#p2--doctor-점검-심화)
  - [P2 — update 실패 롤백](#p2--update-실패-롤백)
  - [P2 — main 브랜치 보호 활성화 (외부 repo 설정)](#p2--main-브랜치-보호-활성화-외부-repo-설정)
  - [P3 — Homebrew tap 배포](#p3--homebrew-tap-배포)
  - [P3 — 릴리스 아티팩트 체크섬](#p3--릴리스-아티팩트-체크섬)
- [설정 / UX 표면](#설정--ux-표면)
  - [P3 — 타입드 설정 노브 (model / restart / verbosity)](#p3--타입드-설정-노브-model--restart--verbosity)
  - [P3 — UX 잔여 (--json 확대 / --dry-run / 확인 프롬프트 / bash 자동완성 i18n)](#p3--ux-잔여---json-확대----dry-run--확인-프롬프트--bash-자동완성-i18n)
- [구조 / 확장성](#구조--확장성)
  - [다중 게이트웨이 — imessage](#다중-게이트웨이--imessage)
  - [(선택) lib/commands.sh 도메인 분할](#선택-libcommandssh-도메인-분할)
- [방어 코드 / 견고성 (잔여)](#방어-코드--견고성-잔여)
  - [P3 — access.json / launch.env 초기 작성 비원자](#p3--accessjson--launchenv-초기-작성-비원자)
  - [P3 — 동시 실행 TOCTOU](#p3--동시-실행-toctou)
  - [P3 — `claude_alive` comm 공백 경로 엣지](#p3--claude_alive-comm-공백-경로-엣지)
- [테스트 커버리지 확장 (잔여)](#테스트-커버리지-확장-잔여)

## 게이트웨이 회복력 / 감독

> README 의 "저장소에 장기 실행 어시스턴트를 붙여 둔다" 시나리오를 기준으로, 봇이 죽거나 멈추거나 사라졌을 때의 감지·복구·지속성이 현재 가장 약한 영역이다. 아래 항목은 하나의 "supervision" 결손 묶음이다.
>
> **P1(헬스 기반 liveness, 거짓 UP 제거) 해결됨** — v0.5.1/006-liveness-dead-state: `status`/`--json` 이 pane 자손 트리의 `claude` 생존을 확인해 `DEAD`(세션은 있으나 claude 종료)를 구분한다. 자동복구(아래 P2)·통지(P3)는 그 감지 위에서 이어간다.

### P2 — 크래시 자동 복구 (restart-on-failure, 옵트인)

`claude` 가 죽으면 수동 `cctg up` 전까지 봇이 멈춘다. 감독 루프·재시작 정책이 없다.

- **무엇**: `launch.env` 옵트인 노브(예: `CCTG_RESTART_ON_FAILURE` / `CCTG_RESTART_MAX` / backoff)로, launch wrapper 가 `claude` 비정상 종료 시 제한된 횟수·backoff 로 재기동. 기본은 현행(미재시작) 유지.
- **주의**: API rate-limit·영구 인증 오류·즉시 종료 루프에서 **무한 재시작 폭주 방지**(backoff + 최대 횟수 + 짧은 수명 감지). P1 liveness 와 정합(재시작 중 상태 표기).
- **규모**: 중. P1(liveness) 선행 권장.

### P2 — 재부팅 지속성 (launchd 자동기동, 옵트인)

Mac 재부팅·로그아웃 시 tmux 세션이 전멸하고 자동 복귀 수단이 없어, 사용자가 매번 수동 `cctg up` 해야 한다.

- **무엇**: 옵트인 `cctg enable-autostart` / `disable-autostart` 가 `~/Library/LaunchAgents` 에 LaunchAgent plist 를 생성/제거하여 로그인 시 지정 봇들을 `up`. (또는 문서에 "재부팅 후 수동 복귀"를 명시적 한계로 기재.)
- **주의**: macOS 전용 정합(P-001, launchd 는 macOS). 토큰·시크릿을 plist 에 담지 않는다(P-003 — plist 는 `cctg up <name>` 호출만). 어떤 봇을 자동기동할지 선택 모델 필요.
- **규모**: 중. 단일 사용자 dev 도구 기준 "예정/한계 문서화"로 갈음 가능.

### P3 — 장애 통지

위 liveness/복구/재부팅 이벤트가 사용자에게 능동 통지되지 않는다(직접 `status`/`logs` 확인 필요).

- **무엇**: 옵트인 장애 통지(예: 크래시·DEAD 감지 시 macOS 알림 `osascript -e 'display notification'` 또는 사용자 지정 webhook).
- **주의**: CLI 도구 모델상 항상-on 데몬 통지는 과함 — 옵트인. 시크릿 비노출.
- **규모**: 중. P1/P2 의 감지 신호에 의존.

### P3 — status last-activity 표기

`status` 는 RUNNING/DEAD 등 상태는 보여주지만 봇이 **마지막으로 활동한 시각**은 안 보여준다(살아있어도 멈춰있는지 구분 불가). v0.5.1/006 P1 liveness 의 원래 검토 항목이었으나 본 차수 스코프에서 제외됐다(거짓 UP 제거에 집중).

- **무엇**: `status`(및 `--json`)에 last-activity 표기 — 예: `last-session.log` mtime(스냅샷터 활성 시) 또는 pane 마지막 출력 시각. RUNNING 인데 오래 무활동인 "좀비스러운" 봇 식별에 도움.
- **주의**: 스냅샷터 미활성 봇은 mtime 신호가 없음(부분 가용). DEAD 감지(claude 생존)와는 직교 — 보조 지표.
- **규모**: 저. 표시 전용.

### P3 — liveness 신호 견고화 (claude 프로세스명 변경 대비)

`claude_alive`(v0.5.1/006)는 pane 자손 트리에서 `comm` 이 `claude` 인 프로세스로 판정한다. claude CLI 가 프로세스명을 바꾸면(node 래퍼·`claude-code` 등) **false DEAD** 가 날 수 있다(현재는 코드 주석에만 기록).

- **무엇**: 정규식을 `claude` 단독이 아니라 launch 래퍼 `caffeinate`(이름 안정) 병행 매칭으로 확장하거나, 감지 신호를 다중화. claude 프로세스명이 실제 바뀌는 시점에 대응(발생 시 대응 성격).
- **주의**: pane 자손 한정이라 다른 caffeinate 와 충돌 없음(launch 가 유일 출처). 과대 매칭 주의.
- **규모**: 저. 발생 가능성 낮아 우선순위 낮음.

## 배포 / 운영 / CI

### P2 — doctor 점검 심화

현재 `doctor` 는 `tmux`/`claude`/`caffeinate`/`jq` 존재만 확인한다(`lib/commands.sh` doctor). 흔한 실패를 사전 진단하지 못한다.

- **무엇**: 다음 점검 추가 — (1) 사용 채널 플러그인(`telegram`/`discord`) 설치 여부, (2) `claude`/`tmux` 최소 버전, (3) `BINDIR`/libexec/share 쓰기 권한, (4) 등록 봇 `.env` 권한(600) 및 매니페스트(`~/.config/cctg/install.conf`) 경로 유효성(매니페스트 desync 조기 발견).
- **규모**: 저비용 · 중효과. 신규 사용자 onboarding 실패를 크게 줄인다.

### P2 — update 실패 롤백

`cctg update` 가 `git pull --ff-only` 성공 후 `install.sh` 실패 시(권한 거부 등) 저장소만 새 버전이고 설치는 깨진 상태로 잔존한다(`lib/commands.sh` update).

- **무엇**: pull 전 현재 ref 를 기록하고, `install.sh` 실패 시 안내(또는 옵트인으로 이전 ref 복원)·전/후 검증. 매니페스트 경로 유효성 사전 점검(위 doctor 와 공유).
- **규모**: 중.

### P2 — main 브랜치 보호 활성화 (외부 repo 설정)

`release.yml` 은 `main` push **후** 게이트를 실행하므로, `main` 직접 push 를 막지 않으면 잘못된 `VERSION` bump 가 `main` 에 먼저 도달한 뒤 게이트가 실패한다. "main 직접 push 금지"는 현재 문서상의 약속일 뿐 강제되지 않는다.

- **무엇**: GitHub repo Settings → Branches 에서 `main` 에 "Require a pull request before merging" + "Require status checks (CI)" 보호 규칙 활성화. **코드로 처리 불가 — 저장소 소유자 수동 설정.**
- **문서**: `docs/RELEASING.md` 에 이 보호가 전제임을 명시.
- **주의**: 워크플로의 `github.token` 태그 push 는 CI 를 재트리거하지 않는다. PR 시점 CI 가 실질 방어선이다.

### P3 — Homebrew tap 배포

현재 설치는 `git clone` + `./install.sh` 뿐이다. macOS CLI 의 표준 1줄 설치(`brew install`) 경로가 없다.

- **무엇**: Homebrew tap/formula 제공(릴리스 태그 기반). `docs/packaging.md` 는 현재 단일 셸 스크립트 단계로 의도적 보류 상태 — 사용자 규모가 커지면 재검토.
- **규모**: 대(별도 tap repo + CI 자동 갱신). 우선순위 낮음.

### P3 — 릴리스 아티팩트 체크섬

`release.yml` 산출물에 무결성 검증(SHA256 등)이 없어, 다운로드/클론 코드의 정합을 사용자가 검증할 수 없다.

- **무엇**: 릴리스 노트/아티팩트에 SHA256 첨부(선택적으로 서명). `install.sh` 에 검증 옵션.
- **규모**: 중. 단일 셸 스크립트 배포 특성상 우선순위 낮음.

## 설정 / UX 표면

### P3 — 타입드 설정 노브 (model / restart / verbosity)

`config` 는 `mode`/`args`/`snapshot`/`cwd`/`token` 을 지원한다(`lib/commands.sh` cmd_config). 모델 선택·로그 verbosity·재시작 정책은 현재 free-form `CLAUDE_EXTRA_ARGS` 로만 가능하다.

- **무엇**: 자주 쓰는 항목(예: `config <name> model <m>`)을 타입드 노브로 노출 검토. 재시작 정책은 위 "P2 크래시 자동 복구" 와 연동.
- **주의**: 최소 명령 표면 원칙(P-005)과 트레이드오프 — 정말 빈번한 것만 승격하고 나머지는 `CLAUDE_EXTRA_ARGS` 유지.
- **규모**: 저.

### P3 — UX 잔여 (--json 확대 / --dry-run / 확인 프롬프트 / bash 자동완성 i18n)

- **`--json` 확대**: 현재 `status` 만 지원. `logs`/`config show`/`common show` 의 기계 판독 출력은 없음. 핵심 use case(status)는 충족 — 나머지는 nice-to-have.
- **`--dry-run` / 확인 프롬프트**: 파괴적 op(`rm --purge`, `config token`)에 dry-run·확인 프롬프트 없음. 현재는 `--purge` 명시 플래그 + 보호 디렉터리 가드 + 마스킹 입력으로 완화됨.
- **bash 자동완성 i18n**: zsh 자동완성은 한/영 설명, bash 는 영어-only(`completions/cctg.bash`). 실질 내용은 언어-중립(플래그/모드명)이라 영향 낮음.
- **규모**: 저. 모두 nice-to-have.

## 구조 / 확장성

### 다중 게이트웨이 — imessage

telegram·discord 는 채널 descriptor(`lib/channels.sh`)로 일반화돼 구동된다. 남은 채널은 imessage 다(README 「지원 게이트웨이」 표에 "예정"으로 예약).

- **무엇**: imessage 채널 descriptor(plugin ID·statedir_env·token 정책·seed 정책) 정의 + `add`/`up`/`status` 분기 일반화.
- **주의**: imessage 는 토큰이 없고 `chat.db` 에 의존하므로 `add` 의 토큰 입력·`.env` 시드 흐름이 채널별로 분기해야 한다(현재 `id_required`/`token_required`/`seed_policy` descriptor 축을 확장). 접근제어 모델도 다름.
- **규모**: 대형(별도 기능 차수 권장). 채널 "완전" 커버리지의 마지막 조각. 본 TODO 정리 시점 기준 미착수.

### (선택) lib/commands.sh 도메인 분할

`cc-tg.sh` → `lib/*.sh` 런타임 분리는 완료됐다(env/output/channels/config/util/registry/session/commands 8개 모듈). 잔여는 가장 큰 `lib/commands.sh`(~790줄)를 도메인별(lifecycle / config / registry-cmd 등)로 더 쪼갤지 여부다.

- **판단**: 현재 규모에서는 단일 파일이 탐색·테스트에 더 단순하다(명령군이 한곳). 명령 수가 더 늘거나 단일 파일이 유지보수 부담이 될 때 분할한다. **현재는 보류.**

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

### P3 — `claude_alive` comm 공백 경로 엣지

`claude_alive`(v0.5.1/006)는 `ps -ax -o pid=,ppid=,comm=` 출력을 awk 로 파싱해 3번째 필드(comm)를 본다. claude 실행 **경로에 공백**이 있으면(예: `/Users/me/My Tools/claude`) comm 이 여러 필드로 쪼개져 매칭이 깨질 수 있다 → false DEAD.

- **위치**: `lib/session.sh` `claude_alive` 의 awk 필드 분해.
- **현황**: 현실적으로 claude 경로에 공백은 드물어 수용된 엣지(decisions.md DEC-003 기록). 단 사용자 홈/도구 경로에 공백이 생길 여지는 있음.
- **수정 방향(선택)**: comm 대신 `command=`(전체 명령줄) 파싱 + 앵커 매칭, 또는 `ppid`/`pid` 만 awk 로 뽑고 comm 은 `ps -p <pid> -o comm=` 개별 조회. 우선순위 낮음.

## 테스트 커버리지 확장 (잔여)

`tests/` bats 스위트(201 테스트)는 등록·명령·라이프사이클(다중 타겟·실패 가드 포함)·스냅샷 watcher·가드 로직·텍스트/JSON status 를 격리 상태 트리 + stateful fake tmux + claude stub 으로 검증한다. 아직 안 덮은 경로:

- **`install.sh` / `uninstall.sh`** — 파일시스템·심볼릭·매니페스트 부수효과가 커서 별도 격리(HOME 샌드박스 + git 픽스처)가 필요. 현재 `bash -n`·shellcheck 만 적용. **위 "배포/운영" 의 update 롤백·doctor 심화와 함께 다룰 때 우선순위 상향 권장(P2).**
- **`attach` / `update`** — 인터랙티브·네트워크 의존이라 수동 검증 영역으로 남기는 것이 합리적(테스트 추가는 선택).
- **`launch` 문자열 내용 검증** — stub 이 세션 생성/종료는 추적하지만 `new-session` 명령 인자 본문(`--settings`·`--permission-mode`·`CLAUDE_EXTRA_ARGS` 주입)은 단언하지 않는다. stub 의 `FAKE_TMUX_LASTCMD` 기록을 활용해 확장 가능. 위 "P1 liveness" 검증 시 pane-명령 흉내와 함께 확장 가능.
