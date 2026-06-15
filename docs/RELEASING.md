# CCTG 릴리스 가이드

> 버전 올리기부터 GitHub Release 발행까지의 표준 절차. `VERSION` 파일이 버전의 SoT 이며, git 태그·CHANGELOG·릴리스 노트가 이를 따른다.

## 목차

- [사전 조건](#사전-조건)
- [버전 규약 (SemVer)](#버전-규약-semver)
- [릴리스 절차](#릴리스-절차)
  - [1. 버전·CHANGELOG 갱신](#1-버전changelog-갱신)
  - [2. 커밋](#2-커밋)
  - [3. 태그 생성](#3-태그-생성)
  - [4. 푸시](#4-푸시)
  - [5. GitHub Release 발행](#5-github-release-발행)
- [CI 게이트](#ci-게이트)
- [사용자 업데이트 경로](#사용자-업데이트-경로)

## 사전 조건

- `main` 브랜치가 깨끗하고(`git status`) 최신인지 확인한다.
- 로컬 검증을 통과해야 한다 (CI 와 동일):
  ```bash
  for f in cc-tg.sh install.sh uninstall.sh scripts/*.sh messages/*.sh; do bash -n "$f"; done
  shellcheck -S warning cc-tg.sh install.sh uninstall.sh scripts/*.sh
  bash scripts/check-i18n-keys.sh
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

### 1. 버전·CHANGELOG 갱신

- `VERSION` 파일을 새 버전으로 수정한다 (SoT). `cctg version` 출력으로 확인.
- `CHANGELOG.md` 의 `[Unreleased]` 누적분을 `[X.Y.Z] - YYYY-MM-DD` 섹션으로 확정하고, 새 빈 `[Unreleased]` 를 추가한다.
- 하단 compare 링크를 갱신한다:
  ```
  [Unreleased]: https://github.com/qwertygeon/cctg/compare/vX.Y.Z...HEAD
  [X.Y.Z]: https://github.com/qwertygeon/cctg/compare/v{PREV}...vX.Y.Z
  ```

### 2. 커밋

```bash
git add VERSION CHANGELOG.md
git commit -m "[chore] release vX.Y.Z"
```

### 3. 태그 생성

annotated 태그를 권장한다 (날짜·작성자 메타데이터 보존):

```bash
git tag -a vX.Y.Z -m "vX.Y.Z"
```

### 4. 푸시

태그는 자동으로 따라가지 않으므로 별도 푸시한다:

```bash
git push origin main
git push origin vX.Y.Z
# 또는 한 번에: git push --follow-tags
```

### 5. GitHub Release 발행

**A. 웹 UI**

1. `https://github.com/qwertygeon/cctg/releases` → **Draft a new release**
2. **Choose a tag** → `vX.Y.Z` (4단계에서 푸시한 태그)
3. **Release title**: `vX.Y.Z`
4. 본문: `CHANGELOG.md` 의 `## [X.Y.Z]` 섹션을 붙여넣는다.
5. **Publish release**

**B. gh CLI**

```bash
# 최초 1회: brew install gh && gh auth login
gh release create vX.Y.Z --title "vX.Y.Z" \
  --notes "$(awk '/^## \[X.Y.Z\]/{f=1;next} /^## \[/{f=0} f' CHANGELOG.md)"
```

## CI 게이트

`.github/workflows/ci.yml` 가 `push`/`pull_request`(main) 에서 자동 실행된다:

- `bash -n` — 전 셸 스크립트 구문 검사
- `shellcheck -S warning` — 로직 스크립트(`cc-tg.sh`·`install.sh`·`uninstall.sh`·`scripts/*.sh`) 정적 분석
- `scripts/check-i18n-keys.sh` — 메시지 카탈로그 키 패리티·참조 키 검증

> `messages/*.sh` 는 `t()` 가 eval 로 소비하는 데이터 카탈로그(SC2034 다수)라 shellcheck 대상에서 제외하고 i18n 린트로 검증한다. `completions/*` 는 `COMPREPLY=( $(compgen ...) )` 관용구(SC2207)가 본질적이라 정적 분석 대상에서 제외한다.

릴리스 전 CI 가 green 인지 확인한다.

## 사용자 업데이트 경로

릴리스 후 기존 사용자는 `cctg update` 로 받는다 — 매니페스트(`~/.config/cctg/install.conf`)의 repo·mode 를 읽어 `git pull --ff-only` 후 `install.sh` 를 재실행하고, 전/후 버전을 함께 출력한다. copy 설치는 새 `cc-tg.sh`·`VERSION`·`messages/` 를 libexec 로 재복사하고, `--dev`(심볼릭) 설치는 `git pull` 즉시 반영되며 자동완성만 재복사한다.
