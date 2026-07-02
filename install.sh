#!/usr/bin/env bash
# install.sh — Mavis Agent Kit installer (kingwabg/mavis-officex-agent-kit)
# 한 줄 실행: git clone + cd + ./install.sh
# 결과: 8개 officex-* agent 등록 + 도구 셋업 + 트레이스 페이지 자동 open

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
  # YAML frontmatter 제거 후 복사 (daemon이 system prompt 로드 시 description: 줄이 새는 것 방지)
  # 형식: 첫 '---' 부터 두 번째 '---' 까지 제거
  awk '
    BEGIN { in_fm = 0; fm_done = 0 }
    fm_done == 0 && /^---[[:space:]]*$/ {
      if (in_fm == 0) { in_fm = 1; next }
      else { in_fm = 0; fm_done = 1; next }
    }
    fm_done == 1 { print }
    fm_done == 0 && in_fm == 1 { next }
    fm_done == 0 && in_fm == 0 { print }
  ' "$md_file" > "$agent_dir/agent.md"
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

  # display_name 추출 우선순위:
  #   1) frontmatter 의 display_name: (legacy, optional)
  #   2) 헤딩 "# Officex Care — NAME (ox-xxx)" 의 (ox-xxx) 부분
  #   3) frontmatter 의 name: 값의 마지막 토큰 (e.g. officex-architect → architect)
  #   4) 그래도 없으면 base 이름 그대로 fallback
  display=$(grep -m1 "^display_name:" "$md_file" 2>/dev/null | sed 's/^display_name:\s*//;s/^["'"'"']//;s/["'"'"']$//')

  if [ -z "$display" ]; then
    # 헤딩 "# Officex Care — NAME (ox-xxx)" 에서 (ox-xxx) 부분만 추출
    # bash [[ =~ ]] regex 호환 안 되니 grep -oE 로 단순 처리
    display=$(grep -m1 "^# Officex Care —" "$md_file" 2>/dev/null \
              | grep -oE '\([^)]+\)' | head -1 | tr -d '()')
  fi

  if [ -z "$display" ]; then
    # 마지막 fallback: base 이름에서 마지막 토큰만 (e.g. officex-refactorer → refactorer)
    display=$(echo "$base" | awk -F'-' '{print $NF}')
  fi

  # description: frontmatter 에서 추출
  desc=$(grep -m1 "^description:" "$md_file" 2>/dev/null | sed 's/^description:\s*//;s/^["'"'"']//;s/["'"'"']$//')

  # 20자 제한 검사
  if [ ${#display} -gt 20 ]; then
    echo "  [WARN] $base — display '$display' >20 chars, will be truncated by mavis"
  fi
  desc="${desc:0:100}"  # 100자 제한

  # mavis agent 등록 (idempotent, prompt cache 안전 갱신)
  # - mavis agent new 는 등록 시점에 on-disk agent.md 를 읽어 system prompt 캐시
  # - mavis agent update 는 display/description 만 바꾸고 prompt 캐시는 안 바꿈
  #   → update 시 --system-prompt 로 깨끗한 파일 내용을 함께 전달해서 캐시 강제 갱신
  agent_md_clean="$AGENTS_DST/$base/agent.md"

  # display 갱신 + (있는 경우) system prompt 캐시 갱신
  update_args=(--display-name "$display" --description "$desc")
  if [ -s "$agent_md_clean" ]; then
    update_args+=(--system-prompt "$(cat "$agent_md_clean")")
  fi

  if mavis agent info "$base" >/dev/null 2>&1; then
    echo "  updating: $base (display=$display, prompt=$(wc -l < "$agent_md_clean" 2>/dev/null || echo 0) lines)"
    if mavis agent update "$base" "${update_args[@]}" >/dev/null 2>&1; then
      REGISTERED=$((REGISTERED + 1))
    else
      echo "  [WARN] $base — mavis agent update failed"
    fi
  else
    echo "  creating: $base (display=$display)"
    if mavis agent new "$base" "${update_args[@]}" 2>/dev/null; then
      REGISTERED=$((REGISTERED + 1))
    else
      echo "  [WARN] $base — mavis agent new failed"
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
