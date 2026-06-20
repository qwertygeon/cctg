# decisions — v0.6.0/003-defensive-hardening

> 비자명 결정의 append-only 로그 (direct 모드, main session 기록).

## DEC-001 — set_env_kv 멀티라인 손상: `config args` 개행 거부 (review correctness #1)

- **맥락**: `set_env_kv` 치환 분기는 awk `^KEY=` 로 **첫 물리 줄만** 매칭한다. 새 `shq()` 가 개행을 멀티라인 단일따옴표 토큰으로 충실히 보존하므로, 멀티라인 값을 재설정하면 옛 값의 연속 줄이 고아로 남아 `launch.env` 가 `source` 실패(봇 기동 불가). 도달: `cctg config <bot> args $'--a\n--b'` 후 재설정.
- **선택지**: (a) 치환 분기가 논리 엔트리 전체(연속 줄 포함)를 삭제하도록 재작성, (b) `config args` 입력에서 개행을 거부(launch.env 는 줄 단위 KEY=value 이고 CLAUDE_EXTRA_ARGS 의 실사용은 단일 줄).
- **결정**: **(b)** — 개행이 든 값은 애초에 저장되지 않게 입력 시점에 거부한다. 더 단순하고 CLAUDE_EXTRA_ARGS 의 실사용(공백 구분 단일 줄 인자)과 정합. 멀티라인 인자가 필요하면 `cctg config <bot> edit` 로 직접 편집(파일 단위 쓰기).
- **영향**: `cctg config <name> args` 값에 개행 포함 시 `ERR_CONFIG_ARGS_NEWLINE` 로 거부(신규 메시지 en/ko). 단일 줄 args(일반 경로) 불변.

## DEC-002 — 검토분석 17건 적용/보류 범위

- **적용(코드)**: set_env_kv 개행 거부(DEC-001) · doctor `.env` perm 빈값 가드 · last-activity 음수 클램프(텍스트) · `write_atomic`/`write_token_env` no-slash dir 폴백.
- **적용(테스트)**: doctor manifest OK/badpath/bindir 분기 · shq 작은따옴표 e2e · reserved 봇 last-activity · write_atomic residue/registry 보존 · set_env_kv 치환 라운드트립 · status DEAD-state last-activity · status_json last-activity 결정적 값.
- **적용(문서)**: TODO 테스트 수·commands.sh 줄 수 갱신.
- **보류**: scope.md CUT-001 참조.
