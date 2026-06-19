---
작성: 2026-06-19 13:36
버전: 0.6.0
최종 수정: 2026-06-19 13:55
상태: 확정
---

# CHANGES.md — 사용자 설정 가능한 detached 세션 폭

## 목차

- [무엇을·왜](#무엇을왜)
- [변경 파일](#변경-파일)
- [동작·우선순위](#동작우선순위)
- [테스트 결과](#테스트-결과)

## 무엇을·왜

detached tmux 세션의 폭(`new-session -x`, logs/snapshot 캡처가 80폭으로 잘리는 것 방지)을
하드코딩 전역값(200, env override only)에서 **2계층 사용자 설정**으로 전환한다.

- 봇별: `cctg config <name> width <칼럼|clear>` → launch.env `CCTG_SESS_WIDTH`.
- 전역: `cctg common width <칼럼|clear>` → `~/.config/cctg/config` `sess_width`
  (권한 JSON 아님 — 폭은 권한이 아니므로, DEC-003).
- 미설정 기본값 200 → **100** (DEC-002, 동작 변경).

## 변경 파일

| 파일 | 변경 |
|---|---|
| `lib/env.sh` | `SESS_WIDTH` 제거 → `SESS_WIDTH_DEFAULT=100` 상수 |
| `lib/util.sh` | `valid_width()` 추가 (정수 ∧ ≥20) |
| `lib/config.sh` | `sess_width_of()`·`effective_sess_width()` 추가 |
| `lib/session.sh` | `start_session` 3번째 인자(폭) 수용; `up_one`/`up_reserved` 가 `effective_sess_width` 전달 |
| `lib/commands.sh` | `cmd_config` `width)` 액션 + show + launch.env 템플릿 2곳; `cmd_common` `width)` 액션 + show |
| `messages/{en,ko}.sh` | CFG/COMMON width 메시지·usage 키 추가 |
| `completions/{_cctg,cctg.bash}` | config·common 에 `width` 완성 추가 |
| `tests/{config,common,up_down}.bats`, `test_helper.bash` | width 테스트 13건 + 기본값 200→100 갱신 + `CC_TG_SESS_WIDTH` unset |
| `docs/{commands,configuration}{,.ko}.md`, `CHANGELOG.md` | 문서·체인지로그 |

## 동작·우선순위

`effective_sess_width(sd)` 해석(첫 유효값 채택, 각 후보 `valid_width` 통과 필요):
봇별 `CCTG_SESS_WIDTH` → env `CC_TG_SESS_WIDTH` → 전역 `sess_width` → `SESS_WIDTH_DEFAULT`(100).

비정상값(비정수·<20)은 set 시점에 `ERR_BAD_WIDTH` 로 거부, 해석 시점엔 다음 후보로 폴백.

## 테스트 결과

- `shellcheck -S warning` : 0 (clean)
- `bats tests/` : 214/214 PASS (신규 width 13건 포함, 기존 201 무회귀)
- 수동 스모크: `common width 160/clear`, `common show` 출처 표기, 잘못된 값 거부 확인.
