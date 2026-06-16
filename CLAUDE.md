# CCTG — 프로젝트 절대 원칙

이 파일은 cctg 작업 세션마다 항상 로드된다. 아래는 **이 프로젝트에서 예외 없이 지키는 절대 원칙**이다.

## Git 변경 사용자 확인 (최우선 절대 원칙)

> **[MUST] git/gh "변경" 동작은 실행 전에 반드시 사용자에게 알리고 명시적 확인을 받은 뒤에만 수행한다.**

- 대상: working tree · index · HEAD · stash · branch · tag 중 하나라도 바꾸는 모든 git 명령
  (`git add`, `git commit`, `git push`, `git tag`, `git stash`, `git reset`, `git checkout`(변경),
  `git rebase`, `git merge`, `git cherry-pick`, `git revert`, `git restore`, `git clean`),
  그리고 외부 발행·상태 변경 `gh` 명령(`gh pr create/merge`, `gh release create/edit`,
  `gh issue create/close` 등).
- **확인 절차**: 실행 직전 (1) 실행할 **정확한 명령**과 (2) **무엇을 왜** 하려는지를 사용자에게 보여주고,
  사용자의 **명시적 승인**을 받은 뒤에만 실행한다. 승인 없이 자동 실행하지 않는다.
- **포괄 위임 무효**: "알아서 커밋해", "대충 해줘" 같은 포괄적·사전적 위임이 있어도
  **매 커밋·푸시·태그 시점마다** 명령을 보여주고 그 건의 확인을 받는다.
  단, 사용자가 특정 명령을 직접 "이거 실행해"라고 지목하면 그 건은 승인으로 간주한다.

### 이 규칙이 allowlist 자동 허용을 의도적으로 덮는다

이 프로젝트는 `~/.claude/git-autonomy.allowlist` 에 `git,gh` 로 등재되어 있어
`git-guard.sh` 훅이 git/gh 변경을 자동 허용(`allow`)한다. **그럼에도 본 규칙이 우선한다.**
allowlist 등재는 "훅이 차단하지 않는다"는 의미일 뿐, **에이전트가 사용자 확인 없이 실행해도 된다는 뜻이 아니다.**
훅이 통과시키더라도 에이전트는 위 확인 절차를 **반드시** 거친다. (전역 기본값보다 이 프로젝트 규칙이 우선)

### 예외 (확인 불필요 / 항상 금지)

- **확인 불필요 (자유 실행)**: read-only 조회 — `git status`, `git diff`, `git log`, `git show`,
  `git branch`(조회), `git rev-parse`, `git remote -v`, `gh ... view/list/status/checks` 등.
- **항상 금지 (대행 불가)**: 파괴적 명령 — `git push --force/-f`, `git reset --hard`, `git clean -fd[x]`.
  훅이 항상 차단하며, 에이전트는 대행하지 않는다. 필요하면 사용자가 직접 실행한다.

## 릴리스·CI 자동화 경계

- **릴리스 발행은 자동화되어 있다.** `main` 에 `VERSION` 변경이 push 되면
  `.github/workflows/release.yml` 이 GitHub Actions(서버측, `github.token`)에서
  태그 생성·GitHub Release 발행을 수행한다. 이는 **서버측 자동화**이며 위 로컬 git 확인 정책과 별개다.
  → "로컬 작업은 사용자 확인, 릴리스 발행은 CI가 자동" 으로 책임이 분리된다.
- 로컬에서 태그·릴리스를 수동 발행하는 경우(폴백)에도 위 **Git 변경 사용자 확인** 규칙이 그대로 적용된다.
- 브랜치 정책(`feature/* → develop → PR → main → 자동 태그`)의 SoT 는 [docs/RELEASING.md](docs/RELEASING.md).

## 프로젝트 문서 (.claude/docs/)

설계·구현·검증 전 아래 프로젝트 문서를 참조한다 (SDD 파이프라인이 단계별로 읽는다).

- [constitution.md](.claude/docs/constitution.md) — 프로젝트 불변 원칙(macOS/Bash 3.2, 안전, 시크릿, git 확인, 최소 표면). 전역 규칙과 충돌 시 우선.
- [context.md](.claude/docs/context.md) — 현재 구조·흐름·도메인 용어·알려진 제약. 새 spec 설계 전 필독.
- [infra.md](.claude/docs/infra.md) — 환경·배포(install/릴리스)·테스트 실행 정책·운영 제약.

## 참조

- 전역 git 규칙: `~/.claude/rules/on-demand/git.md`
- 자동화 경계(allowlist) SoT: `~/.claude/git-autonomy.allowlist`
- 기여·커밋 컨벤션: [CONTRIBUTING.md](CONTRIBUTING.md)
- 릴리스 절차: [docs/RELEASING.md](docs/RELEASING.md)
