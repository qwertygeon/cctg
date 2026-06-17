---
작성: Spec Agent
버전: v1.0
최종 수정: 2026-06-17
상태: 확정
---

# Assumptions: discord-channel-support

## 목차

- [가정 목록](#가정-목록)

---

## 가정 목록

| ID | 가정 내용 | 확인 필요 여부 | 확인 방법 |
|---|---|---|---|
| ASM-001 | Discord 플러그인(`plugin:discord@claude-plugins-official`)이 사용자 환경에 전역 설치되어 있다. `cctg add --channel discord` 등록은 가능하지만 `cctg up` 실행 시 플러그인이 없으면 claude --channels 실행이 실패한다. | 사용자 확인 필요 | `/plugin list`로 설치 여부 확인 |
| ASM-002 | Discord 봇 토큰은 사용자가 Discord Developer Portal에서 사전 발급한 상태다. CCTG는 토큰 발급 절차에 관여하지 않는다. | 사용자 확인 필요 | Discord Developer Portal에서 봇 생성 및 토큰 발급 여부 확인 |
| ASM-003 | discord access.json의 `"pending"` 필드는 Discord 플러그인 런타임에서도 사용되지 않는다(ACCESS.md config file 스키마에 없음). 따라서 시드에서 제거해도 플러그인 동작에 영향이 없다. | 코드 확인으로 검증 | `~/.claude/plugins/cache/claude-plugins-official/discord/0.0.4/server.ts`에서 `pending` 필드 참조 여부 확인 |
| ASM-004 | telegram 기존 access.json 시드에서 `"pending":{}` 제거가 기존 telegram 봇 동작에 영향을 주지 않는다. pending은 새 봇 등록(add) 시에만 생성되며, 기존 운영 중인 봇의 access.json은 변경되지 않는다. | 확인 불필요(add 시만 적용) | 기존 봇 access.json 파일 미변경으로 자명 |
| ASM-005 | discord의 `id_required=no`로 인해 비대화형 add에서 `--id` 없이 진행 시, `id_required` 필드를 읽어 `ERR_ADD_NEED_ID` 발생 여부를 분기하는 로직이 `cmd_add`에 추가된다. 기존 `noninteractive=1` + `--id` 미제공 → `die ERR_ADD_NEED_ID` 경로가 채널 분기 후 조건부로만 실행된다. | 설계 단계에서 확인 | Design Agent의 research.md에서 분기 로직 설계 검증 |
| ASM-006 | `channel_spec` 함수의 새 필드(display, id_label, id_required, seed_policy)는 미구현 채널(기존 `*) return 1` 분기)에서 동일하게 return 1을 반환해도 무방하다. 현재 비활성 채널(imessage 등)이 `channel_spec` 새 필드를 요청하는 경로가 없기 때문이다. | 확인 불필요(활성 채널만 배선) | IMPLEMENTED_CHANNELS 등재 여부로 제어 |
