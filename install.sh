#!/usr/bin/env bash
# install.sh — Mavis Agent Kit installer (kingwabg/mavis-officex-agent-kit)
# 한 줄 실행: git clone + cd + ./install.sh
# 결과: 9개 officex-* agent 등록 + 도구 셋업 + 트레이스 페이지 자동 open

set -e

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_SRC="$KIT_DIR/agents"
AGENTS_DST="$HOME/.mavis/agents"
SCRATCHPAD_SRC="$KIT_DIR/scratchpad.md"

echo ">> Mavis Agent Kit installer (Officex Care edition)"
echo "   KIT: $KIT_DIR"
echo "   HOME: $HOME"
echo ""

# 1. agent 디렉토리 검증
if [ ! -d "$AGENTS_SRC" ]; then
  echo "[ERROR] agents/ not found in $KIT_DIR" >&2
  exit 1
fi

# 2. mavis CLI 가용성 체크
if ! command -v mavis >/dev/null 2>&1; then
  echo "[ERROR] mavis CLI not found. Install Mavis first." >&2
  echo "  https://MiniMax Code.dev (MiniMax Code)" >&2
  exit 1
fi

# 3. agent 9쌍 설치 + 등록
mkdir -p "$AGENTS_DST"
INSTALLED=0
for md_file in "$AGENTS_SRC"/officex-*.md; do
  [ -e "$md_file" ] || continue
  base=$(basename "$md_file" .md)
  yaml_file="$AGENTS_SRC/$base.yaml"
  if [ ! -f "$yaml_file" ]; then
    echo "[SKIP] $base — yaml not found"
    continue
  fi
  agent_dir="$AGENTS_DST/$base"
  mkdir -p "$agent_dir"
  cp "$md_file" "$agent_dir/agent.md"
  cp "$yaml_file" "$agent_dir/config.yaml"
  echo "  installed: $base"
  INSTALLED=$((INSTALLED + 1))
done

echo ""
echo ">> Filesystem layer complete. ($INSTALLED officex-* agents)"
echo "   이제 mavis agent new 로 등록합니다..."
echo ""

# 4. mavis CLI 로 agent 등록 (idempotent)
REGISTERED=0
for md_file in "$AGENTS_SRC"/officex-*.md; do
  [ -e "$md_file" ] || continue
  base=$(basename "$md_file" .md)

  # Frontmatter 에서 display_name, description 추출
  display=$(grep -m1 "^display_name:" "$md_file" 2>/dev/null | sed 's/^display_name:\s*//;s/^["'"'"']//;s/["'"'"']$//')
  desc=$(grep -m1 "^description:" "$md_file" 2>/dev/null | sed 's/^description:\s*//;s/^["'"'"']//;s/["'"'"']$//')

  # display_name 이 frontmatter 에 없으면 # Officex Care — NAME 부분에서 추정
  if [ -z "$display" ]; then
    display=$(grep -m1 "^# Officex Care —" "$md_file" 2>/dev/null | sed 's/^# Officex Care —\s*//')
    # 형식: "Architect (ox-arch)" → "ox-arch"
    if [[ "$display" =~ \(([^)]+)\) ]]; then
      display="${BASH_REMATCH[1]}"
    fi
  fi

  if [ -z "$display" ]; then
    echo "  [WARN] $base — display name not found, skipping registration"
    continue
  fi

  # 20자 제한 검사
  if [ ${#display} -gt 20 ]; then
    echo "  [WARN] $base — display '$display' >20 chars, will be truncated by mavis"
  fi
  desc="${desc:0:100}"  # 100자 제한

  # mavis agent new (이미 있으면 update 만)
  if mavis agent info "$base" >/dev/null 2>&1; then
    echo "  updating: $base (display=$display)"
    mavis agent update "$base" --display-name "$display" --description "$desc" >/dev/null 2>&1 || true
  else
    echo "  creating: $base (display=$display)"
    # 새 등록. login 안 되어 있으면 실패할 수 있음.
    if mavis agent new "$base" --display-name "$display" --description "$desc" 2>/dev/null; then
      REGISTERED=$((REGISTERED + 1))
    fi
  fi
done

echo ""
echo ">> Mavis agent registry complete."
echo ""

# 5. scratchpad 안내
echo ">> Next steps:"
echo "   1) source / install scratchpad.md into your root session's working dir:"
echo "      cp scratchpad.md \$MAVIS_SCRATCHPAD"
echo ""
echo "   2) Open the trace page (browser):"
echo "      open tools/mavis-trace.html"
echo ""
echo "   3) Run a sample plan:"
echo "      mavis team plan run plans/01-simple-p2-refactor.yaml --from \$ROOT_SESSION --no-wait"
echo ""

# 6. 트레이스 페이지 자동 open (선택)
if command -v open >/dev/null 2>&1; then
  echo ">> Opening trace page..."
  open "$KIT_DIR/tools/mavis-trace.html" 2>/dev/null || true
fi

echo ">> DONE. installed=$INSTALLED registered=$REGISTERED"
