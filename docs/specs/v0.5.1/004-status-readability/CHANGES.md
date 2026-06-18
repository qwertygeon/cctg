# CHANGES — v0.5.1/004-status-readability (출력 경로 시인성)

> 작성: 2026-06-18 16:58 | 버전: 1.1 | 최종 수정: 2026-06-18 17:10 | 상태: 완료(검증 통과)
>
> v1.1: status 외 전체 명령 출력 시인성 검토(사용자 요청)에 따라 범위 확장 — `up` 성공 블록 분리, `add`/`rm`/`rename`/`config`/`doctor`/`up` 에러힌트 경로 `~` 전면 적용(Finding 1~4).

## 목차

- [요약](#요약)
- [변경 내용 (B + C)](#변경-내용-b--c)
- [Before / After](#before--after)
- [변경 파일](#변경-파일)
- [검증 결과](#검증-결과)
- [영향 범위](#영향-범위)

## 요약

`cctg status` 텍스트 출력에서 `cwd`·`state` 가 한 줄에 묶여 긴 절대경로로 줄바꿈·시인성이 나빴다. **B(라벨 정렬 컬럼) + C(홈경로 `~` 축약)** 로 개선했다. 표시 전용 변경이며 `status --json` 은 불변.

## 변경 내용 (B + C)

- **B — 라벨 정렬 컬럼**: `cwd`/`state` 를 별도 줄로 분리하고 `mode`/`channel` 과 함께 라벨을 좌측 정렬해 값이 같은 열에서 시작하도록 했다(en 8칸 / ko 9 디스플레이칸 — 한글 2열 가정). `STATUS_PATHS`·`STATUS_MODE`·`STATUS_CHANNEL`·`STATUS_CHANNEL_TOPO` 템플릿에서 `=` 라벨을 정렬 라벨로 교체.
- **C — 홈경로 `~` 축약**: `lib/registry.sh` 에 표시 전용 `tilde()`(=`expand()` 의 역) 추가. `cmd_status` 가 `cwd`/`state` 를 출력 전 `tilde()` 로 감싼다. `$HOME` 접두만 `~` 로 축약하고 그 외(예: 미상 `—`)는 그대로 둔다.

## Before / After

```
# Before
  [stopped] tgbot
            cwd=/Users/you/work/myproject  state=/Users/you/.claude/channels/tgbot
            mode=shared
            channel=Telegram (allowlist, 0 groups)

# After
  [stopped] tgbot
            cwd     ~/work/myproject
            state   ~/.claude/channels/tgbot
            mode    shared
            channel Telegram (allowlist, 0 groups)
```

## 전체 명령 검토 결과 (Finding 1~4, 전부 적용)

- **F1 (up)**: `UP_OK` 가 cwd+state+tmux 를 한 괄호 줄에 cram → status 와 동일하게 `cwd`/`state`/`tmux` 분리+정렬 블록 + `~` 축약.
- **F2 (add)**: `ADD_DONE` 의 cwd/state 를 `~` 축약(tilde).
- **F3 (전면 `~` 일관성)**: `tilde()` 를 경로 출력 전반에 적용 — `RM_PURGE_*`/`RM_KEEP`, `RENAME_MOVED/KEPT`/`ERR_TARGET_EXISTS`/`ERR_MOVE_FAILED`, `ERR_NO_CWD`/`ERR_NO_TOKEN`(up/up_reserved), `CFG_SHOW_HEADER`(launch.env), `ERR_NO_SUCH_DIR`/`CFG_CWD_SET`(config cwd), `STATUS_HINT_NO_CWD`/`NO_TOKEN`, `DOCTOR_FILE`(registry·shared settings).
- **F4 (정렬)**: `RESERVED_UP` 접두 `UP ` → `UP   `(UP_OK/DOWN 과 정렬).
- **양호(불변)**: `doctor` 섹션 구조·`config show`/`common show`·usage/help.

## 변경 파일

- `lib/registry.sh` — `tilde()` 헬퍼(표시용 `$HOME`→`~`).
- `lib/commands.sh` — `STATUS_PATHS`(status 2곳)·`ADD_DONE`·`RM_*`·`RENAME_*`/move 에러·`CFG_SHOW_HEADER`·config cwd·`STATUS_HINT_*`·`DOCTOR_FILE` 경로 인자 `tilde()` 래핑.
- `lib/session.sh` — `UP_OK`(tilde) · `ERR_NO_CWD`/`ERR_NO_TOKEN`(up/up_reserved, tilde).
- `messages/en.sh`·`ko.sh` — `STATUS_PATHS`(분리+정렬)·`STATUS_MODE`·`STATUS_CHANNEL`(+TOPO) 정렬, `UP_OK`(분리 블록), `RESERVED_UP`(정렬).
- `tests/status_view.bats`(+2)·`tests/up_down.bats`(+1, UP_OK ~/분리).
- `CHANGELOG.md` — [Unreleased] Changed 1건(확장).

## 검증 결과

- `bats tests/*.bats`: **185/185 PASS**(신규 3: status 분리·`~`, up 분리·`~`, 회귀 0)
- `scripts/check-i18n-keys.sh`: PASS (en/ko 패리티, 167 키 — 신규 키 없음, 템플릿 값만 변경)
- `bash -n`·`shellcheck -S warning`(CI 동일): **EXIT 0**
- 격리 env 렌더로 정렬·`~` 축약 시각 확인.

## 영향 범위

- **텍스트 `status` 전용**. `status --json`(machine-readable)은 별도 경로로 불변.
- 신규 메시지 키 없음(기존 4키 템플릿 값만 변경) → i18n 키 수 불변(167).
- `status_view.bats` 기존 단언(부분 문자열: Telegram/Discord/pairing/groups)은 형식 변경에 영향 없음.
- ko 정렬은 한글 2-열 폭 가정 — 대부분의 모노스페이스 폰트에서 정렬되며, 폰트별 미세 차이가 있어도 줄 분리·`~` 축약의 가독성 이득은 유지.
