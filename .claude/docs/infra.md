# Project Infra

> 작성: 2026-06-16 | 버전: 1.0 | 최종 수정: 2026-06-16 | 상태: 초안(사용자 검토 대기)
>
> 이 문서는 프로젝트의 **운영 수준 인프라 지식**을 기록하는 참조 문서다.
> 배포·환경 구성에 영향을 주는 spec 설계 전 반드시 읽어 운영 제약을 파악한다.
>
> - **갱신 시점**: 인프라 구성이 변경된 spec 완료 후 갱신한다.
> - **환경변수**: 봇 토큰 등은 상태 디렉터리 `.env` 로 관리한다. 이 문서에 실제 값을 기재하지 않는다.
> - **보안 원칙**: 실제 인증 정보(토큰·키)는 절대 기록하지 않는다.

---

## 1. 환경 구성

- dev/staging/prod 구분 없음. **사용자 로컬 macOS 머신 단일 환경**에서 실행되는 개발자용 CLI 도구다.
- 서버·클라우드 배포 대상 없음. "배포" = 사용자 머신에 설치(`install.sh`) + GitHub Release 발행.

## 2. 인프라 토폴로지

- **tmux 서버** 위에 봇당 세션 `cctg-<name>` 1개. 각 세션은 `caffeinate -is` 로 래핑된 `claude --channels plugin:telegram@claude-plugins-official` 프로세스 1개를 실행.
- 각 봇은 상태 디렉터리 `~/.claude/channels/<name>/`(토큰·allowlist·로그)와 작업 디렉터리(cwd)를 가진다.
- 공통 권한 설정 `cctg-shared.settings.json` 이 전 봇에 `--settings` 로 주입된다.
- 외부 의존: Telegram Bot API(플러그인이 통신), Claude Code 런타임. 컨테이너·DB·메시지 브로커 없음.

## 3. 배포 방식

- **설치**: `install.sh`
  - copy 모드(기본): 패키지를 `~/.local/libexec/cctg/`(cc-tg.sh + VERSION + messages)로 복사하고 `~/.local/bin/cctg` 심볼릭.
  - `--dev`/`--link` 모드: `~/.local/bin/cctg` 를 레포 `cc-tg.sh` 로 심볼릭(레포 편집 즉시 반영).
  - 완성 파일 복사 + 셸 rc 관리 블록(멱등) + 매니페스트(`~/.config/cctg/install.conf`) 기록. `--lang en|ko` 로 초기 언어 시드. `BINDIR=` 로 설치 위치 변경.
- **업데이트**: `cctg update` — 매니페스트의 repo·mode 로 `git pull --ff-only` 후 `install.sh` 재실행(전/후 버전 출력).
- **릴리스 발행(서버측 자동)**: `main` 에 `VERSION` 변경 push → `.github/workflows/release.yml` 이 게이트 재실행 → `v{VERSION}` 태그 → GitHub Release 발행(CHANGELOG 해당 섹션). 브랜치 정책·절차 SoT: `docs/RELEASING.md`.
- **하드웨어 요구사항**: 일반 macOS 개발 머신. 특별 요구 없음.
- **롤백**: 잘못된 릴리스는 태그/Release 재발행 또는 `cctg update` 로 이전 버전 설치(저장소 git 이력 기준).

## 4. 모니터링·로깅

- 실시간: `cctg attach`(tmux 세션), `cctg logs <name> [N]`(pane 또는 정지 시 `last-session.log` 폴백), `cctg status [--json]`(RUNNING/uptime/BROKEN + 복구 힌트).
- 스냅샷: `config <name> snapshot <초>` 활성 시 watcher 가 `last-session.log` 주기 갱신(crash/reboot 커버리지).
- 진단: `cctg doctor` — 의존성(tmux/claude/caffeinate/jq) 존재, PATH, 레지스트리/공통설정 상태 점검.

## 5. 연결 실패 재시도 동작

- CCTG 자체는 외부 연결 재시도 로직을 두지 않는다. Telegram API 연결·재시도는 Claude Code Telegram 플러그인 책임.
- tmux 세션/`claude` 프로세스가 비정상 종료하면 자동 재기동하지 않으며, `status` 에서 stopped/BROKEN 으로 표면화된다(사용자가 `up`/`restart`).

## 6. 로컬 개발 환경 / 테스트 실행 정책

- **의존성**: 런타임 — tmux, jq, `caffeinate`(macOS 기본), Claude Code CLI. 개발 — `shellcheck`, `bats`(`brew install bats-core`).
- **개발 설치**: `./install.sh --dev` (레포 심볼릭).
- **검증 명령**(CI 와 동일):
  ```bash
  for f in cc-tg.sh lib/*.sh install.sh uninstall.sh scripts/*.sh messages/*.sh; do bash -n "$f"; done
  shellcheck -S warning cc-tg.sh install.sh uninstall.sh scripts/*.sh   # .shellcheckrc: severity 는 -S 로, SC2207 disable, external-sources 로 lib/ 추종
  bash scripts/check-i18n-keys.sh
  bats tests/
  ```
- **테스트 실행 정책**: **로컬 자동 실행 가능**. `bats` 스위트는 격리 상태 트리(`HOME`/`XDG_CONFIG_HOME`/`CC_CHANNELS_DIR` 샌드박스) + stateful fake `tmux`(`tests/stubs/tmux`)로 실제 봇·tmux 서버에 무접촉. CI `test` 잡(main push/PR)에서도 실행. 별도 개발 서버 불필요.
  - 주의: 로컬 `bats`(1.x)와 CI 의 apt `bats` 가 테스트 중간 단언 실패 마스킹 동작이 다를 수 있다 — 단언은 마지막 명령에 의존하지 말고 독립 검증한다. (v0.2.0 `lang clear` 회귀 사례)

## 7. 배포 전 확인 체크리스트

- `git status` clean, `develop`/`main` 최신.
- CI green(lint+test).
- `VERSION` ↔ `CHANGELOG.md`(`[Unreleased]`→`[X.Y.Z]`) ↔ compare 링크 정합.
- 로컬 검증 명령(§6) 통과.
- 자세한 절차: `docs/RELEASING.md`.

## 8. 알려진 인프라 제약

| 항목 | 내용 | 영향 범위 | 관련 spec |
|---|---|---|---|
| macOS 한정 | `caffeinate` 등 macOS 의존 — Linux/WSL 미지원(의도된 범위) | 설치·기동 | — |
| 단일 게이트웨이 | Telegram 플러그인 하드코딩 | 기동 | (예정) 다중 게이트웨이 |
| 컨테이너/서버 부재 | Docker·서버 배포 없음. 사용자 머신 직접 실행 | 배포 | — |
| CI 트리거 범위 | `ci.yml` 는 `main` push/PR 에만 실행 — `develop` push 는 CI 미실행(검증은 develop→main PR 시점) | CI | — |
