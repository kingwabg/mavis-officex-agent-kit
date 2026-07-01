# Mavis Root 운영 메모 — Officex Care 프로젝트

> 이 메모는 Mavis root 세션의 영구 운영 노트.
> sub-agent(`officex-*`)는 시작 시 `$MAVIS_SCRATCHPAD` 환경 변수로 이 파일을 inherit 받음 → 공통 롤스 + classifier + 가속화 default 활용.

---

## 1. 시스템 컨텍스트 (Source of Truth)

- **저장소**: `https://github.com/kingwabg/sc-` (로컬 clone `/tmp/sc-`)
- **Architecture 명세**: `/tmp/sc-/AGENTS.md` — feature module 분리·셸 사용·page.tsx 200줄 룰·한국어 UI·다국어
- **Self 매니페스트**: 각 agent의 `~/.mavis/agents/officex-*/agent.md` (role-specific 만 유지)
- **결정/메모**: 본 scratchpad (cross-cycle)
- **Plan 산출물**: `~/.mavis/plans/<plan>/outputs/<task>/deliverable.md`

---

## 2. 12-Agent Roster (2026-07-01, ox-* 명칭 통일, dev 1/2/3 명료화)

| 표기 | agent_name | displayName | 역할 |
|---|---|---|---|
| Mavis | `mavis` | Mavis | PM (orchestrator, root). classifier + plan + monitor + **3 dev 슬롯 자동 라우팅** |
| ox-arch | `officex-architect` | ox-arch | **default = 0.1초 auto-pass** (큰 변경만 detail 검증) |
| **ox-dev-1** | `officex-feature-builder` | **ox-dev-1** | **dev 슬롯 1** — 풀스택 (5영역 A~E 모두 처리) |
| **ox-dev-2** | `officex-data-layer` | **ox-dev-2** | **dev 슬롯 2** — 풀스택 (ox-dev-1과 **동일** 역할, 슬롯 식별자만 다름) |
| **ox-dev-3** | `officex-integration` | **ox-dev-3** | **dev 슬롯 3** — 풀스택 (ox-dev-1·2와 **동일** 역할, 슬롯 식별자만 다름) |
| ~~ox-refac~~ | `officex-refactorer` | ~~ox-refac~~ | **DEPRECATED** (2026-07-01) — refactor 작업은 ox-dev-N 풀스택 슬롯이 처리 |
| ~~ox-ui~~ | `officex-frontend` | ~~ox-ui~~ | **DEPRECATED** (2026-07-01) — UI 작업도 ox-dev-N 풀스택 슬롯이 처리 |
| ox-tester | `officex-reviewer` | ox-tester | 빠른 검증 + bug 발견 시 dev loop + 통과 시 최종보고 |
| ox-deploy | `officex-deployer` | ox-deploy | **default = smoke-only fast-path** (build skip) |
| (b-in) | `coder` / `general` / `verifier` | builtin | 다른 도메인 예비 |

> **3-역할 다이어그램**: PM → Tester → Deploy (smoke-only default). (3-tier small)
> **5-역할 다이어그램**: PM → Architect (auto-pass default) → Developer(dev 1/2/3, 자동 라우팅) → QA/Tester → Deploy (smoke-only default).
> **풀스택 dev 슬롯 dispatch**: Mavis가 idle 슬롯에 자동 라우팅. 같은 task가 큰 경우 3명 동시 병렬 dispatch 가능 (e.g., 한 도메인을 A·B·C 모듈로 동시 작업). 새 plan 작성 시 `assigned_to: ox-dev-1` 같은 특정 슬롯 OR `assigned_to_pool: [ox-dev-1, ox-dev-2, ox-dev-3]` 풀 둘 다 지원.

---

## 3. 작업 Classifier — Small vs Full (가속화 default 옵션)

작업 수신 시 Mavis(root)가 1차로 분류:

```yaml
classify(task):
  intent = infer(task_text)
  diff = git -C /tmp/sc- diff --stat HEAD~..HEAD (없으면 0/0)
  files = diff.files_changed
  lines = insertions + deletions

  if intent ∈ {patch, fix, typo, rename}: mode = simple
  elif (files ≤ 1 && lines ≤ 10 && AGENTS.md 무변경): mode = simple
  else: mode = full
```

### Plan YAML **가속화 default** (Mavis launch 시 적용)

```yaml
max_cycles: 1                  # 1 attempt
max_consecutive_failures: 1    # 첫 FAIL → owner 검토
auto_reject_retries: 0         # 자동 retry X (owner manual)
timeout_ms:
  ox-arch:   30000      # 30초
  ox-feat/-data/-intg/-refac/-ui: 300000  # 5분
  ox-tester: 120000    # 2분
  ox-deploy: 60000     # 1분
```

### Mode → Plan 분기 (auto)

| mode | 멤버 |
|---|---|
| **simple** | dev (ox-dev-N idle 라우팅) → **ox-tester** → ox-deploy (smoke-only fast-path) |
| **full** | ox-arch (0.1초 PASS default) → dev (ox-dev-N idle 라우팅) → **ox-tester** → ox-deploy (smoke-only) |

> **dev 슬롯 라우팅 규칙**: 한 plan = 1 dev 슬롯 점유 (또는 3 dev 모두 점유 — 풀 dispatch). Mavis가 idle한 슬롯 자동 선택. 동일 task를 3명이 병렬로 작업 가능. (예: 한 feature를 data·ui·api로 동시 병렬, Mavis가 depends_on으로 조립).

### Loop 동작

- `max_cycles: 1` → 단 한 번의 attempt. retry 안 함.
- tester FAIL → cycle_report → **owner manual 결정** (Mavis 또는 사용자)
- 2회 시도 (manual_retry) 후 PASS면 accept / 아니면 owner override

---

## 4. 공통 롤스 (모든 ox-* agent inherit — agent.md 본문에서 반복 금지)

1. **AGENTS.md read** — `/tmp/sc-/AGENTS.md` 작업 시작 시 1회.
2. **한국어 UI 100%** — 영문 브랜드만 예외.
3. **사용자 분기 안 묻기** — 가설 + 추천, 1안으로 끝.
4. **parent 보고** — `mavis communication send --to "$PARENT_SESSION_ID" --command prompt --content "<verdict>"`.
5. **핸드오프 표기** — 본인 role 외 일은 `ox-{arch|dev-1|dev-2|dev-3|tester|deploy}` 중 하나로 명시. (2026-07-01: ox-feat/ox-data/ox-intg → ox-dev-N 풀스택 통일, ox-refac/ox-ui DEPRECATED)
6. **AGENTS.md 무변경 + schema/infra 무변경** → ox-arch 0.1초 auto-pass default.
7. **scratchpad 영구화** — 본 메모는 모든 cycle에서 inherit.
8. **풀스택 self-discipline** — dev 슬롯(ox-dev-1/2/3)은 어떤 task든 처리 가능. 작업 영역(A·B·C·D·E) 자율 판별. 영역 안묻고 1안.

---

## 5. ox-arch 0.1초 auto-pass (default mode)

조건 (모두 만족): AGENTS.md 무변경 + `lib/features/*` schema/infra 무변경 + 200룰 violation 0

→ ox-arch 즉시 PASS sign + producer hand-off 사양(parent 보고)만 보내고 cycle 종료. **30초 timeout**.

큰 변경(예: schema 신규 도입, Supabase migration, 새 feature module 신설)에서만 plan validator detail 분석으로 확장.

---

## 6. ox-deploy smoke-only fast-path (default mode)

4-tier (runtime 검증 강화 — compile-time만 잡던 것의 70~80% runtime에서 추가 차단):
1. **typecheck** (tsc 0 errors)
2. **dev server boot** (`npm run dev --port 3002 &` + 5초 sleep + health check)
3. **auto-route GET** — `git diff --name-only`에서 `app/**/page.tsx` 자동 추출 → 각 route를 `curl`로 GET → 200/307 + latency 측정. 4xx/5xx → FAIL. (각 page.tsx를 route path로 변환: `app/foo/page.tsx` → `/foo`)
4. **hot reload** — producer 변경 파일 dev server reload 확인 + 응답에 새 내용 반영 여부 grep

→ `npm run build` **skip** (lazy — owner 명시적 요청 시에만 1회 실행)

→ cycle 안에서 자동 트리거 X → cycle time 절감. owner가 추후 build 결과를 보고 싶을 때 deployer가 lazy 실행.

---

## 7. Avoid / Anti-pattern

- **ox-tester**: 코드 작성/수정 절대 금지 (수정안 텍스트로만 제안)
- **ox-deploy**: 코드 작성 금지 (typecheck/build/smoke/hot reload만 — default smoke-only)
- **ox-arch**: 손코딩 금지 (산출물 = plan + 의견)
- **dev-slots** (ox-dev-1 / ox-dev-2 / ox-dev-3): 동일 풀스택 슬롯 — 어떤 도메인 작업이든 처리 가능. **DEPRECATED**: ~~ox-feat / ox-data / ox-intg / ox-refac / ox-ui~~ (5개 분리 슬롯은 2026-07-01에 3개 풀스택으로 통합. refac/ui 작업도 dev 풀스택이 받음)

---

## 8. 가속화 default 적용 후 자동화 동작 (시계열)

### 🟢 SMALL (simple 3-tier)

```
T=0초   classifier → simple
T=3초   dev 1-hop (ox-feat / ox-refac / ox-ui / ox-data / ox-intg 자동)  (≤30초)
T=33초  ox-tester (7규칙 + typecheck)                                    (≤15초)
T=48초  ox-deploy smoke-only (typecheck + dev smoke + hot reload)          (≤20초)
T=68초  Mavis 보고 ────────── 너한테

총 ~50초 (1분 컷)
```

### 🔵 BIG (full 4-tier, arch auto-pass default)

```
T=0초   classifier → full, dev 슬롯 자동
T=3초   ox-arch (0.1초 PASS default) — 큰 변경이면 ≤30초 plan validator
T=8초   dev 1-hop (≤60초)
T=68초  ox-tester (≤15초)
T=83초  ox-deploy smoke-only (≤20초, build skip)
T=103초 Mavis 보고 ────────── 너한테

총 ~80초 (1분 컷 + α)
```

### tester FAIL 시 (max_cycles=1 default)

- cycle_report 자동 emit → Mavis/owner manual 결정 (manual_retry / override_accept)
- 자동 retry X
- 사용자 의도 결정 후 다음 task

---

## 9. Session Title Convention (2026-07-01)

**형식**: `[<에이전트 short name>] <수정 파일명> <내용 요약>`

- 모든 ox-* agent의 worker 세션 title은 이 형식 통일
- displayName 그대로 사용 (ox-arch / ox-feat / ox-data / ox-intg / ox-refac / ox-ui / ox-tester / ox-deploy)
- producer 세션 예: `[ox-feat] format-date.ts 1줄 zero-pad`, `[ox-refac] children.ts P2 분리`
- verifier(ox-tester) 세션 예: `[ox-tester] format-date.ts 1줄 verify`, `[ox-tester] children.ts P2 분리 verify`
- 다중 파일: `&` 또는 `→` 로 표기 (예: `[ox-feat] foo.ts & bar.ts 신규 작성`)
- **적용 시점**: (1) Mavis가 새 plan YAML 작성 시 `title:` 필드를 이 형식으로, (2) past 세션은 `mavis session update --title` 로 일괄 적용. owner가 임의 변경 시 format 엄수.

## 10. Updates Log

- 2026-07-01: 9-agent 등록 (architect / builder / refactorer / frontend / reviewer / deployer)
- 2026-07-01: displayName 짧게 (ox-*), scratchpad 영구화 도입 (classifier + 공통 롤스 + 경량 모드)
- 2026-07-01: **ox-review → ox-tester** rename. 워크플로우 = 빠른 검증 + bug 발견 시 자동 dev loop + 통과 시 최종보고
- 2026-07-01: **+2 신규 dev 슬롯** — `ox-data` (dev 2 데이터 layer), `ox-intg` (dev 3 외부 시스템 통합). **12-agent 완전체** — dev 1/2/3 명료화, 5-역할 다이어그램 완성
- 2026-07-01: **A+B+C 가속화 default 적용** — §5 ox-arch always-0.1초-auto-pass / §6 ox-deploy smoke-only fast-path / §3 max_cycles=1 + auto_reject_retries=0. 사이클 시간 small **~50초**, full **~80초**. 다음 task부터 새 시간 가동.
- 2026-07-01: **동시 plan git diff 오염 발견** — 2개 plan이 같은 `/tmp/sc-` 작업트리 동시 실행 시 verifier의 `git diff` 가 cross-plan 변경 포함. 다음 demo 부터 (a) git worktree 분리 또는 (b) plan 사이 commit 도입
- 2026-07-01: **Session Title Convention §9 도입** — `[<agent>] <파일> <요약]` 형식 통일. 기존 12개 세션 일괄 리네임 완료. 앞으로 새 plan YAML의 `title:` 도 이 형식
- 2026-07-01: **5-역할 → 3-역할 + 풀스택 슬롯 3명** — 사용자 결정. `ox-feat / ox-data / ox-intg` 3개를 **풀스택 동일 슬롯** `ox-dev-1 / ox-dev-2 / ox-dev-3` 로 통일. `ox-refac / ox-ui` **DEPRECATED** (refactor/UI 작업도 ox-dev-N 풀스택이 처리). Mavis는 idle 슬롯에 자동 라우팅. 큰 task는 3명 동시 병렬 dispatch 가능.
- 2026-07-01: **런타임 smoke + 추적 시각화 도입** (사용자 초기 에이전트 오작동 감소 요청). ox-deploy §6 4-tier로 upgrade: typecheck + dev boot + auto-route GET (변경 page.tsx 자동 추출) + hot reload. `mavis-team-trace-dump.sh` + `mavis-trace.html` 로 세션·플랜·에이전트별 카운트 시각화.
- 2026-07-01: **dump 스크립트 강화 (B+A 완료)** — (B) 23개 세션 전부 messages pre-cache → `mavis-sessions/<sid>.json` → 페이지 클릭 시 즉시 view. (A) 8개 plan 모두 state.json + intro.md 파싱 → 트리 형태로 verifier verdict + summary 표시. plan 이름은 `notes/intro.md`의 `# Plan "name"` regex 추출.
- 2026-07-01: **worktree 도입 + P2 child-documents merge 완료** — `git worktree add` 패턴 정착. wt-p2-childdocs 에서 작업 → `wt-p2-*` commit → main에 `--no-ff` merge. verifier가 AGENTS.md §1.3 localStorage 키 규칙 위반 (`office-portal:`) 1줄 캐치 → owner manual fix 후 override_accept. 정리: 3개 worktree + branch 전부 `worktree remove --force` + `git branch -d` 로 청소. main HEAD = `5de819f`.
- 2026-07-01: **P2 병렬 첫 실전 — settings + tenants 동시** — wt-p2-settings (ox-dev-1) + wt-p2-tenants (ox-dev-2) 둘 다 worktree 격리로 동시 진행. 두 verifier 모두 PASS (tenants는 4 verticals data integrity + 모든 필드 일치 검증 추가). main HEAD `7007d07`. 남은 flat lib 파일: attendance.ts(141), session-types(28), utils(34), format-date(4) — 얇거나 utility는 모듈 분리보다 보존.
- 2026-07-01: **P3 attendance (wt-p3-attendance)** — `lib/attendance.ts` (142줄) → `lib/features/attendance/` 5파일 분리 (types/data/utils/labels/index). `genMonth() + Map cache` 패턴과 `STATUS_LABEL/TONE` 5개 키 (등원/결석/조퇴/보건휴식/미등원) 100% 보존. shim 16줄. main HEAD `bd6e4f8`. worktree pattern 4번째 적용 — 패턴 완전히 정착.
- 2026-07-01: **`lib/session-types.ts` cleanup** — single-consumer (session.tsx) 였던 28줄 모듈 → inline + 삭제. `User`/`Widget` 타입 + `MOCK_USER`/`DEFAULT_WIDGETS` 상수 모두 `lib/session.tsx` 안으로. 외부 동작 보존, typecheck 0. **교훈**: 얇은 utility 모듈 + single-consumer면 worktree+plan ceremony 안 거치고 직접 inline이 깔끔. main HEAD `0c9d0e5` (또는 그 다음).
