---
작성: Spec Agent
버전: v1.0
최종 수정: 2026-06-17
상태: 확정
---

# Spec Input: cli-convenience-patches

> 수집 일시: 2026-06-17 20:45 | 사용자 최종 확인: 완료

## 수집 진행 상태

| 카테고리 | 상태 | 마지막 질문 번호 | 답변 완료 항목 |
|---|---|---|---|
| 1. 배경 및 목적 | 완료 | Q1~Q3 | [Q1, Q2, Q3] |
| 2. 사용자 & 이해관계자 | 완료 | — | [context.md 기반 확정] |
| 3. 핵심 기능 | 완료 | Q7~Q9 | [Q7, Q8, Q9] |
| 4. 데이터 & 입출력 | 완료 | Q10~Q12 | [Q10, Q11, Q12] |
| 5. 제약조건 | 완료 | Q13~Q16 | [Q13, Q14, Q15, Q16] |
| 6. 운영 환경 | 완료 | Q17~Q19 | [Q17, Q18, Q19] |
| 7. 예외 & 실패 시나리오 | 완료 | Q20~Q22 | [Q20, Q21, Q22] |

## 질문 분석 근거 (Question Analysis Basis)

| 질문 ID | 요지 | 옵션별 근거·trade-off | 추천안(이유) | 채택 결과 |
|---|---|---|---|---|
| Q-A1 | 항목1: 사후 변경 범위 | A: cwd만 / B: token만 / C: cwd+token / D: 전체 | C — 실용성·표면 최소 균형 | C 채택 (channel/allowlist/discord-groups 는 Out of Scope) |
| Q-A2 | 항목1: 커맨드 패턴 | A: 기존 config 확장 / B: 새 서브커맨드 신설 | A — P-005 준수, 기존 패턴 일관성 | A 채택 (config <name> cwd/token 액션 추가) |
| Q-B1 | 항목2: 자동완성 힌트 범위 | A: zsh만 / B: zsh 힌트+bash 값완성 | B — UX 최대화 | B 채택 + 서브커맨드별 --help 추가 |
| Q-C1 | 항목3: 예약어 런타임 범위 | A: status/logs만 / B: up/down / C: up/down+가드 / D: 스코프 외 | C — 안전성 확보 | C 채택 (up/down/restart/status/logs 허용, 단독소유자 가드 필수) |

## 카테고리별 수집 내용

### [카테고리 1] 배경 및 목적

Q1. 왜 만드는가?
- (항목1) add 로 등록 후 cwd 이동·토큰 교체 시 rm 후 재등록 없이 변경하고 싶다.
- (항목2) 자동완성 사용 시 값 목록이 부족하고 옵션 설명(힌트)이 없어 불편하다. 서브커맨드별 --help 도 없다.
- (항목3) 전역 telegram/discord 봇도 cctg 로 라이프사이클 제어(up/down/status 등)를 하고 싶다.

Q2. 현재 한계?
- `cctg config <name>` 은 mode/args/snapshot(launch.env 기반)만 변경 가능. (commands.sh:228-298)
- cwd(레지스트리 2번 컬럼), token(.env) 은 add 시 고정 — 변경 불가.
- 자동완성: `config <name> mode <TAB>` 에 모드 목록 미제공. (_cctg:56-61 — compadd 없음)
- top-level help/--help/-h 는 있으나 서브커맨드별 --help 없음. (cc-tg.sh:98-104)
- 예약어 telegram/discord 로 up/down 시도 → ERR_NOT_REGISTERED. (registry.sh:50-57 — lookup 실패)

Q3. 성공 기준?
- `cctg config <name> cwd <path>` 로 cwd 변경 + 레지스트리 2번 컬럼 갱신.
- `cctg config <name> token` 으로 토큰 교체 + .env 600 재작성.
- `config <name> mode <TAB>` 시 6개 모드 목록 표시 (zsh: 설명 포함, bash: 단어 목록).
- `cctg add --help` 등 서브커맨드별 사용법 출력 동작.
- `cctg up telegram` 등이 전역 봇에 대해 단독소유자 가드 후 정상 동작.

### [카테고리 2] 사용자 & 이해관계자

- 단일 사용자(개발자 본인): CLI 운영자·cctg 설치자·봇 등록자가 동일인.
- 이해관계자: 사용자 1인. 외부 이해관계자 없음.
- 기술 수준: CLI 도구 개발자 수준. 내부 구조 인지함.

### [카테고리 3] 핵심 기능

Q7. 필수 기능(우선순위 순):
1. `cctg config <name> cwd <path>` — cwd 사후 변경 (레지스트리 2번 컬럼 갱신)
2. `cctg config <name> token` — 토큰 사후 변경 (.env 600 재작성, argv 토큰 금지 유지)
3. 자동완성 값 보강: `config <name> mode <TAB>` → 6개 모드 목록 (zsh 힌트+bash 값 둘 다)
4. 서브커맨드별 `--help` 옵션 — 각 서브커맨드가 자기 사용법을 출력
5. 예약어(telegram/discord) 런타임: up/down/restart/status/logs 허용 + add/rm/rename 차단 유지 + 단독소유자 가드

Q8. 있으면 좋은 기능:
- config snapshot / config args 등 다른 config 액션 값도 자동완성 보강 가능하면 포함
- 각 서브커맨드 플래그 목록에 --help 추가 노출

Q9. 명시적 Out of Scope:
- channel 사후 변경 (telegram↔discord 전환)
- allowlist / telegram-id (access.json) 사후 변경
- discord groups 사후 변경
- imessage/fakechat 예약어 런타임 지원 (미구현 채널)
- 전역 봇에 대한 add/rm/rename (차단 유지)

### [카테고리 4] 데이터 & 입출력

Q10. 주요 데이터:
- 레지스트리: `projects.conf` (name|cwd|state_dir|channel — awk/mv 로 2번 컬럼 갱신)
- 상태 디렉터리 `.env` (TELEGRAM_BOT_TOKEN / DISCORD_BOT_TOKEN — 600 권한)
- 자동완성 파일: `completions/_cctg` (zsh), `completions/cctg.bash` (bash)
- 메시지 카탈로그: `messages/en.sh`, `messages/ko.sh` (신규 키 추가 필요)
- 전역 봇 상태 디렉터리: `~/.claude/channels/<ch>/` (.env, access.json, bot.pid)

Q11. 외부 연동:
- 레지스트리 파일 read/write (awk+mv 패턴, registry.sh 기존 패턴 준용)
- `.env` 파일 write (chmod 600)
- tmux: `tmux has-session` 으로 실행 중 감지 (session.sh:6)

Q12. 데이터 민감도:
- 봇 토큰 — 고민감. constitution P-003 준수 (argv 노출 금지, .env 600 저장)
- 나머지 — 낮음

### [카테고리 5] 제약조건

Q13. 기술 스택:
- macOS / Bash 3.2 호환 필수 (P-001 — 연관 배열 불가)
- 완성 파일에서 lib/ source 금지 (ADR-003 — 로컬 리터럴 미러 방식)

Q14. 일정: 제약 없음

Q15. 성능: SLA 없음 (constitution §3 선언 — 로컬 CLI 도구)

Q16. 보안/법규:
- P-003: 토큰을 argv 로 받지 않음. --token-env / --token-stdin / 대화형 마스킹 입력만.
- P-002: 전역 봇 .env/access.json 을 덮어쓰거나 삭제하지 않음.
- cwd 변경 시 디렉터리 존재 검증 필수.
- 토큰 빈 문자열 거부.

### [카테고리 6] 운영 환경

Q17. 실행 환경: 로컬 macOS 머신 단일 환경. 서버 없음.

Q18. 사용자 수·데이터 규모: 1인. 봇 수 수 개~수십 개 수준.

Q19. 배포 담당: 사용자 본인. `cctg update` 또는 install.sh 재실행.

배포 환경 cross-reference 결과: 이 spec 은 로컬 CLI 변경이며 컨테이너/NAT/LB/L4 영향 없음.

### [카테고리 7] 예외 & 실패 시나리오

Q20. 시스템 실패 시:
- cwd 변경: 경로가 존재하지 않으면 오류 메시지 + 중단. awk+mv 원자적 갱신으로 레지스트리 보존.
- token 변경: 빈 입력 거부. .env write 실패 시 오류 메시지.
- 예약어 up: 이미 cctg-<ch> tmux 세션 존재 또는 bot.pid 생존이면 기동 거부 + 사유 안내.

Q21. 예상 엣지케이스:
- cwd/token 변경 시 봇이 실행 중인 경우 → restart 안내 (mode 변경 패턴과 동일).
- 예약어 `up` 시 `.env` 없음 → 오류.
- 예약어 `down` 시 cctg-<ch> tmux 세션이 없는 경우(플러그인 bot.pid 러너로만 기동) → tmux 세션 없음 메시지, bot.pid 러너 종료 불가 (한계 명시).

Q22. 데이터 백업/복구: 요구사항 없음. awk+mv 원자적 갱신으로 충분.

## 보완 내용

- 항목3 cwd 규약: 전역 봇(예약어)은 레지스트리에 없으므로 lookup() 으로 cwd 조회 불가.
  up_one() 이 레지스트리 기반이므로 전역 봇 전용 경로가 필요. 사용자 확정: $HOME 을 기본 cwd 로 사용 (ASM-001 로 기록).
- 항목3 down 한계: cctg 가 tmux 로 띄운 세션(cctg-<ch>)만 kill 가능.
  전역 봇이 별도 러너(bot.pid)로 기동된 경우 해당 프로세스는 종료 못 함. NFR/제약으로 명시.
- 서브커맨드별 --help: 각 서브커맨드가 `--help` 플래그를 받아 자기 사용법 출력.
  en.sh/ko.sh 에 서브커맨드별 USAGE 메시지 키 추가 필요. 자동완성에도 --help 노출.
