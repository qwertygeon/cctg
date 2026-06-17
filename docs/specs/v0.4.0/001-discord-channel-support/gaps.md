---
작성: Design Agent
버전: v1.0
최종 수정: 2026-06-17 15:25
상태: 활성
---

# gaps.md — discord-channel-support 기획·설계 공백 기록

> 3단계 Design Agent 가 최초 생성. 이후 모든 Agent 가 누적 기록한다.
> 형식: `pipeline-conventions.md §6`. 상태 갱신은 해결 주체 Agent 가 `RESOLVED by [공식명]` 으로 표기.

## 목차

- [공백 목록](#공백-목록)

---

## 공백 목록

3단계 Design 시점에 spec.md / plan.md / decisions.md 의 모든 요구사항이 코드 근거로 확정 가능했으며, 미해결 기획·설계 공백 0건이었다. 4단계 구현 중 아래 2건이 식별되었다.

### GAP-001 (테스트 정합) — 기존 channel.bats "add --channel discord refused" 테스트가 SC-003 와 충돌
- 출처: Development Agent
- 컨텍스트: T001 (IMPLEMENTED_CHANNELS 에 discord 등재)
- 내용: `tests/channel.bats:18` "add --channel <unsupported>: refused before anything is created" 가 `--channel discord` → 비0 exit + "not supported" 출력을 단언한다(discord 미구현 시절 동작). T001 로 discord 가 구현 채널이 되면서 이 단언이 거짓이 되어 회귀 FAIL(1건). 이는 SC-003("add --channel discord ≠ UNSUPPORTED")이 명시한 **의도된 동작 변경**으로, 구현 결함이 아니다. research.md §회귀 점검(L68~73)은 channel.bats 의 add/status/config/legacy 를 "telegram 경로 불변=회귀 없음"으로 예측했으나 이 discord-refused 테스트를 누락했다.
- 처리: 본 테스트는 D 레이어(SC-매핑 테스트)이므로 **5a Test Agent(AUTHORING) 가 SC-003 시나리오로 갱신**한다(미구현 채널 케이스는 discord 대신 imessage/fakechat 등 여전히 비활성 채널로 대체). Development Agent 는 tests/ 미수정(§금지사항). SC-024 "기존 88 회귀 0" 의 기준값은 이 테스트 갱신 후 재산정(갱신본 PASS + discord-supported 신규).
- 상태: RESOLVED by Test Agent (AUTHORING) — channel.bats 가 SC-003 양방향(discord not-refused + fakechat refused) 으로 갱신됨. 5b 검증: `add --channel discord: not refused as unsupported (SC-003)` PASS, 미구현 fakechat 거부 PASS. 회귀 0(119/119).

### GAP-002 (검증 계약) — SC-021 `bash --posix -n` 대상에 commands.sh 포함되나 commands.sh 는 process substitution 으로 posix -n 불가(사전 존재)
- 출처: Development Agent
- 컨텍스트: T002~T005 (lib/commands.sh)
- 내용: tasks.md 구현 완료 기준·Test Authoring Contract SC-021 이 `bash --norc --noprofile --posix -n` 대상에 commands.sh 를 포함한다. 그러나 commands.sh 는 `done < <(all_names)` 등 **process substitution**(bash 확장, POSIX 비표준)을 다수 사용하며 baseCommit 3480eb1 시점에도 `--posix -n` 이 line syntax error 로 실패했다(사전 존재 — 본 spec 변경과 무관). 본 spec 의 T002~T005 신규 코드는 process substitution 을 추가하지 않으며(`done <<EOF` heredoc 만 사용), commands.sh 는 `bash --norc --noprofile -n`(posix 미적용) 으로는 통과한다. channels.sh/en.sh/ko.sh/cctg.bash 4개는 `--posix -n` 통과.
- 처리: SC-021 의 commands.sh 검증은 `bash -n`(non-posix)으로 갈음하는 것이 타당(commands.sh 는 항상 비-posix bash 로 source 됨). 5a Test Agent 가 SC-021 static 테스트 작성 시 commands.sh 에 한해 `--posix` 제외 또는 process-substitution 라인 예외 처리. 구현 측은 신규 비-posix 구문 미도입으로 책임 완료.
- 상태: RESOLVED by Test Agent (AUTHORING) — static.bats 가 SC-021 을 분리: `posix -n passes for channels.sh/en.sh/ko.sh/cctg.bash` + `bash -n passes for commands.sh (GAP-002 non-posix)`. 5b 검증: 양 테스트 PASS. 잔여: 6단계 Docs/회고에서 spec.md SC-021 문구(commands.sh 를 `--posix -n` 대상에 포함)의 정정 검토 권고(비차단).

### GAP-003 (문서-갱신-필요) — context.md 가 "telegram 한정" 으로 기술되어 discord 활성화와 불일치
- 출처: Docs Agent
- 컨텍스트: `{project}/.claude/docs/context.md`
- 내용: 본 spec(001-discord-channel-support)으로 discord 채널이 실제 구현·검증(IMPLEMENTED_CHANNELS="telegram discord", bats 119 PASS)됐으나, context.md 가 다음 지점에서 telegram 한정 상태로 남아 있다.
  - §1 프로젝트 개요: "프로젝트별 Claude Code **Telegram** 채널 봇", "현재 버전: v0.2.0"(실제 v0.3.0 릴리스됨, 본 spec 은 v0.4.0), 기술 스택의 "Telegram 채널 플러그인" 표기.
  - §5 도메인 용어: `channel descriptor` 정의의 descriptor 필드 목록이 `plugin/statedir_env/token_key/...`(4필드 시절) — 본 spec 으로 8필드(display/id_label/id_required/seed_policy 추가)로 확장됨.
  - §6 알려진 제약: "구현 채널 telegram 한정" 행이 더 이상 사실 아님 — discord 가 구현 채널이 됨. imessage/fakechat 만 미구현으로 정정 필요. 신규 제약 후보: 자동완성 채널 미러(CCTG_COMPLETION_CHANNELS)가 IMPLEMENTED_CHANNELS 와 수동 동기화 필요(ADR-003), Bash 3.2 제약으로 `--group` 컴파운드 토큰 파싱이 스칼라 누적+`:` split 기반(연관배열 불가).
- 처리: 06-docs 핵심원칙 #6 [MUST NOT] context.md 직접 갱신. 7단계 Retrospective Agent 가 context.md 갱신 패치로 처리(`{project}/.claude/docs-change-logs/` 변경 로그 동반). PROC-003 — §6 표는 기존 행 정정/제거이며 무가치 이력 행 추가가 아님.
- 상태: OPEN

### GAP-004 (문서-갱신-필요) — infra.md 의 채널/구현 언급 cross-check (PATCH-A18)
- 출처: Docs Agent
- 컨텍스트: `{project}/.claude/docs/infra.md`
- 내용: PATCH-A18 사전 cross-check 결과 — infra.md 에 Kafka/Application 임계값/비동기 표는 부재(셸 CLI 프로젝트, 운영 상수 변경 없음)하나, §1 환경 구성·§3 배포·§테스트 정책에 telegram 한정 또는 채널 목록 언급이 있으면 discord 활성화와 불일치 가능. 본 spec 은 install 매니페스트·배포 메커니즘 미변경(selection-phases Deploy=N)이므로 §3 배포 절은 영향 없을 가능성이 높으나, "구동 채널 = telegram" 류 서술이 §1/테스트 정책에 있으면 정정 필요. (Docs Agent 는 infra.md 직접 수정 금지 — 코드 근거 cross-check 만 기록.)
- 처리: 06-docs 핵심원칙 #6 [MUST NOT] infra.md 직접 갱신. 7단계 Retrospective Agent 가 infra.md 의 telegram 한정 표기 존재 여부를 확인 후 필요 시 갱신 패치 처리.
- 상태: OPEN

### GAP-002 후속 (검증 계약 — 문서 정정 권고) — spec.md SC-021 문구가 commands.sh 를 `--posix -n` 대상에 포함
- 출처: Docs Agent (GAP-002 / 5b test-report 비차단 권고 인계)
- 컨텍스트: `spec.md` SC-021 Given 절
- 내용: spec.md SC-021 은 `bash --norc --noprofile --posix -n` 대상에 commands.sh 를 포함하나, commands.sh 는 사전 존재 process substitution 으로 `--posix -n` 불가(GAP-002 확정). 실제 검증은 static.bats 가 분리(`--posix -n` 4파일 + commands.sh 는 `bash -n`)했고 양 테스트 PASS. spec 문구가 구현/테스트와 미세 불일치 — 정정 검토 권고(비차단).
- 처리: spec.md 는 1단계 Spec Agent 산출물(06-docs 책임 밖). 7단계 Retrospective 에서 spec 문구 정정 또는 SC-021 의 commands.sh 검증 방식 명문화 검토 권고.
- 상태: OPEN

### GAP-005 (구현 표면 — 사용자 가시성, 비차단) — `CCTG_MSG_USAGE`(cctg help) 가 `--channel`/`--group` 플래그를 노출하지 않음
- 출처: Docs Agent
- 컨텍스트: `messages/en.sh`/`messages/ko.sh` `CCTG_MSG_USAGE`
- 내용: `cctg help` 의 add 줄은 `add <name> <cwd> [--id <num>] [--token-env <VAR>|--token-stdin] [--mode <m>]` 로, `--channel`(v0.3.0 도입)·`--group`(본 spec 도입) 플래그를 노출하지 않는다. 자동완성(`completions/*`)에는 두 플래그가 모두 후보로 포함되어 비대칭. spec FR/NFR 에 USAGE 문자열 갱신 요구가 명시되지 않아 본 spec 변경 범위 밖이며 SC 도 없음(따라서 회귀 아님·게이트 차단 아님). Docs Agent 는 코드 근거 원칙상 README 사용법 synopsis(README.md:103/README.ko.md:103)를 코드 `CCTG_MSG_USAGE` 와 일치하게 유지함(USAGE 에 없는 플래그를 README synopsis 에 임의 추가하지 않음). 대신 Discord 사용법 절·플래그 표·자동완성에서 `--channel`/`--group` 을 충분히 문서화.
- 처리: spec 범위 밖 개선 후보. 7단계 Retrospective 에서 후속 spec(예: USAGE 문자열에 `--channel`/`--group` 반영) 제안 여부 판단. 본 spec 에서는 변경하지 않음(SCOPE 보존).
- 상태: OPEN

> 후속 단계에서 공백 발견 시 아래 형식으로 추가한다.
>
> ```
> ### GAP-XXX (유형) — [한 줄 요약]
> - 출처: [Agent 공식명]
> - 컨텍스트: [태스크/컴포넌트명]
> - 내용: [공백 상세]
> - 상태: OPEN | RESOLVED by [Agent 공식명]
> ```
