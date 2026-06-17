[001-cli-convenience-patches] 구현 완료

변경 파일:
- cc-tg.sh: 서브커맨드 --help/-h 선검사 블록 추가 (FR-005 / ADR-005)
- lib/commands.sh: cmd_config() 에 cwd·token 액션 추가 (FR-001/002), cmd_up/down/restart 에 예약어 라우팅 추가 (FR-006/007/008), cmd_status() 에 예약어 전역 봇 섹션 추가 (FR-009), cmd_logs() 에 예약어 분기 추가 (FR-010)
- lib/registry.sh: set_registry_cwd() 함수 추가 — cwd 원자적 갱신 (FR-001 / NFR-005)
- lib/session.sh: reserved_runner_alive()·up_reserved()·down_reserved() 함수 추가 (FR-006/007)
- lib/util.sh: sub_usage() 함수 추가 — 서브커맨드별 --help 출력 (FR-005)
- completions/_cctg: config 액션에 cwd·token 추가 (FR-004), mode 값 목록 추가 (FR-003), 서브커맨드 --help 추가 (FR-005)
- completions/cctg.bash: config 액션에 cwd·token 추가 (FR-004), mode 값 목록 추가 (FR-003), 서브커맨드 --help 추가 (FR-005)
- messages/en.sh: CFG_CWD_SET·ERR_CONFIG_CWD_USAGE·ERR_NO_SUCH_DIR·CFG_TOKEN_SET·ERR_CONFIG_TOKEN_USAGE·RESERVED_UP·ERR_RESERVED_UP_OCCUPIED·ERR_RESERVED_UP_RUNNER·ERR_RESERVED_UNSUPPORTED·RESERVED_DOWN_NONE·STATUS_RESERVED_HEADER·USAGE_ADD~USAGE_HELP 16종 키 추가 (NFR-007)
- messages/ko.sh: en.sh 와 동일 키 추가 — 한국어 번역 (NFR-007)

후속 작업 시 주의사항:
- context.md §5 예약어 정의: telegram/discord 에 대해 up/down/restart/status/logs 가 이제 허용된다. 현재 §5 의 "예약 이름은 add/rm/rename 거부" 설명에 런타임 동사 허용 사실을 추가해야 한다. gaps.md GAP-001 참조.
- 전역 봇의 cwd 가 $PWD 임(DEC-001): status 출력의 전역 봇 cwd 는 cctg 호출 시점 현재 디렉터리이다. 사용자 문서에 이 동작을 명시하였다.
- down_reserved() 는 cctg 가 기동한 tmux 세션만 종료한다. bot.pid 러너는 종료 대상이 아님(NFR-003 한계). RESERVED_DOWN_NONE 메시지에 이 한계가 명시된다.
