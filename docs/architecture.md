# Architecture

## 5-Role Workflow (full mode, default)

```
PM (Mavis root) → Architect (ox-arch, default 0.1s auto-pass)
                 → Developer (ox-dev-1 / ox-dev-2 / ox-dev-3, 자동 idle 라우팅)
                 → Tester (ox-tester, verifier-only)
                 → Deployer (ox-deploy, smoke-only fast-path)
```

| 단계 | 디폴트 | timeout |
|------|--------|---------|
| PM (분류) | dev 슬롯 자동 | — |
| ox-arch | 0.1초 auto-pass | 30s |
| ox-dev-N | 풀스택 슬롯 (max 동일성) | 5m |
| ox-tester | 7규칙 + typecheck | 2m |
| ox-deploy | typecheck + dev boot + auto-route GET + hot reload | 1m |

총 ~80s (full) / ~50s (small 3-tier)

## 3-Role Workflow (small/simple)

```
Developer (ox-dev-N) → Tester (ox-tester) → Deploy (ox-deploy, smoke-only)
```

총 ~50s. 1줄 patch / typo / 파일 1개 변경.

## Acceleration Defaults

`max_cycles: 1` + `auto_reject_retries: 0` — verifier FAIL 시 owner 결정.

| verdict | 의미 |
|---------|------|
| `accept` | PASS — 자동 흐름 |
| `reject` | producer 잘못 — 자동 retry |
| `manual_retry` | owner 지시로 retry |
| `override_accept` | verifier 잘못 또는 risk OK |

## dev 슬롯 풀 라우팅

3 dev 슬롯 (ox-dev-1 / ox-dev-2 / ox-dev-3) 은 **풀스택 동일 역할**.
5영역 (A·B·C·D·E) 모두 처리 가능:

- **A.** 신규 도메인 (lib/features + app/<name>/ 셸)
- **B.** 데이터 layer (Prisma + Supabase + RLS)
- **C.** 외부 시스템 통합 (OAuth, mail, webhook)
- **D.** UI polish (디자인 토큰, a11y, 반응형)
- **E.** 리팩토링 (legacy → 모듈 분리)

Mavis가 idle 슬롯에 자동 라우팅. 큰 task면 3 dev 동시 병렬 dispatch 가능.

## worktree 패턴

```
1. /path/to/your/repo  ← main, dev server on port 3002
2. /tmp/wt/<wt-name>   ← wt-X 브랜치, 격리 작업
```

- `git worktree add -b wt-X /tmp/wt/X main`
- producer prompt 첫 줄: `cd /tmp/wt/X`
- 작업 후 worktree 안에서 commit
- main에 `git merge wt-X --no-ff` 로 합치기
- `git worktree remove --force` + `git branch -d wt-X` 으로 청소

**장점**: 동시 plan의 git diff 오염 0건. verifier 헷갈림 없음.

## 7-Rule AGENTS.md 자동 검증

ox-tester 가 다음 7 규칙 자동 점검:

1. page.tsx 200줄 룰
2. Feature Module 분리 (lib/features/{name}/ 구조)
3. ResourceTable<T> / TreeResourceShell 셸 사용
4. localStorage 키 = `ox:{domain}-{name}` 형식
5. 네이밍 규칙 (function: verb+Noun, const: SCREAMING_SNAKE)
6. 한국어 UI 100%
7. 타입 안전성 (npm run typecheck 0)

WARN → 기존 위반 (scope 밖), 무시
PASS → 정상
FAIL → fix-pointer + 자동 다음 사이클 blocking

## Deprecated 슬롯

- `mavis-frontend` (ox-ui) — UI 작업도 풀스택 슬롯이 처리
- `mavis-refactorer` (ox-refac) — 리팩토링도 풀스택 슬롯이 처리

DEPRECATED-*.md 파일은 보존 (history 추적용).
