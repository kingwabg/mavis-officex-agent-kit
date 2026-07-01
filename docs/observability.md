# Observability

이 디렉토리의 도구로 Mavis 세션/플랜 활동을 한눈에 추적할 수 있습니다.

## mavis-trace.html

세션 + 플랜 트리 시각화.

**표시 내용:**
- 상단 stats: 총 세션 수, 24h 활동, 플랜 진행 상태, 활성 agent 수
- 섹션 01: 최근 50개 세션 (title, agent, status, duration)
- 섹션 02: Plan 트리 (task → producer → verifier → PASS/FAIL + summary)
- 섹션 03: Per-agent 카운트 (DEPRECATED 슬롯은 line-through)
- 클릭: 세션 message cache 로 즉시 view

**사용법:**
```bash
cd tools/
./mavis-team-trace-dump.sh         # JSON 갱신 (cron 또는 수동)
open mavis-trace.html              # 브라우저에서 보기
```

## mavis-system-diagram.html

정적 시스템 구조 다이어그램 — 1페이지 overview.

8 섹션:
1. 에이전트 구조 (10 active + 2 deprecated)
2. 워크플로우 3종 (3-tier / 5-tier / parallel)
3. Dispatch 알고리즘 (simple/full/parallel 분기)
4. 가속화 defaults (YAML 필드 단위)
5. 실제 demo (A vs B 비교 bench)
6. 알려진 이슈 (cross-plan git diff)
7. Session title 컨벤션
8. Updates log (타임라인)

**사용법:**
```bash
open tools/mavis-system-diagram.html
```

## mavis-team-trace-dump.sh

mavis CLI → JSON 데이터 변환 스크립트.

**수집 데이터:**
- 모든 활성 + 최근 세션 (8개 agent)
- 23개 세션의 messages pre-cache → `mavis-sessions/<sid>.json`
- 모든 플랜 state.json + intro.md → 트리 형태
- per-agent 카운트 + status 분류

**사용법:**
```bash
./mavis-team-trace-dump.sh                    # → tools/mavis-trace.json + mavis-sessions/*

# 또는 특정 출력 디렉토리 지정
./mavis-team-trace-dump.sh /tmp/trace-dumps/  # 그 디렉토리에 dump
```

**권장 주기:**
- 활발한 작업 중: 매 30분
- 안정기: 매 2-4시간
- 작업 종료 직후: 1회 확정

## 디버깅 흐름 (실전)

세션이 FAIL 났을 때:

1. `mavis-trace.html` 페이지 열기
2. 섹션 02 (Plans) 에서 해당 plan 펼치기
3. verifier summary 읽기 — 어떤 룰 위반?
4. summary 의 fix-pointer 보기
5. 실패한 세션 클릭 → message cache 에서 producer의 tool_calls + reasoning 확인
6. owner 결정: `manual_retry` / `override_accept` / `reject`

평균 디버깅 시간: 5분 → 30초 단축.
