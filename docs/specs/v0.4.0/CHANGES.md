# CHANGES — v0.4.0

> 버전 폴더 루트 누적 변경 기록. 각 spec 완료 시 Docs Agent 가 항목을 append 한다.

---

## [001-discord-channel-support] 구현 완료

근거: spec.md FR-001~008 / NFR-001~005, SC-001~032 전수 PASS (5b test-report 119/119, coverage 32/32). DEC-001(`--group` 컴파운드 토큰).

변경 파일:
- `lib/channels.sh`: `IMPLEMENTED_CHANNELS="telegram discord"`, discord descriptor 8필드 활성화, telegram 신규 4필드(display/id_label/id_required/seed_policy) 추가 (FR-001/002)
- `lib/commands.sh`: cmd_add 의 `id_required` 분기·`seed_policy` 시드·`"pending"` 제거·`--group <id>[:nomention][:allow=...]` 파싱/검증/시드, cmd_status 의 채널 표시명+jq 토폴로지 출력 (FR-003/004/007/008)
- `messages/en.sh`, `messages/ko.sh`: telegram 하드코딩 4키 동적화 + 신규 키 5종(ADD_DONE_PAIRING, ERR_ADD_BAD_GROUP_ID, ERR_ADD_BAD_GROUP_MEMBER, STATUS_CHANNEL, STATUS_CHANNEL_TOPO) (FR-005)
- `completions/_cctg`, `completions/cctg.bash`: `--channel` 후보 동적화(IMPLEMENTED_CHANNELS 미러) + add 플래그 `--group` 추가 (FR-006/008)
- `tests/add.bats`, `tests/channel.bats`: SC 매핑 확장 (5a/5b)
- `tests/static.bats` (신규): SC-001/002/012~017/021/029 static 검증
- `tests/status_view.bats` (신규): SC-018/019/020 status 출력 검증
- 문서: `README.md`, `README.ko.md`(Discord 지원·`--channel discord`·`--group` 문법·status 토폴로지), `CHANGELOG.md`([Unreleased]에 v0.4.0 항목)

후속 작업 시 주의사항:
- **완성 파일 채널 미러 동기화**: `completions/_cctg`·`completions/cctg.bash` 는 `lib/channels.sh` 를 source 하지 않고 `CCTG_COMPLETION_CHANNELS="telegram discord"` 로컬 변수로 IMPLEMENTED_CHANNELS 를 **미러**한다(ADR-003). 향후 채널을 추가하면 `IMPLEMENTED_CHANNELS` 와 이 두 미러 변수를 **함께** 갱신해야 한다(자동 동기화 아님).
- **`--group` 검증 시점**: group/member 숫자 검증(`^[0-9]+$`)과 jq 가드는 레지스트리 등록 **전** 수행(ADR-006) — 비숫자 입력 시 abort 하고 봇 미등록(SC-027/032). 이 순서를 바꾸면 부분 등록 결함 발생.
- **`"pending"` 미포함 불변식**: 모든 채널 시드(telegram/discord)의 `access.json` 에 `"pending"` 키를 넣지 않는다(SC-009/010/011). 후속 시드 코드 변경 시 유지.
- **SC-021 검증 범위(GAP-002)**: `commands.sh` 는 사전 존재 process substitution 으로 `bash --posix -n` 불가 → static.bats 는 `commands.sh` 만 `bash -n`(non-posix)으로 갈음. spec.md SC-021 Given 절은 `commands.sh` 를 `--posix -n` 대상에 포함하나 실제 검증은 분리됨 — spec 문구 정정은 7단계 회고 비차단 권고(gaps GAP-002).
- **실 Discord 운영 검증 미수행**: 실제 봇 토큰·Gateway·서버 연결은 spec "범위 외"(통합 테스트 없음). 페어링 코드 반환·`/discord:access pair`·서버채널 @멘션·status 토폴로지 표시는 사용자 사후 운영 검증 시나리오(spec "사후 운영 검증 피드백 사이클").
