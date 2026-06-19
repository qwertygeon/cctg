---
작성: 2026-06-19 13:36
버전: 0.6.0
최종 수정: 2026-06-19 13:36
상태: 확정
---

# decisions.md — 결정 기록 (session-width-config)

## DEC-001 — 버전 폴더 v0.6.0

- **결정**: 본 작업을 `docs/specs/v0.6.0/001-session-width-config` 에 배치한다.
- **근거**: VERSION=0.5.1 은 방금 릴리스됨(태그 v0.5.1 존재, CHANGELOG 확정). 새 명령/설정 추가 =
  하위호환 기능 추가 → docs/RELEASING.md SemVer 규약상 MINOR. 사용자가 옵션 1(v0.6.0) 선택.
- **확인**: 사용자 (Discord 2026-06-19).

## DEC-002 — 미설정 시 기본 폭 = 100

- **결정**: 아무 설정도 없을 때 detached 세션 폭 기본값을 기존 200 에서 **100** 으로 변경한다.
- **근거**: 사용자 지정(80 제안 → 100 확정). 200→100 은 동작 변경 — `logs`/snapshot 캡처 폭이
  좁아질 수 있음을 사용자에게 고지함(detached 기본 80 대비로는 여전히 넓음).
- **확인**: 사용자 (Discord 2026-06-19).

## DEC-003 — 전역 기본값 저장 위치·명령

- **결정**: 전역 기본 폭은 `~/.config/cctg/config`(CCTG_CONFIG, `lang` 과 동거) 의 `sess_width`
  키에 저장하고 `cctg common width <cols|clear>` 로 편집한다. **공통 권한 JSON(SHARED_SETTINGS)
  에는 넣지 않는다** — 폭은 Claude 권한 설정이 아니라 cctg 수준 설정이므로.
- **근거**: 사용자가 "config, common 에 추가" 요청. common(전역)·config(봇별) 양면 제공.
  `cctg common` 의 기존 권한 JSON 편집과 저장소를 분리해 의미 충돌 방지(lang 패턴 재사용).
- **확인**: 사용자 요청 해석 + 설계 판단.

## DEC-004 — 봇별 오버라이드·삭제

- **결정**: 봇별 폭은 `cctg config <name> width <cols|clear>` 로 설정하며 launch.env 의
  `CCTG_SESS_WIDTH` 키에 저장한다. `clear`(또는 `default`) 로 삭제하면 전역 기본값을 따른다.
- **근거**: 기존 `CCTG_LOG_SNAPSHOT_INTERVAL`(snapshot) 노브와 동형 패턴.

## DEC-005 — 유효 폭 해석 우선순위 + 검증

- **결정**: 유효 폭 = `effective_sess_width(sd)` 가 다음 순으로 해석한다.
  1. 봇별 `launch.env` `CCTG_SESS_WIDTH`
  2. env `CC_TG_SESS_WIDTH`
  3. 전역 config `sess_width` (`cctg common width`)
  4. 기본 `SESS_WIDTH_DEFAULT`(100)
  각 후보는 `valid_width()`(양의 정수 ∧ ≥20)를 통과해야 채택, 아니면 다음 후보.
- **근거**: env > config 우선순위는 `lang` 해석(CCTG_LANG > config lang)과 동형. 하한 20 은
  tmux 가 거부할 비정상값·오타를 set 시점에 차단(snapshot 의 ≥5 검증과 동류).
