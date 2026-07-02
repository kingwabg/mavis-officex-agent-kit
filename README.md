# Mavis Agent Kit — Officex Care Edition

8 officex-* role-specific agents + 운영 메모 + 시각화 도구를 한 줄 설치로 셋업합니다.
Mavis (MiniMax Code) 환경이 이미 깔려 있는 다른 컴퓨터에서 `git clone + ./install.sh` 만으로 동일 워크플로우를 재현할 수 있게 모듈화.

## 구성

```
mavis-officex-agent-kit/
├── README.md                      ← 이 파일
├── LICENSE                        ← MIT
├── install.sh                     ← one-command setup
│
├── agents/                        ← 8개 officex-* agent 정의 (.md + .yaml 쌍)
│   ├── officex-architect.{md,yaml}            # arch (default 0.1초 auto-pass)
│   ├── officex-feature-builder.{md,yaml}      # 풀스택 슬롯 1 (ox-dev-1)
│   ├── officex-data-layer.{md,yaml}           # 풀스택 슬롯 2 (ox-dev-2)
│   ├── officex-integration.{md,yaml}          # 풀스택 슬롯 3 (ox-dev-3)
│   ├── officex-frontend.{md,yaml}             # UI specialist (P5/P9 활용)
│   ├── officex-refactorer.{md,yaml}           # 리팩토링 (200줄 분할 + 셸 적용)
│   ├── officex-reviewer.{md,yaml}             # tester (verifier-only)
│   └── officex-deployer.{md,yaml}             # default smoke-only fast-path
│
├── plans/                         ← 작업 YAML 예시
│   ├── 01-simple-p2-refactor.yaml          ← 3-tier small (~50s)
│   └── 02-medium-p2-refactor.yaml          ← 5-tier full with verifier
│
├── tools/
│   ├── mavis-trace.html                       ← 세션/플랜 활동 트리 시각화
│   ├── mavis-system-diagram.html              ← 시스템 구조 다이어그램
│   └── mavis-team-trace-dump.sh               # mavis CLI → JSON dump
│
└── docs/
    ├── architecture.md                ← 9-역할 다이어그램 + 가속화 default
    └── observability.md               ← 트레이스 페이지 사용법
```

## 빠른 시작

```bash
git clone https://github.com/kingwabg/mavis-officex-agent-kit.git
cd mavis-officex-agent-kit
./install.sh
```

`install.sh` 가 자동으로:
- `~/.mavis/agents/<name>/agent.md` + `config.yaml` 9쌍 복사 (officex-*)
- `mavis agent new` 로 각 에이전트 등록 (displayName + description 설정)
- `tools/mavis-trace.html` 을 default browser 로 열기
- 5-tier / 3-tier 워크플로우 한 줄 설명 출력

## 워크플로우 3종

| 모드 | 멤버 | 시간 |
|------|------|------|
| **3-tier small** | dev(dev-N) → tester → deploy | ~50초 |
| **5-tier full** | arch (auto-pass default) → dev(dev-N) → tester → deploy | ~80초 |
| **parallel full + 3 dev** | arch → {dev-1+dev-2+dev-3} → tester → deploy | ~80초, 3 dev 동시 |

dev 슬롯 (dev-1/2/3) 은 **풀스택 동일 역할** — 어떤 task 든 받음. Mavis 가 idle 슬롯에 자동 라우팅.

## 가속화 default

- `max_cycles: 1` (한 번 attempt, retry 안 함)
- `auto_reject_retries: 0` (owner 수동 결정)
- ox-arch → default 0.1초 auto-pass (큰 변경만 detail 검증)
- ox-deploy → default smoke-only fast-path (build skip)

## 운영 룰 (R1~R5 — Token Economy)

P3~P14 운영 중 축적된 5가지 핵심 룰. live system 의 `agent.md` 본문에 반영됨:

- **R1 Plan Template**: `~/.mavis/templates/plan-template.yaml` 표준 (worktree / dev commit / verifier workdir / report 형식)
- **R2 Dev Commit 강제**: dev prompt 첫 줄에 `git add -A && git commit` 명시 (commit 누락 패턴 4회 반복 후 도입)
- **R3 Verifier Workdir 강제**: verify prompt 첫 줄에 `cd /tmp/wt/<wt-name>` (worktree 오인 방지)
- **R4 Mavis Report 3-line**: parent 보고 3-line 형식 (RESULT / VERDICT / NEXT)
- **R5 PM Auto-Decision**: owner 명시 요청 없으면 Mavis 가 자동 결정 + 백로그 자동 dispatch

자세한 내용: `docs/architecture.md`

## 사용 예시

### 1줄 patch (3-tier small)

```bash
mavis team plan run plans/01-simple-p2-refactor.yaml --from $MAVIS_ROOT_SESSION --no-wait
```

### 5-역할 풀 워크플로우

```bash
mavis team plan run plans/02-medium-p2-refactor.yaml --from $MAVIS_ROOT_SESSION --no-wait
mavis team plan status <plan-id>
mavis team plan decision <plan-id> --file decision.json
```

### 트레이스 페이지 (실시간)

```bash
cd tools/
./mavis-team-trace-dump.sh         # JSON 갱신
open mavis-trace.html              # 브라우저에서 보기
```

## 검증된 워크플로우 (Officex Care 기록)

이 kit 의 디자인은 Officex Care 저장소 (https://github.com/kingwabg/sc-) 에서 다듬어진 결과입니다.
실제 운영 기록:

- **12+ plan dispatch** (P3 ~ P14): 1줄 patch (3-tier) + 풀스택 (5-tier) + 3 dev 병렬 (parallel full)
- **`/tmp/sc-/lib/features/<name>/`** — 12+ 도메인 모두 5-파일 모듈 분리 (children, attendance, leave, approval, audit, donation, meeting, inspection, accounting, sidebar-todo, hwp-export, my-attendance)
- **worktree 패턴** — `git worktree add -b wt-X /tmp/wt/X main` 으로 cross-plan git diff 오염 해결
- **namespace 분리 충돌 회피** — `lib/features/<name>-<variant>/` (e.g. `leave-mock` vs `leave`)
- **Mavis 직접 fix 패턴** — dev commit 누락 / timeout / abort 시 Mavis 가 직접 typecheck + 머지
- **AGENTS.md 7규칙** — verifier 가 자동 검증 (200줄 룰 / Feature Module / 셸 / localStorage / 네이밍 / 한국어 / 타입)

## License

MIT
