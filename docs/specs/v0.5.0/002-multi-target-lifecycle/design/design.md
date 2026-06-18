# design — 다중 타겟 라이프사이클 (direct 모드 통합 설계)

> 작성: 2026-06-18 13:12 / 버전: v0.5.0 / 최종 수정: 2026-06-18 13:12 / 상태: ACTIVE

## 목차

- [현재 구조](#현재-구조)
- [설계](#설계)
- [메시지(i18n)](#메시지i18n)
- [자동완성](#자동완성)
- [엣지 케이스](#엣지-케이스)
- [테스트 계획](#테스트-계획)

## 현재 구조

`lib/commands.sh` 의 `cmd_up`/`cmd_down`/`cmd_restart` 는 각각 `TARGET="${1:?...}"` 로 첫 인자만 처리하고, 내부에서 `is_reserved_name`→예약어 경로, `all`→`all_names` 전개, 그 외→`*_one`/`*_reserved` 로 분기한다. per-target 출력(`UP_OK`/`DOWN_OK`/`ALREADY_RUNNING`/`ERR_*`)은 `up_one`/`down_one`/`up_reserved`/`down_reserved`(lib/session.sh)가 담당하며, 각 함수는 성공 0 / 실패 비0 을 반환한다.

## 설계

세 명령의 분기 로직이 동일하므로 **공통 헬퍼 2개**로 추출(중복 제거, P-005 정신):

```sh
# 한 타겟에 action 적용 — 예약어/프로젝트 라우팅. 성공 0 / 실패 비0(피호출 함수 반환 전파).
_lifecycle_apply() {            # $1=action(up|down|restart) $2=name
  case "$1" in
    up)      if is_reserved_name "$2"; then up_reserved "$2"; else up_one "$2"; fi ;;
    down)    if is_reserved_name "$2"; then down_reserved "$2"; else down_one "$2"; fi ;;
    restart) if is_reserved_name "$2"; then down_reserved "$2"; up_reserved "$2"
             else down_one "$2"; up_one "$2"; fi ;;   # 성공=up 결과(기존 의미 보존)
  esac
}

# 다중 타겟 순차 처리 + continue-on-error + 요약. 전부 성공 0 / 하나라도 실패 1.
_lifecycle_run() {              # $1=action  $2..=targets
  local action="$1"; shift
  local ok=0 fail=0 failed="" arg n
  for arg in "$@"; do
    if [ "$arg" = all ]; then
      while IFS= read -r n; do [ -n "$n" ] || continue
        if _lifecycle_apply "$action" "$n"; then ok=$((ok+1)); else fail=$((fail+1)); failed="${failed:+$failed }$n"; fi
      done < <(all_names)
    else
      if _lifecycle_apply "$action" "$arg"; then ok=$((ok+1)); else fail=$((fail+1)); failed="${failed:+$failed }$arg"; fi
    fi
  done
  if [ $((ok+fail)) -ge 2 ]; then
    if [ "$fail" -eq 0 ]; then t MULTI_SUMMARY_OK "$action" "$ok"
    else t MULTI_SUMMARY_FAIL "$action" "$ok" "$fail" "$failed"; fi
  fi
  [ "$fail" -eq 0 ]
}

cmd_up()      { [ $# -ge 1 ] || { te ERR_NEED_TARGET; usage >&2; exit 1; }; _lifecycle_run up "$@"; }
cmd_down()    { [ $# -ge 1 ] || { te ERR_NEED_TARGET; usage >&2; exit 1; }; _lifecycle_run down "$@"; }
cmd_restart() { [ $# -ge 1 ] || { te ERR_NEED_TARGET; usage >&2; exit 1; }; _lifecycle_run restart "$@"; }
```

- 종료코드: `_lifecycle_run` 의 마지막 `[ "$fail" -eq 0 ]` 가 함수 반환값 → `cmd_*` 반환 → 디스패처(`cc-tg.sh` case)가 스크립트 종료코드로 전파.
- `all` 전개 시 각 봇을 1건으로 카운트(요약 정확도). 중복 인자/`all`+명시 중복은 `*_one` 이 already-running no-op 이라 무해(요약엔 중복 카운트될 수 있음 — 동작 안전, 표기상 경미).

## 메시지(i18n)

en/ko 동일 키 추가:

| 키 | en | ko |
|---|---|---|
| `ERR_NEED_TARGET` | `ERROR: needs at least one <name> or 'all'\n` | `오류: <이름> 또는 all 이 하나 이상 필요\n` |
| `MULTI_SUMMARY_OK` | `— %s: %d succeeded —\n` | `— %s: %d개 성공 —\n` |
| `MULTI_SUMMARY_FAIL` | `— %s: %d succeeded, %d failed (failed: %s) —\n` | `— %s: %d개 성공, %d개 실패 (실패: %s) —\n` |

`USAGE_UP`/`USAGE_DOWN`/`USAGE_RESTART` 의 `<name|all>`/`<이름|all>` → `<name...|all>`/`<이름...|all>`.

## 자동완성

- bash(`completions/cctg.bash`): up/down/restart 를 단일-이름 그룹(logs/attach/rm…)과 분리하여, `COMP_CWORD>=2` 모든 위치에서 `names + all + --help` 보완.
- zsh(`completions/_cctg`): up|down|restart 블록을 `(( CURRENT == 3 ))` → `(( CURRENT >= 3 ))` 로 확장.

## 엣지 케이스

- 타겟 0개 → `ERR_NEED_TARGET` + usage, 비0 (FR-007).
- `--help` 가 인자에 있으면 `cc-tg.sh` 선스캔이 usage 출력(기존 동작) — 다중 이름과 무관.
- restart 예약어/프로젝트 모두 `down; up` 순서이며 성공판정=up 결과(기존 의미 보존).
- 요약은 처리 건수 ≥2 일 때만 — 단일 타겟 출력 불변(FR-005/SC-005).

## 테스트 계획

`tests/up_down.bats` 에 SC-001~004·006 추가. fake tmux stub 기반(실제 tmux/세션 불침해 — `~/.claude/rules/on-demand/tmux.md`). 기존 단일 타겟 테스트로 SC-005 회귀 확인.
