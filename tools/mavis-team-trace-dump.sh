#!/bin/bash
# mavis-team-trace-dump.sh — Dump Mavis session/plan/communication data to JSON
# + pre-cache per-session messages for instant HTML click-to-view
# + plan-level trees with verifier results
#
# Usage: ./mavis-team-trace-dump.sh [output_dir]
# Default output_dir: same dir as this script

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${1:-$SCRIPT_DIR}"
OUT_JSON="${OUT_DIR}/mavis-trace.json"
SESSIONS_DIR="${OUT_DIR}/mavis-sessions"
mkdir -p "$SESSIONS_DIR"

PLAN_ROOT="${HOME}/.mavis/plans"
TMP=$(mktemp -d)

# === 1. Plan-level data: walk ~/.mavis/plans/*/state.json ===
python3 - "$PLAN_ROOT" "$TMP/plans.json" <<'PYEOF'
import json, os, sys, glob, re
plan_root = sys.argv[1]
out = sys.argv[2]
plans = []
for state_file in sorted(glob.glob(os.path.join(plan_root, '*', 'state.json')), key=lambda p: os.path.getmtime(p), reverse=True)[:20]:
    plan_id = os.path.basename(os.path.dirname(state_file))
    name = '?'
    # Extract name from notes/intro.md
    intro = os.path.join(plan_root, plan_id, 'notes', 'intro.md')
    if os.path.exists(intro):
        try:
            with open(intro) as f:
                first = f.readline()
            m = re.match(r'^#\s*Plan\s*"(.*)"', first)
            if m:
                name = m.group(1)
        except Exception: pass
    try:
        with open(state_file) as f:
            d = json.load(f)
        engine_sessions = d.get('engine_sessions', {})
        results = []
        for r in d.get('results', []):
            vr = r.get('verifier_results', []) or []
            vr_summaries = []
            for v in vr:
                s = v.get('summary', '')
                if len(s) > 600: s = s[:600] + '... [truncated]'
                vr_summaries.append({
                    'agent': v.get('agent'),
                    'session_id': v.get('session_id'),
                    'passed': v.get('passed'),
                    'inconclusive': v.get('inconclusive'),
                    'summary': s,
                })
            results.append({
                'task_id': r.get('task_id'),
                'status': r.get('status'),
                'attempt': r.get('attempt'),
                'producer_session_id': r.get('producer_session_id'),
                'producer_agent': r.get('producer_agent'),
                'verdict_summary': r.get('verdict_summary'),
                'started_at': r.get('started_at'),
                'finished_at': r.get('finished_at'),
                'duration_sec': round((r.get('finished_at', 0) - r.get('started_at', 0))/1000.0, 1)
                    if r.get('finished_at') and r.get('started_at') else 0,
                'verifier_results': vr_summaries,
            })
        plans.append({
            'plan_id': plan_id,
            'name': name,
            'status': d.get('status', '?'),
            'cycle': d.get('cycle', 0),
            'phase': d.get('phase', '?'),
            'total_tasks': len(d.get('results', [])),
            'tasks_done': sum(1 for r in d.get('results', []) if r.get('status') == 'done'),
            'results': results,
            'engine_sessions': [
                {'session_id': sid, 'task_id': meta.get('task_id'),
                 'role': meta.get('role'), 'agent_name': meta.get('agent_name')}
                for sid, meta in engine_sessions.items()
            ],
        })
    except Exception as e:
        plans.append({'plan_id': plan_id, 'name': name, 'error': str(e)})

with open(out, 'w') as f:
    json.dump({'plans': plans}, f, ensure_ascii=False, indent=2)
print(f'plans.json: {len(plans)} plans')
PYEOF

# === 2. All sessions grouped by agent (top-level mavis-trace.json) ===
AGENTS=(officex-architect officex-data-layer officex-deployer officex-feature-builder officex-frontend officex-integration officex-refactorer officex-reviewer mavis)
ALL_SESSIONS="$TMP/sessions.jsonl"
> "$ALL_SESSIONS"
for a in "${AGENTS[@]}"; do
  mavis session ls "$a" --include-compressed --limit 50 2>/dev/null \
    | python3 -c "
import json, sys
raw = sys.stdin.read()
start = raw.find('{')
if start < 0: sys.exit()
try:
    d = json.loads(raw[start:])
    for s in d.get('sessions', []):
        print(json.dumps(s, ensure_ascii=False))
except: pass
" >> "$ALL_SESSIONS" 2>/dev/null || true
done

# === 3. Per-session message pre-cache ===
echo "Caching session messages → $SESSIONS_DIR/"
python3 - "$ALL_SESSIONS" "$SESSIONS_DIR" > "$TMP/cache.log" 2>&1 <<'PYEOF'
import json, os, subprocess, sys

sessions_file = sys.argv[1]
out_dir = sys.argv[2]

def fetch(sid, *args):
    try:
        return subprocess.run(
            ['mavis', 'session'] + list(args) + [sid],
            capture_output=True, text=True, timeout=12
        )
    except Exception as e:
        return None

cached = 0; failed = 0
seen = set()
with open(sessions_file) as f:
    for line in f:
        line = line.strip()
        if not line: continue
        try:
            s = json.loads(line)
        except Exception:
            continue
        sid = s.get('sessionId', '')
        if not sid or sid in seen: continue
        seen.add(sid)

        m = fetch(sid, 'messages', '--limit', '12')
        i = fetch(sid, 'info')
        if m is None or m.returncode != 0:
            failed += 1; continue
        try:
            data = json.loads(m.stdout)
            msgs = data.get('messages', []) if isinstance(data, dict) else data
            if not isinstance(msgs, list):
                failed += 1; continue
            preview = []
            for x in msgs:
                if not isinstance(x, dict): continue
                c = x.get('content') or x.get('msg_content') or x.get('text') or ''
                if isinstance(c, list):
                    try:
                        c = ' '.join((y.get('text') if isinstance(y, dict) else str(y)) for y in c)
                    except Exception:
                        c = json.dumps(c)
                preview.append({
                    'role': x.get('role', x.get('type', '?')),
                    'ts': x.get('timestamp') or x.get('createdAt') or x.get('ts'),
                    'content': c if isinstance(c, str) else str(c),
                })
            info = {}
            try:
                if i and i.returncode == 0:
                    info = json.loads(i.stdout)
            except Exception: pass
            payload = {
                'session_id': sid,
                'agent': info.get('agentName') if info else None,
                'status': (info.get('status') or {}).get('type') if info else None,
                'title': info.get('title') if info else None,
                'message_count': len(preview),
                'messages': preview,
            }
            with open(os.path.join(out_dir, sid + '.json'), 'w') as f2:
                json.dump(payload, f2, ensure_ascii=False, indent=2)
            cached += 1
        except Exception as e:
            sys.stderr.write(f'parse fail {sid}: {e}\n')
            failed += 1

print(f'cached={cached} failed={failed}')
PYEOF
cat "$TMP/cache.log"

# === 4. Combined mavis-trace.json ===
python3 - "$ALL_SESSIONS" "$TMP/plans.json" "$OUT_JSON" <<'PYEOF'
import json, sys, time
from datetime import datetime, timezone, timedelta

sessions_file = sys.argv[1]
plans_file = sys.argv[2]
out_path = sys.argv[3]

sessions = []
with open(sessions_file) as f:
    for line in f:
        line = line.strip()
        if not line: continue
        try:
            s = json.loads(line)
            d_s = (s.get('updatedAt',0) - s.get('createdAt',0))/1000.0
            sessions.append({
                'id': s.get('sessionId',''),
                'agent_name': s.get('agentName',''),
                'title': s.get('title',''),
                'status': (s.get('status') or {}).get('type', 'unknown'),
                'parent_session_id': s.get('parentSessionId'),
                'task_tree_id': s.get('taskTreeId'),
                'created_at': s.get('createdAt',0),
                'updated_at': s.get('updatedAt',0),
                'duration_sec': round(d_s, 1) if d_s > 0 else 0,
                'effective_model': (s.get('model') or {}).get('model_id',''),
                'compressed': s.get('compressed', False),
            })
        except: pass

with open(plans_file) as f:
    plans_data = json.load(f)
plans = plans_data.get('plans', [])

agent_counts = {}
for s in sessions:
    a = s['agent_name']
    agent_counts.setdefault(a, {'total':0, 'finished':0, 'running':0, 'compressed':0})
    agent_counts[a]['total'] += 1
    if s['status'] == 'finished': agent_counts[a]['finished'] += 1
    if s['compressed']: agent_counts[a]['compressed'] += 1

NOW = int(time.time()*1000)
SEEN_24H = NOW - 86400*1000

out = {
    'generated_at': datetime.now(timezone(timedelta(hours=9))).strftime('%Y-%m-%d %H:%M:%S KST'),
    'sessions_total': len(sessions),
    'sessions_last_24h': sum(1 for s in sessions if s['updated_at'] >= SEEN_24H),
    'plans_total': len(plans),
    'plans_running': sum(1 for p in plans if p.get('status') == 'running'),
    'plans_completed': sum(1 for p in plans if p.get('status') == 'completed'),
    'sessions': sessions,
    'plans': plans,
    'agent_counts': agent_counts,
}
with open(out_path, 'w') as f:
    json.dump(out, f, ensure_ascii=False, indent=2)
print(f'wrote {len(sessions)} sessions, {len(plans)} plans → {out_path}')
PYEOF

rm -rf "$TMP"
