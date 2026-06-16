# CCTG 릴리스 가이드

> 버전 올리기부터 GitHub Release 발행까지의 표준 절차. `VERSION` 파일이 버전의 SoT 이며, git 태그·CHANGELOG·릴리스 노트가 이를 따른다. `main` 에 VERSION 변경이 들어오면 GitHub Actions 가 태그 생성·Release 발행을 **자동** 처리한다.

## 목차

- [브랜치 정책](#브랜치-정책)
- [사전 조건](#사전-조건)
- [버전 규약 (SemVer)](#버전-규약-semver)
- [릴리스 절차](#릴리스-절차)
  - [1. 릴리스 브랜치에서 버전·CHANGELOG 갱신](#1-릴리스-브랜치에서-버전changelog-갱신)
  - [2. develop → main PR·머지](#2-develop--main-pr머지)
  - [3. 자동 발행 (release.yml)](#3-자동-발행-releaseyml)
- [CI 게이트](#ci-게이트)
- [수동 발행 (폴백)](#수동-발행-폴백)
- [사용자 업데이트 경로](#사용자-업데이트-경로)

## 브랜치 정책

2단계 통합 모델을 따른다.

| 브랜치 | 역할 | 받는 입력 |
|---|---|---|
| `feature/*`, `fix/*` | 개별 작업 | 로컬에서 분기 |
| `develop` | 통합 브랜치 (다음 릴리스 누적) | `feature/*` → PR |
| `main` | 릴리스 가능 상태 (항상 배포 가능) | `develop` → PR |
| 태그 `vX.Y.Z` | 릴리스 시점 고정 | `main` push 시 자동 생성 |

- 일상 작업은 `develop` 에서 분기해 `develop` 으로 PR 한다.
- `main` 직접 push 하지 않는다. `main` 은 `develop` 으로부터의 PR 로만 갱신한다.
- `main` 에 VERSION 변경이 도달하는 순간이 곧 릴리스 트리거다 (아래 [3](#3-자동-발행-releaseyml)).
- **브랜치 보호 전제**: `release.yml` 은 `main` push *후* 게이트를 실행하므로, 잘못된 VERSION bump 가 `main` 에 먼저 들어가는 것을 워크플로만으로는 막지 못한다. repo Settings → Branches 에서 `main` 에 "Require a pull request before merging" + "Require status checks to pass (CI)" 보호 규칙을 활성화하여 PR·CI 통과를 강제한다 — 이것이 실질 방어선이다.
- 커밋 메시지는 `[type] 요약` 규약을 따른다 (`feat`/`fix`/`docs`/`refactor`/`test`/`chore`). 상세는 [CONTRIBUTING.md](../CONTRIBUTING.md).

## 사전 조건

- 릴리스 대상 변경이 `develop` 에 모두 통합되어 있고 CI 가 green 인지 확인한다.
- 로컬 검증을 통과해야 한다 (CI·release 게이트와 동일):
  ```bash
  for f in cc-tg.sh lib/*.sh install.sh uninstall.sh scripts/*.sh messages/*.sh; do bash -n "$f"; done
  shellcheck -S warning cc-tg.sh install.sh uninstall.sh scripts/*.sh
  bash scripts/check-i18n-keys.sh
  bats tests/
  ```

## 버전 규약 (SemVer)

`MAJOR.MINOR.PATCH` ([SemVer](https://semver.org/spec/v2.0.0.html)) 를 따른다.

| 변경 성격 | 올릴 자리 | 예 |
|---|---|---|
| 호환 깨지는 변경 (명령·경로·동작 비호환) | MAJOR | 1.x → 2.0.0 |
| 하위호환 기능 추가 | MINOR | 0.1.x → 0.2.0 |
| 하위호환 버그 수정·방어코드·문서 | PATCH | 0.1.0 → 0.1.1 |

태그명은 `v` 접두사를 붙여 `v{VERSION}` 형식으로 만들며 `VERSION` 파일값과 일치시킨다.

## 릴리스 절차

### 1. 릴리스 브랜치에서 버전·CHANGELOG 갱신

`develop` 에서 릴리스 준비 브랜치를 분기하거나 `develop` 에 직접 다음을 반영한다:

- `VERSION` 파일을 새 버전으로 수정한다 (SoT). `cctg version` 출력으로 확인.
- `CHANGELOG.md` 의 `[Unreleased]` 누적분을 `[X.Y.Z] - YYYY-MM-DD` 섹션으로 확정하고, 새 빈 `[Unreleased]` 를 추가한다. (release.yml 이 이 `## [X.Y.Z]` 섹션을 릴리스 노트로 추출한다.)
- 하단 compare 링크를 갱신한다:
  ```
  [Unreleased]: https://github.com/qwertygeon/cctg/compare/vX.Y.Z...HEAD
  [X.Y.Z]: https://github.com/qwertygeon/cctg/compare/v{PREV}...vX.Y.Z
  ```

### 2. develop → main PR·머지

```bash
# develop 푸시 후 GitHub UI 또는 gh 로 PR 생성
gh pr create --base main --head develop --title "release vX.Y.Z" --fill
```

PR 의 CI 가 green 인지 확인하고 `main` 으로 머지한다. **VERSION 변경이 `main` 에 도달하는 것이 트리거**다.

### 3. 자동 발행 (release.yml)

`main` 에 VERSION 변경이 push 되면 `.github/workflows/release.yml` 이 자동 실행된다:

1. `VERSION` 을 읽어 `v{VERSION}` 태그가 이미 있는지 확인 (있으면 멱등하게 종료).
2. CI 와 동일한 게이트 재실행 (`bash -n` · `shellcheck` · i18n · `bats`).
3. `CHANGELOG.md` 의 `## [X.Y.Z]` 섹션을 릴리스 노트로 추출 (없으면 자동 생성 노트로 폴백).
4. `v{VERSION}` annotated 태그 생성·push.
5. `gh release create` 로 GitHub Release 발행.

> 별도 수동 태그·발행 단계는 필요 없다. VERSION 을 올리지 않은 일반 변경은 트리거되지 않으며, 같은 버전 재-push 는 태그가 이미 존재하므로 건너뛴다.

## CI 게이트

`.github/workflows/ci.yml` 가 `push`/`pull_request`(main) 에서 자동 실행된다:

- `bash -n` — 전 셸 스크립트 구문 검사
- `shellcheck -S warning` — 로직 스크립트(`cc-tg.sh`·`install.sh`·`uninstall.sh`·`scripts/*.sh`) 정적 분석
- `scripts/check-i18n-keys.sh` — 메시지 카탈로그 키 패리티·참조 키 검증
- `bats tests/` — 명령 동작 테스트 스위트

`release.yml` 은 발행 직전 동일 게이트를 한 번 더 실행하여 잘못된 VERSION bump 가 깨진 릴리스로 나가지 않게 한다.

> `messages/*.sh` 는 `t()` 가 eval 로 소비하는 데이터 카탈로그(SC2034 다수)라 shellcheck 대상에서 제외하고 i18n 린트로 검증한다. `completions/*` 는 `COMPREPLY=( $(compgen ...) )` 관용구(SC2207)가 본질적이라 정적 분석 대상에서 제외한다.

## 수동 발행 (폴백)

자동 발행이 실패했거나(게이트 실패·노트 추출 실패) 핫픽스로 특정 태그를 직접 발행해야 할 때:

```bash
# main 최신 상태에서
git tag -a vX.Y.Z -m "vX.Y.Z"
git push origin vX.Y.Z
gh release create vX.Y.Z --title "vX.Y.Z" \
  --notes "$(awk '/^## \[X.Y.Z\]/{f=1;next} /^## \[/{f=0} f' CHANGELOG.md)"
```

태그가 이미 push 된 상태라면 `gh release create` 만 실행한다.

## 사용자 업데이트 경로

릴리스 후 기존 사용자는 `cctg update` 로 받는다 — 매니페스트(`~/.config/cctg/install.conf`)의 repo·mode 를 읽어 `git pull --ff-only` 후 `install.sh` 를 재실행하고, 전/후 버전을 함께 출력한다. copy 설치는 새 `cc-tg.sh`·`VERSION`·`messages/` 를 libexec 로 재복사하고, `--dev`(심볼릭) 설치는 `git pull` 즉시 반영되며 자동완성만 재복사한다.
