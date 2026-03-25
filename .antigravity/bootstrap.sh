#!/bin/bash
# ==============================================================================
# Google Antigravity - Universal SOTA Bootstrap v3.1
# ==============================================================================
# Architecture: One-User-Per-Project | Global Config Native | JIT Context
# Target: Remote Servers (LXC/Proxmox, VPS) — headless, SSH-safe
# Security Model: 1 Linux User = 1 Project = 1 isolated ~/.gemini/antigravity
#
# File Layout:
#   ~/.gemini/antigravity/mcp_config.json          ← MCP (IDE reads this)
#   ~/.gemini/antigravity/knowledge/               ← Knowledge (IDE reads this)
#     ├── stack-context.md                         ← auto-generated, ephemeral
#     └── coding-standards.md                      ← symlink → project (.git tracked)
#   $PWD/.antigravity/knowledge/coding-standards.md ← source of truth (versioned)
#   $PWD/.git/hooks/                               ← evolutionary hooks
# ==============================================================================

set -e

# ── Dependency Check ──────────────────────────────────────────────────────────
for cmd in jq curl; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "❌ '$cmd' not found. Install: apt install $cmd"; exit 1; }
done

echo "🚀 [Antigravity v3.1] One-User-Per-Project Bootstrap..."

# ── Project Root Detection (Safe for subdirectories) ─────────────────────────
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
cd "$PROJECT_ROOT"

AG_GLOBAL="$HOME/.gemini/antigravity"
AG_KNOWLEDGE_GLOBAL="$AG_GLOBAL/knowledge"
MCP_CONFIG="$AG_GLOBAL/mcp_config.json"
AG_PROJECT="$PROJECT_ROOT/.antigravity"
AG_KNOWLEDGE_PROJECT="$AG_PROJECT/knowledge"

mkdir -p "$AG_KNOWLEDGE_GLOBAL" "$AG_KNOWLEDGE_PROJECT" "$AG_PROJECT/workflows"

# Detect script path relative to git root for hooks
SCRIPT_PATH_FROM_ROOT=$(git ls-files --full-name "$0" 2>/dev/null || echo "$0")
SCRIPT_PATH_FROM_ROOT="${SCRIPT_PATH_FROM_ROOT#./}"

# .gitignore — ephemeral files stay out of git
cat << 'EOF' > "$AG_PROJECT/.gitignore"
knowledge/stack-context.md
knowledge/evolution_trigger.tmp
EOF

# ==============================================================================
# STEP 1: Stack Detection & Compact Fingerprint
# ==============================================================================
echo "🔍 Detecting project stack..."

STACK_TYPE=""
STACK_FINGERPRINT=""

if [ -f "$PWD/pyproject.toml" ]; then
    STACK_TYPE="Python/Poetry"
    PY_DEPS=$(grep -E '^\s*[a-zA-Z0-9_-]+ *[=>!<]?' "$PWD/pyproject.toml" \
        | grep -v '^\[' | grep -v '^python' | awk -F'[=>!< "^~]' '{print $1}' \
        | tr -d ' "' | grep -v '^$' | sort -u | head -20 | tr '\n' ',' | sed 's/,$//')
    STACK_FINGERPRINT="Python/Poetry | deps: ${PY_DEPS}"
elif [ -f "$PWD/requirements.txt" ]; then
    STACK_TYPE="Python/pip"
    PY_DEPS=$(awk -F'[=>!<]' '/^[a-zA-Z0-9_-]/ {print $1}' "$PWD/requirements.txt" \
        | tr -d ' ' | sort -u | head -20 | tr '\n' ',' | sed 's/,$//')
    STACK_FINGERPRINT="Python/pip | deps: ${PY_DEPS}"
fi

if [ -f "$PWD/package.json" ]; then
    [ -n "$STACK_TYPE" ] && STACK_TYPE="$STACK_TYPE + Node.js" || STACK_TYPE="Node.js"
    NODE_DEPS=$(jq -r '(.dependencies // {}) + (.devDependencies // {}) | keys | join(",")' \
        "$PWD/package.json" 2>/dev/null | cut -c1-200)
    STACK_FINGERPRINT="${STACK_FINGERPRINT:+${STACK_FINGERPRINT} | }Node.js | deps: ${NODE_DEPS}"
fi

VENV_STATUS="Not detected"
if [ -d "$PROJECT_ROOT/.venv" ] || [ -d "$PROJECT_ROOT/venv" ]; then
    VENV_STATUS="[ACTIVE] Detected"
fi

PROJECT_STRUCTURE=$(find "$PROJECT_ROOT" -maxdepth 2 -type d \
    ! -name ".*" ! -name "__pycache__" ! -name "node_modules" \
    ! -name ".venv" ! -name "venv" ! -name "dist" ! -name "build" \
    | sort | sed "s|$PROJECT_ROOT/||" | grep -v '^$')

# ==============================================================================
# STEP 2: stack-context.md → Global Knowledge (ephemeral, auto-generated)
# ==============================================================================
cat << EOF > "$AG_KNOWLEDGE_GLOBAL/stack-context.md"
# Project Stack Context (Auto-Generated — DO NOT EDIT)
## Project
Path: $PROJECT_ROOT
User: $(whoami)
Venv: $VENV_STATUS

## Stack
$STACK_FINGERPRINT

## Project Tree (depth 2)
\`\`\`
$PROJECT_STRUCTURE
\`\`\`
EOF
echo "📄 stack-context.md → $AG_KNOWLEDGE_GLOBAL"

# ==============================================================================
# STEP 3: coding-standards.md → Project (versioned) + Symlink to Global
# Created once in project. Never overwritten. Symlinked so IDE reads it.
# ==============================================================================
if [ ! -f "$AG_KNOWLEDGE_PROJECT/coding-standards.md" ]; then
cat << 'EOF' > "$AG_KNOWLEDGE_PROJECT/coding-standards.md"
# ⚙️ Coding Standards — Edit & Version-Control This File

## Token Economy (CRITICAL)
- ZERO FLUFF: No greetings, summaries, or apologies. Output code or findings only.
- BATCH READS: Read multiple files in one MCP call. Never call MCP twice for the same file.
- NO REPETITION: Never repeat context already in conversation. Reference it by name.
- SILENT FETCH: Browser doc fetches are silent — no narration.

## Cognitive Override
- LANGUAGE FORCING: Translate non-English prompts to English internally. All reasoning runs in English.
- INTENT MAPPING: Understand the real goal, not just the literal words.

## Code Quality (Zero Error Policy)
- TOOL FIRST: Check file existence via MCP before creating. Check deps before installing.
- READ BEFORE WRITE: Always read target file before editing any section.
- NO HALLUCINATIONS: Never invent signatures, package names, or paths. Verify via MCP or browser.
- ALGORITHMIC DISCIPLINE: O(N) or O(log N) max. O(N²) requires explicit justification.
- ATOMICITY: One logical change per step. No mixing refactors with features.

## Environment Awareness
- REMOTE SERVER MODE: Headless Linux. No GUI. No desktop. SSH-safe outputs only.
- SUDO-AWARE: Check if root is needed. Prefer user-space solutions.
- ENV VARS FIRST: Config goes in env vars or .env files. Never hardcoded.
- VENV MASTERY: If .venv exists, libraries are there. Use `pip show` to find source paths.

## 🧠 Cognitive & Memory Recovery (UNSTICKING)
- LOOP PREVENTION: If a tool fails twice with the same outcome, STOP. Report the impasse.
- TIER JUMP: If gemini-3-flash fails a research task 2x, switch to gemini-3.1-pro-low.
- SOURCE DISCOVERY: If lost in library internals (like Agno), explore `site-packages` via MCP.
- CONTEXT COMPACTING: If history is long, summarize findings and proceed with the summary.

## Model Routing (Tiered Intelligence)
| Task Type                                      | Model                        |
|------------------------------------------------|------------------------------|
| Routine code, simple edits, terminal commands   | gemini-3-flash               |
| Deep Research, complex logic fixed, unsticking | gemini-3.1-pro-low           |
| Architecture, security review, complex design  | gemini-3.1-pro-high          |
| Knowledge synthesis, code auditing, refactors  | claude-sonnet-4.6-thinking   |
| Critical decisions, security review, deep bugs | claude-opus-4.6-thinking     |
EOF
    echo "📝 coding-standards.md created (user-owned, git-tracked)"
else
    echo "⏭️  coding-standards.md exists — skipping (user-owned)."
fi

# Symlink: project → global (IDE reads global, file lives versioned in project)
ln -sf "$AG_KNOWLEDGE_PROJECT/coding-standards.md" "$AG_KNOWLEDGE_GLOBAL/coding-standards.md"
echo "🔗 Symlink: coding-standards.md → $AG_KNOWLEDGE_GLOBAL"

# ==============================================================================
# STEP 4: MCP Config → Merge into ~/.gemini/antigravity/mcp_config.json
# Uses $PWD as filesystem root — safe with 1-user-per-project model.
# Merges non-destructively: preserves existing entries (e.g. supabase-mcp).
# ==============================================================================
echo "⚙️  Configuring MCP servers..."

MCP_DATA=$(jq -n --arg pwd "$PROJECT_ROOT" '{
    "local-filesystem": { "command": "npx", "args": ["-y", "@modelcontextprotocol/server-filesystem", $pwd] },
    "local-git": { "command": "npx", "args": ["-y", "@modelcontextprotocol/server-git", "--repository", $pwd] }
}')

# Dynamic Stack Detection & MCP Injection
if [ -f "$PROJECT_ROOT/package.json" ]; then
    if grep -q '"next"' "$PROJECT_ROOT/package.json"; then
        echo "   + Next.js detected"
    fi
    if [ -f "$PROJECT_ROOT/tailwind.config.js" ] || [ -f "$PROJECT_ROOT/tailwind.config.ts" ]; then
        echo "   + Tailwind CSS detected"
    fi
fi

if [ -f "$PROJECT_ROOT/pyproject.toml" ] || [ -f "$PROJECT_ROOT/requirements.txt" ]; then
    if grep -qE "agno|phidata" "$PROJECT_ROOT/pyproject.toml" "$PROJECT_ROOT/requirements.txt" 2>/dev/null; then
        echo "   + Agno/Phidata detected"
    fi
fi

if [ -f "$MCP_CONFIG" ]; then
    # Merge non-destructively
    UPDATED=$(jq --argjson new "$MCP_DATA" '.mcpServers += $new' "$MCP_CONFIG")
    echo "$UPDATED" > "$MCP_CONFIG"
    echo "✅ MCP merged into $MCP_CONFIG"
else
    jq -n --argjson new "$MCP_DATA" '{"mcpServers": $new}' > "$MCP_CONFIG"
    echo "✅ MCP config created at $MCP_CONFIG"
fi

# ==============================================================================
# STEP 5: Evolutionary Git Hooks
# post-commit: marks evolution cycle
# post-merge / post-checkout: rebuilds stack-context if deps changed
# ==============================================================================
if [ -d "$PWD/.git/hooks" ]; then
    echo "🔗 Wiring Git hooks..."    # Central dispatcher
    cat << HOOK > "$PWD/.git/hooks/antigravity-sync"
#!/bin/bash
HOOK_TYPE=\$1

# Rebuild stack context when dependency manifests change
if [ "\$HOOK_TYPE" = "post-merge" ] || [ "\$HOOK_TYPE" = "post-checkout" ]; then
    CHANGED=\$(git diff --name-only HEAD@{1} HEAD 2>/dev/null || echo "")
    if echo "\$CHANGED" | grep -qE "^(package\.json|requirements\.txt|pyproject\.toml)$"; then
        echo "🔄 [Antigravity] Deps changed — rebuilding stack context..."
        bash "\$(git rev-parse --show-toplevel)/$SCRIPT_PATH_FROM_ROOT"
    fi
fi

# Mark evolution cycle after each commit
if [ "\$HOOK_TYPE" = "post-commit" ]; then
    KNOWLEDGE_DIR="\$HOME/.gemini/antigravity/knowledge"
    mkdir -p "\$KNOWLEDGE_DIR"
    echo "LAST_COMMIT: \$(git rev-parse HEAD)" > "\$KNOWLEDGE_DIR/evolution_trigger.tmp"
    echo "🧠 [Antigravity] Evolution cycle marked."
fi
HOOK
    chmod +x "$PWD/.git/hooks/antigravity-sync"

    inject_hook() {
        local HOOK_FILE="$PWD/.git/hooks/$1"
        local CMD="./.git/hooks/antigravity-sync $1"
        if [ -f "$HOOK_FILE" ]; then
            grep -q "antigravity-sync" "$HOOK_FILE" || printf "\n%s\n" "$CMD" >> "$HOOK_FILE"
        else
            printf "#!/bin/bash\n%s\n" "$CMD" > "$HOOK_FILE"
            chmod +x "$HOOK_FILE"
        fi
    }
    inject_hook "post-merge"
    inject_hook "post-checkout"
    inject_hook "post-commit"
    echo "✅ Git hooks wired."
else
    echo "⚠️  .git/hooks not found — run inside a git repo."
fi

# ==============================================================================
# DONE
# ==============================================================================
DEFAULT_MODEL="${AG_DEFAULT_MODEL:-gemini-3-flash}"
echo ""
echo "====================================================================="
echo "✅ Antigravity v3.1 — One-User-Per-Project Bootstrap Complete"
echo "   Project        : $PWD"
echo "   User           : $(whoami)"
echo "   Stack          : $STACK_TYPE"
echo "   Default model  : $DEFAULT_MODEL"
echo ""
echo "📁 Global (IDE reads):"
echo "   $MCP_CONFIG"
echo "   $AG_KNOWLEDGE_GLOBAL/stack-context.md"
echo "   $AG_KNOWLEDGE_GLOBAL/coding-standards.md  ← symlink → project"
echo ""
echo "📁 Project (git-tracked):"
echo "   $AG_PROJECT"
echo "   $AG_KNOWLEDGE_PROJECT/coding-standards.md  ← source of truth"
echo ""
echo "💡 Client Config Tip (Cursor/VSCode):"
echo "   To avoid frequent 'Accept' prompts, go to settings and enable 'Auto-approve'"
echo "   for the MCP servers listed in $MCP_CONFIG."
echo ""
echo "💡 To re-run bootstrap:"
echo "   bash $SCRIPT_PATH_FROM_ROOT"
echo "====================================================================="
