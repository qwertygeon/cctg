---
작성: Spec Agent
버전: v1.0
최종 수정: 2026-06-17
상태: 확정
---

# Spec Input: discord-channel-support

## 목차

- [수집 진행 상태](#수집-진행-상태)
- [질문 분석 근거](#질문-분석-근거)
- [카테고리별 수집 내용](#카테고리별-수집-내용)
- [보완 내용](#보완-내용)

> 수집 일시: 2026-06-17 14:42 | 사용자 최종 확인: 완료
> (RequirementsIntake 로 직전 대화에서 사전 수집. 코드 근거 재검증 후 확정.)

---

## 수집 진행 상태

| 카테고리 | 상태 | 마지막 질문 번호 | 답변 완료 항목 |
|---|---|---|---|
| 1. 배경 및 목적 | 완료 | Q3 | [Q1, Q2, Q3] |
| 2. 사용자 & 이해관계자 | 완료 | Q6 | [Q4, Q5, Q6] |
| 3. 핵심 기능 | 완료 | Q9 | [Q7, Q8, Q9] |
| 4. 데이터 & 입출력 | 완료 | Q12 | [Q10, Q11, Q12] |
| 5. 제약조건 | 완료 | Q16 | [Q13, Q14, Q15, Q16] |
| 6. 운영 환경 | 완료 | Q19 | [Q17, Q18, Q19] |
| 7. 예외 & 실패 시나리오 | 완료 | Q22 | [Q20, Q21, Q22] |

---

## 질문 분석 근거

| 질문 ID | 요지 | 옵션별 근거·trade-off | 추천안(이유) | 채택 결과 |
|---|---|---|---|---|
| Q-discord-seed | discord add 시 access.json 시드 정책 | A: dmPolicy=pairing(기본, 피드백 있음) / B: dmPolicy=allowlist+ID(telegram 방식, DM 전용) | A — 사용자가 ID 모르거나 서버채널 전용 봇일 때 black hole 방지 | A 채택: 채널별 seed_policy descriptor 필드 추가 |
| Q-discord-id-required | discord add --id 선택화 여부 | A: --id 항상 필수 유지 / B: discord는 --id 선택화(서버채널 전용 봇 시 불필요) | B — 서버채널 전용 봇에 dmPolicy=pairing이면 --id 없이도 동작 가능 | B 채택: token_required 처럼 id_required 필드 추가(discord=no, telegram=yes) |
| Q-discord-group-add | cmd_add에 서버채널 시드 방법 | A: --group 플래그 추가 / B: 별도 post-add 가이드(add는 DM만, 서버채널은 /discord:access group add) | B — add 단계는 최소화, 서버채널 세부 설정은 플러그인 스킬로 위임이 최소 표면 원칙에 부합 | B 채택: --group 플래그 범위 외 |
| Q-status-topology | status에 연결 토폴로지(DM/groups 수) 표시 | A: 채널명만 표시 / B: 채널명 + access.json 파싱으로 DM정책+groups수 표시 | B — 사용자 요청("어떤 mcp gateway와 연결됐는지 출력")에 직결. jq 의존하나 --json 도 이미 jq 필요 | B 채택(단 jq 없을 때 graceful degradation 필수) |

---

## 카테고리별 수집 내용

### [카테고리 1] 배경 및 목적

**Q1. 왜 만드는가?**
v0.3.0에서 채널 추상화 골격(descriptor + 레지스트리 channel 컬럼)이 도입됐으나 실제 구현 채널은 telegram 하나뿐. Discord를 실제 동작하는 채널로 활성화하고, 동시에 잔존 telegram 하드코딩을 제거하여 추후 추가 채널(imessage 등) 진입을 단일 파일 1개소 수정으로 완성시키는 구조로 개선.

**Q2. 현재 어떻게 해결하고 있는가?**
Discord 봇 기동 불가(IMPLEMENTED_CHANNELS="telegram"만). 사람용 status에 채널/게이트웨이 표시 없음. 여러 군데에 telegram 특정 문자열 하드코딩(메시지 카탈로그, 자동완성, access.json 시드).

**Q3. 성공 판단 기준?**
- `cctg add mybot /path --channel discord`가 정상 동작하고 봇이 Discord로 응답
- `cctg status`에 각 봇의 채널(게이트웨이) 표시
- telegram 특정 문자열이 사람 노출 경로에서 제거
- 추후 채널 추가 = channels.sh case 블록 1개 + IMPLEMENTED_CHANNELS 1줄 수정만으로 완결

### [카테고리 2] 사용자 & 이해관계자

**Q4. 누가 사용하는가?**
macOS 개발자(1인 사용자). Claude Code를 Discord/Telegram 채널 봇으로 운영하는 개인.

**Q5. 기술 수준?**
CLI 익숙, tmux/jq 사용 경험 있음. Discord 봇 생성(Developer Portal)은 사전 완료된 상태 가정.

**Q6. 이해관계자?**
사용자 1인. Discord 봇을 DM하는 Discord 사용자들(엔드 클라이언트).

### [카테고리 3] 핵심 기능

**Q7. 반드시 있어야 하는 기능(우선순위):**
1. Discord descriptor 완성 — channels.sh 주석 해제 + IMPLEMENTED_CHANNELS 등재
2. descriptor 확장 — display(표시명), id_label, id_required, seed_policy 필드 추가
3. add 흐름 채널 분기 — seed_policy 기반 access.json 시드(discord: pairing 기본), id_required 기반 --id 선택화
4. 메시지 카탈로그 telegram 하드코딩 제거 — ADD_PROMPT_TGID, STATUS_GLOBAL, STATUS_HINT_NO_TOKEN, DOCTOR_PLUGIN_HINT
5. 사람용 status에 채널/게이트웨이 + 연결 토폴로지 표시
6. 자동완성 --channel 후보를 IMPLEMENTED_CHANNELS 기반으로 동적화

**Q8. 있으면 좋지만 필수 아닌 것?**
- cmd_add에 `--group <채널 snowflake>` 플래그 (서버채널 사전 시드). 범위 외로 결정.
- doctor에서 채널별 설치 확인(구현 채널 수에 비례 확장).

**Q9. 명시적 제외:**
- imessage/fakechat 실제 구현(descriptor 확장 시 id_required=no, token_required=no 대비만)
- discord 봇 생성/Developer Portal 설정(플러그인·Discord 측 책임)
- /discord:access 스킬 기능 복제(런타임 접근 관리는 플러그인 소유)
- cmd_add `--group <채널snowflake>` 플래그(최소 표면 원칙, 서버채널 설정은 /discord:access group add로)

### [카테고리 4] 데이터 & 입출력

**Q10. 주요 데이터?**
- `channels.sh` descriptor: plugin, statedir_env, token_key, token_required, display, id_label, id_required, seed_policy (8필드로 확장)
- access.json 시드 스키마: telegram `{dmPolicy,allowFrom,groups,pending}` → discord `{dmPolicy,allowFrom,groups}` (pending 제거)
- `projects.conf` 레지스트리 4번째 컬럼(channel): 변경 없음(기존 호환)

**Q11. 외부 연동?**
Discord 플러그인: `plugin:discord@claude-plugins-official`. access.json 스키마는 ACCESS.md 기준.

**Q12. 데이터 민감도?**
DISCORD_BOT_TOKEN — 기존 P-003(시크릿 비노출) 원칙 동일 적용. .env에만 저장, argv 비노출.

**Q12-1. access.json 시드 내 allowFrom 배열?**
Discord DM 시드: `--id` 제공 시 `{dmPolicy:"allowlist",allowFrom:[id],groups:{}}`, 미제공 시 `{dmPolicy:"pairing",allowFrom:[],groups:{}}`.

### [카테고리 5] 제약조건

**Q13. 기술 스택 제약?**
Bash 3.2 호환 필수(연관배열 금지). channel_spec은 case 기반 유지. 새 필드 = case 블록에 항목 추가.

**Q14. 일정 제약?**
없음(즉시 진행).

**Q15. 성능 요구사항?**
없음(constitution.md A-002 SLA 면제 선언).

**Q16. 보안/법규?**
P-003 시크릿 비노출. discord 봇 토큰은 기존 telegram 토큰과 동일 패턴(.env 저장).

### [카테고리 6] 운영 환경

**Q17. 실행 환경?**
macOS 로컬 머신. tmux, jq, caffeinate 의존.

**Q18. 사용자 수/데이터 규모?**
1인 개발자. 봇 수: 수~수십 개. access.json 파일 크기: 수 KB 이하.

**Q19. 배포/운영 담당?**
사용자 직접(install.sh 경유).

배포 환경 cross-reference 결과: 컨테이너/L4 LB/NAT 없음. macOS 로컬 직접 실행으로 배포 환경 특이성 해당 없음.

### [카테고리 7] 예외 & 실패 시나리오

**Q20. 실패 시?**
discord descriptor 미완성(IMPLEMENTED_CHANNELS 미등재) → ERR_CHANNEL_UNSUPPORTED 기존 에러로 차단. 봇 토큰 없음 → 기존 ERR_NO_TOKEN 처리 불변.

**Q21. 예상 오류·엣지케이스?**
- discord add 시 --id 미제공 + dmPolicy=pairing → allowFrom 빈 배열로 시드, 플러그인이 첫 DM에 페어링 코드 반환(정상 동작, black hole 아님)
- discord add 시 --id 제공 → dmPolicy=allowlist로 시드(즉시 응답)
- telegram 레거시 레지스트리 행(4번째 컬럼 없음) → channel_of 기본값 DEFAULT_CHANNEL=telegram으로 처리(기존 동작 유지)
- token_required=no 채널(미래 imessage 등) → add 흐름에서 토큰 단계 스킵(현재는 구현 대상 아님, descriptor만 대비)

**Q22. 백업/복구?**
없음(CLI 도구, 상태 디렉터리는 파일시스템).

---

## 보완 내용

### discord DM/서버채널 접근 모델 정리 (코드 및 ACCESS.md 직접 확인)

- **DM 경로**: dmPolicy(pairing|allowlist|disabled) + allowFrom[유저 snowflake]. `pairing`이 기본(ACCESS.md: "The default policy is pairing").
- **서버채널 경로**: groups {"<채널 snowflake>": {requireMention, allowFrom[]}}. 채널ID 기준(guild ID 아님). 비어 있으면 DM 전용.
- **"pending" 필드**: telegram access.json에는 존재(commands.sh:67), discord ACCESS.md config file 스키마에는 없음. discord 시드에서 제거 필요.
- **add 흐름 분기**: discord의 경우 --id가 없어도 가능(pairing 기본). --id 있으면 allowlist 모드로 즉시 배선. telegram은 항상 allowlist 모드(기존 동작 유지, id_required=yes).

### descriptor 새 필드 정의

| 필드 | telegram 값 | discord 값 | 설명 |
|---|---|---|---|
| display | Telegram | Discord | 사람 노출 표시명(status/doctor) |
| id_label | Telegram numeric ID | Discord user snowflake | ADD_PROMPT_TGID 대체 라벨 |
| id_required | yes | no | --id 선택/필수 여부 |
| seed_policy | allowlist | pairing | add 시 access.json dmPolicy 기본값 |

### status 연결 토폴로지 표시 방침

사람용 status에 각 봇에 대해:
1. 채널명(display): "Telegram" 또는 "Discord"
2. jq 있을 때: access.json 파싱하여 DM 정책 + groups 수 표시
3. jq 없을 때: 채널명만 표시(graceful degradation)
4. access.json 없을 때: 채널명만(파일 부재는 BROKEN과 별개)
