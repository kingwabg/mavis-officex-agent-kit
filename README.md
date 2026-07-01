# Mavis Agent Kit — Officex Care Edition

8 role-specific agents + 운영 메모 + 시각화 도구를 한 줄 설치로 셋업합니다.
Mavis (MiniMax Code) 환경이 이미 깔려 있는 다른 컴퓨터에서 `git clone + ./install.sh` 만으로 동일 워크플로우를 재현할 수 있게 모듈화.

## 구성

```
mavis-officex-agent-kit/
├── README.md                      ← 이 파일
├── LICENSE                        ← MIT
├── install.sh                     ← one-command setup
│
├── agents/                        ← 8개 agent 정의 (.md + .yaml 쌍)
│   ├── mavis-architect.{md,yaml}            # arch (default 0.1초 auto-pass)
│   ├── mavis-feature-builder.{md,yaml}      # 풀스택 슬롯 1
│   ├── mavis-data-layer.{md,yaml}           # 풀스택 슬롯 2
│   ├── mavis-integration.{md,yaml}          # 풀스택 슬롯 3
│   ├── mavis-frontend.{md,yaml}   (DEPRECATED)
│   ├── mavis-refactorer.{md,yaml} (DEPRECATED)
│   ├── mavis-reviewer.{md,yaml}             # tester (verifier-only)
│   └── mavis-deployer.{md,yaml}             # default smoke-only fast-path
│
├── plans/                         ← 작업 YAML 예시
│   ├── 01-simple-p2-refactor.yaml          ← 3-tier small (~50s)
│   └── 02-medium-p2-refactor.yaml          ← 5-tier full with verifier
│
├── tools/
│   ├── mavis-trace.html                       ← 세션/플랜 활동 트리 시각화
│   ├── mavis-system-diagram.html              ← 시스템 구조 다이어그램
│   └── mavis-team-trace-dump.sh               ← mavis CLI → JSON dump
│
└── docs/
    ├── architecture.md                ← 5-역할 다이어그램 + 가속화 default
    └── observability.md               ← 트레이스 페이지 사용법
```

## 빠른 시작

```bash
git clone https://github.com/kingwabg/mavis-officex-agent-kit.git
cd mavis-officex-agent-kit
./install.sh
```

`install.sh` 가 자동으로:
- `~/.mavis/agents/<name>/agent.md` + `config.yaml` 8쌍 복사
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

- **`/tmp/sc-/lib/features/<name>/`** — 9개 도메인 모두 5-파일 모듈로 분리 완료 (children, attendance, settings, tenants, child-documents, volunteer, staff, my-attendance, daily-log, monthly-plan, annual-plan)
- **A+B+C 가속화 demo** — 1줄 patch + P2 분리 동시 (settings+tenants) 약 5분
- **AGENTS.md 7규칙 자동 검증** — verifier 가 자동 검증, owner 결정
- **scratchpad 영구화** — root 운영 메모로 cross-cycle inherit
- **worktree 패턴** — `git worktree add -b wt-X /tmp/wt/X main` 으로 cross-plan git diff 오염 해결

## License

MIT
