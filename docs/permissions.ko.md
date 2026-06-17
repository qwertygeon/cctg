[English](permissions.md) | **한국어**

# 권한 정책

> CCTG 가 무해한 동작은 자동 승인하고 위험한 동작은 deny 로 차단하여, 헤드리스 봇이 권한 프롬프트에서 멈추지 않게 하는 방식.

## 목차

- [이 정책이 존재하는 이유](#이-정책이-존재하는-이유)
- [두 계층](#두-계층)
  - [주입 방식](#주입-방식)
  - [우선순위](#우선순위)
- [공통 설정 (모든 봇)](#공통-설정-모든-봇)
  - [기본 내용](#기본-내용)
  - [전역 settings.json 과의 병합](#전역-settingsjson-과의-병합)
  - [`cctg common` 서브커맨드](#cctg-common-서브커맨드)
- [봇별 설정](#봇별-설정)
  - [`cctg config <name>` 권한 항목](#cctg-config-name-권한-항목)
- [권한 모드](#권한-모드)
- [변경 적용](#변경-적용)
- [권장 구성](#권장-구성)

## 이 정책이 존재하는 이유

CCTG 봇은 tmux 안에서 대화형 Claude Code TUI 로 실행되지만, 운영자는 그 TUI 앞에 앉아 있지 않고 Telegram 또는 Discord 로만 상호작용한다. 따라서 권한 프롬프트가 나타나도 아무도 응답할 수 없어 봇이 멈춘다.

CCTG 의 모델은 "무해한 것은 자동 승인하고 위험한 것은 deny 로 차단한다" 이며, 이로써 프롬프트가 발생하는 회색 지대를 제거한다.

## 두 계층

| 계층 | 저장 위치 | 편집 커맨드 |
|---|---|---|
| 공통 (모든 봇) | `~/.claude/channels/cctg-shared.settings.json` | `cctg common ...` |
| 봇별 (우선 적용) | `~/.claude/channels/<name>/launch.env` | `cctg config <name> ...` |

### 주입 방식

`up`/`restart` 시 CCTG 는 각 봇을 공통 설정 파일을 `claude --settings <file>` 로 지정하여 기동하고, 그 위에 봇별 launch.env 를 덧입힌다.

```bash
caffeinate -is claude --channels <plugin> \
  --settings ~/.claude/channels/cctg-shared.settings.json \
  ${MODE_ARG} \
  ${CLAUDE_EXTRA_ARGS:-}
```

봇별 `launch.env` 는 기동 직전에 source 된다. 그곳에 `CCTG_PERMISSION_MODE` 가 설정되어 있으면 `--permission-mode <mode>` (`MODE_ARG`) 가 되고, 비어 있으면 `--permission-mode` 를 전달하지 않는다. `CLAUDE_EXTRA_ARGS` 는 추가 `claude` 인자로 그대로 덧붙는다.

### 우선순위

봇별 `CCTG_PERMISSION_MODE` 가 설정되어 있으면 (`--permission-mode` 를 통해) 공통 `defaultMode` 를 override 한다. 공통 값을 따르려면 비워 둔다.

공통 설정 파일 경로는 환경 변수 `CC_TG_SHARED_SETTINGS` 다 (기본값 `$CC_CHANNELS_DIR/cctg-shared.settings.json`, 여기서 `CC_CHANNELS_DIR` 의 기본값은 `~/.claude/channels`).

## 공통 설정 (모든 봇)

공통 설정 파일은 존재하지 않을 경우 최초 `add`/`up` 시 자동 생성된다.

### 기본 내용

```json
{
  "permissions": {
    "defaultMode": "bypassPermissions",
    "deny": [
      "Bash(sudo *)",
      "Bash(rm -rf /*)",
      "Bash(rm -rf ~*)",
      "Bash(rm -rf .*)",
      "Bash(git push --force*)",
      "Bash(git push -f*)",
      "Bash(git reset --hard*)",
      "Bash(git clean -fd*)",
      "Bash(git clean -fdx*)",
      "Read(~/.ssh/**)",
      "Read(~/.aws/**)"
    ],
    "allow": []
  }
}
```

### 전역 settings.json 과의 병합

이 파일은 전역 `~/.claude/settings.json` 의 deny 규칙·PreToolUse 훅과 병합된다. deny 는 union 이며 deny 가 allow 보다 우선한다. deny 규칙과 PreToolUse 훅(예: `git-guard`)은 `bypassPermissions` 에서도 그대로 작동하므로, 위험한 동작은 거기서 차단된다.

### `cctg common` 서브커맨드

```bash
cctg common                          # 현재 공통 설정 출력 (= common show)
cctg common edit                     # $EDITOR 로 직접 편집
cctg common mode acceptEdits         # 공통 defaultMode 변경
cctg common deny add 'Bash(sudo *)'  # deny 규칙 추가
cctg common deny rm  'Bash(sudo *)'  # deny 규칙 제거
cctg common allow add 'Read(/data/**)'   # allow 규칙 추가
cctg common allow rm  'Read(/data/**)'   # allow 규칙 제거
```

구조적 편집(`mode` / `deny` / `allow`)은 `jq` 가 필요하다. `jq` 가 없으면 `common edit` 을 사용한다. `show` 와 `edit` 은 `jq` 없이 동작한다. `deny`/`allow add` 는 중복 제거 집합(unique-set) union 을 사용하고, `rm` 은 정확히 일치하는 규칙을 제거한다.

## 봇별 설정

봇별 옵션은 `~/.claude/channels/<name>/launch.env` 에 있다. 관련 키는 `CCTG_PERMISSION_MODE` (이 봇의 권한 모드; 비우면 공통 값을 따름) 와 `CLAUDE_EXTRA_ARGS` (이 봇 전용 추가 `claude` 인자) 다.

### `cctg config <name>` 권한 항목

```bash
cctg config myproject                          # 보기 (채널, 모드, 스냅샷, launch.env)
cctg config myproject mode bypassPermissions   # 이 봇의 권한 모드 설정
cctg config myproject mode clear               # 해제 → 공통 값을 따름
cctg config myproject args "--model opus"      # 이 봇 전용 추가 claude 인자
cctg config myproject edit                     # launch.env 직접 편집
```

## 권한 모드

유효한 값: `acceptEdits | auto | bypassPermissions | default | dontAsk | plan`.

| 모드 | 헤드리스 봇 환경에서의 동작 |
|---|---|
| `bypassPermissions` | 모든 것을 자동 승인. deny 규칙과 PreToolUse 훅(git-guard 등)은 그대로 적용됨 → 위험한 동작은 여기서 차단된다. (CCTG 기본값) |
| `acceptEdits` | 편집과 안전한 fs 커맨드만 자동; 그 외 Bash/네트워크 동작은 프롬프트 발생 — 헤드리스에서 멈출 수 있다 |
| `dontAsk` | 회색 지대를 프롬프트 대신 자동 거부 (안전하지만, 동작이 `allow` 에 없으면 조용히 실패) |
| `default` / `auto` / `plan` | 표준 Claude Code 모드; `default`/`acceptEdits`/`plan` 은 프롬프트가 발생할 수 있어 헤드리스 봇을 멈출 수 있다 |

## 변경 적용

변경은 `up`/`restart` 시 반영된다 (봇이 이미 실행 중이면 `cctg restart <name>` 실행). 적용된 모드는 `cctg status` / `cctg doctor` 로 확인한다.

## 권장 구성

기본값 — 공통 `bypassPermissions` 와 deny 안전망, 봇별 모드는 비워 둠 — 이 헤드리스 봇의 의도된 기준선이다. 프롬프트가 발생하는 모드(`default`/`acceptEdits`/`plan`)로 전환하는 대신 deny 규칙을 추가하여 정책을 조인다. 그런 모드는 아무도 보고 있지 않은 봇을 멈출 수 있다.

---

[← README 로 돌아가기](../README.md)

함께 보기: [commands.ko.md](commands.ko.md), [configuration.ko.md](configuration.ko.md)
