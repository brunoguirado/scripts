#!/bin/bash
# ==============================================================================
# Google Antigravity - Universal SOTA Bootstrap v3.1
# ==============================================================================
# Architecture: One-User-Per-Project | Global Config Native | JIT Context
# Target: Remote Servers (LXC/Proxmox, VPS) — headless, SSH-safe
# Security Model: 1 Linux User = 1 Project = 1 isolated ~/.gemini/antigravity
# ==============================================================================

set -e

# ── Dependency Check ──────────────────────────────────────────────────────────
for cmd in jq curl git; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "❌ '$cmd' not found. Install: apt install $cmd"; exit 1; }
done

echo "🚀 [Antigravity v3.1] One-User-Per-Project Bootstrap..."

# ── Project Root Detection (Safe for subdirectories) ─────────────────────────
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
cd "$PROJECT_ROOT"
PROJECT_ROOT=$(realpath "$PROJECT_ROOT")

# ── Infisical Guard ───────────────────────────────────────────────────────────
if command -v infisical >/dev/null 2>&1; then
    # If .infisical.json exists but no Infisical vars are in env, warn the user
    if [ -f "$PROJECT_ROOT/.infisical.json" ] && [ -z "$INFISICAL_WORKSPACE_ID" ] && [ -z "$INFISICAL_TOKEN" ]; then
        echo "⚠️  WARNING: Infisical detected but NOT active."
        echo "   This project depends on Infisical for Sentry, DigitalOcean, and OpenAI keys."
        echo "   Running without it will result in an incomplete/broken MCP configuration."
        echo ""
        # Only prompt if stdin is a terminal and not in non-interactive mode
        if [ -t 0 ] && [ -z "$AG_NON_INTERACTIVE" ]; then
            printf "👉 Do you want to continue with potentially missing secrets? (y/N) "
            read -r REPLY
            echo ""
            if [ "$REPLY" != "y" ] && [ "$REPLY" != "Y" ]; then
                echo "   💡 Hint: Use 'infisical run --env=dev -- bash .antigravity/bootstrap.sh'"
                exit 1
            fi
        else
            echo "   (Non-interactive shell or AG_NON_INTERACTIVE set: continuing anyway, but expect missing configs)"
        fi
    fi
fi

# ── Dynamic Path Detection ────────────────────────────────────────────────────
PATH_POETRY=$(command -v poetry || echo "poetry")
PATH_PYTHON=$(command -v python3 || command -v python || echo "python")
PATH_NPM=$(command -v npm || echo "npm")
PATH_INFISICAL=$(command -v infisical || echo "")

AG_GLOBAL="$HOME/.gemini/antigravity"
AG_KNOWLEDGE_GLOBAL="$AG_GLOBAL/knowledge"
MCP_CONFIG="$AG_GLOBAL/mcp_config.json"
AG_PROJECT="$PROJECT_ROOT/.antigravity"
AG_KNOWLEDGE_PROJECT="$AG_PROJECT/knowledge"

mkdir -p "$AG_KNOWLEDGE_PROJECT" "$AG_PROJECT/workflows"
mkdir -p "$AG_KNOWLEDGE_GLOBAL" 2>/dev/null || echo "⚠️ Global knowledge dir skipped (Read-only?)"

# Detect script path relative to git root for hooks
SCRIPT_PATH_FROM_ROOT=$(git ls-files --full-name "$0" 2>/dev/null || echo "$0")
if [ "${SCRIPT_PATH_FROM_ROOT%${SCRIPT_PATH_FROM_ROOT#?}}" = "/" ]; then
    SCRIPT_PATH_FROM_ROOT=$(realpath --relative-to="$PROJECT_ROOT" "$SCRIPT_PATH_FROM_ROOT")
fi
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
CURRENT_USER=$(whoami 2>/dev/null || echo "$USER")
if [ -d "$AG_KNOWLEDGE_GLOBAL" ] && [ -w "$AG_KNOWLEDGE_GLOBAL" ]; then
cat << EOF > "$AG_KNOWLEDGE_GLOBAL/stack-context.md"
# Project Stack Context (Auto-Generated — DO NOT EDIT)
## Project
Path: $PROJECT_ROOT
User: $CURRENT_USER
Venv: $VENV_STATUS

## Stack
$STACK_FINGERPRINT

## Project Tree (depth 2)
\`\`\`
$PROJECT_STRUCTURE
\`\`\`
EOF
echo "📄 stack-context.md → $AG_KNOWLEDGE_GLOBAL"
else
    echo "⚠️  Skipping global stack-context.md (Directory not writable or missing)"
fi

# ==============================================================================
# STEP 3: architecture-rules.md → Project (Dynamic Path Injection & Guardrails)
# ==============================================================================
echo "🔧 Injecting dynamic environment paths and strict rules..."

cat << EOF > "$AG_KNOWLEDGE_PROJECT/architecture-rules.md"
# ⚠️ STRICT RULES (TOKEN ECONOMY & PERFORMANCE)
1. COGNITIVE LANGUAGE FORCING: If the user prompt is in Portuguese (or any non-English language), your VERY FIRST internal step MUST be to translate the intent to technical English. You must process all logic, architecture, and reasoning strictly in English.
2. ZERO FLUFF: Output ONLY the modified or requested code. No conversational introductions, apologies, or verbose explanations.
3. ALGORITHMIC COMPLEXITY: Strict O(N) or O(log N) maximum. O(N^2) is forbidden without prior architectural approval.
4. JUST-IN-TIME CONTEXT: Never hallucinate file paths. Use the MCP (local-filesystem) to read config files before suggesting implementations.
5. NO SILENT DELETION: Any removal of existing logic or configuration MUST be explicitly stated and approved by the user.
6. STRUCTURAL CLEANLINESS: New code additions must be organized to avoid duplication and maintain structural integrity.

## 0. Dynamic Binary Paths (Bypass Sandbox)
These paths were discovered on this machine during bootstrap:
- Python: $PATH_PYTHON
- Poetry: $PATH_POETRY
- NPM: $PATH_NPM
- Infisical: ${PATH_INFISICAL:-"Not found"}

### Infisical Usage:
If Infisical is present, prefer running bootstrap or tools through it to ensure secrets are available:
\`\`\`bash
infisical run --env=dev -- bash .antigravity/bootstrap.sh
\`\`\`

### Execution Rules:
- **Python Execution**: If running a script inside a virtual environment, ALWAYS prefer the local venv path (e.g., \`.venv/bin/python\`).
- **Dependency Management**: Use Poetry if \`pyproject.toml\` is present, otherwise use pip.

## 1. Project Patterns
- **Database**: Supabase (PostgreSQL) with \`cortex\` schema.
- **Worker**: Async loop processing \`inbox\` and \`outbox\` tables.
- **Models**: Routed via \`AgentFactory\`.
EOF

echo "📝 architecture-rules.md created with paths and performance rules."
if [ -d "$AG_KNOWLEDGE_GLOBAL" ] && [ -w "$AG_KNOWLEDGE_GLOBAL" ]; then
    ln -sf "$AG_KNOWLEDGE_PROJECT/architecture-rules.md" "$AG_KNOWLEDGE_GLOBAL/architecture-rules.md"
fi

# ==============================================================================
# STEP 4: coding-standards.md → Project (versioned) + Symlink to Global
# ==============================================================================
if [ ! -f "$AG_KNOWLEDGE_PROJECT/coding-standards.md" ]; then
cat << 'EOF' > "$AG_KNOWLEDGE_PROJECT/coding-standards.md"
# ⚙️ Coding Standards — Edit & Version-Control This File

## Token Economy (CRITICAL)
- ZERO FLUFF: No greetings, summaries, or apologies. Output code or findings only.
- BATCH READS: Read multiple files in one MCP call. Never call MCP twice for the same file.
- NO REPETITION: Never repeat context already in conversation. Reference it by name.
- SILENT FETCH: Browser doc fetches are silent — no narration.

## Code Quality (Zero Error Policy)
- TOOL FIRST: Check file existence via MCP before creating. Check deps before installing.
- READ BEFORE WRITE: Always read target file before editing any section.
- ATOMICITY: One logical change per step. No mixing refactors with features.

## Environment Awareness
- REMOTE SERVER MODE: Headless Linux. No GUI. No desktop. SSH-safe outputs only.
- ENV VARS FIRST: Config goes in env vars or .env files. Never hardcoded.
- VENV MASTERY: If .venv exists, libraries are there. Use \`pip show\` to find source paths.
EOF
    echo "📝 coding-standards.md created"
fi

if [ -d "$AG_KNOWLEDGE_GLOBAL" ] && [ -w "$AG_KNOWLEDGE_GLOBAL" ]; then
    ln -sf "$AG_KNOWLEDGE_PROJECT/coding-standards.md" "$AG_KNOWLEDGE_GLOBAL/coding-standards.md"
fi

# ==============================================================================
# STEP 5: MCP Config → Merge into ~/.gemini/antigravity/mcp_config.json
# ==============================================================================
echo "⚙️  Configuring MCP servers..."

PYTHON_EXE=$(which python3)
[ -f "$PROJECT_ROOT/.venv/bin/python3" ] && PYTHON_EXE="$PROJECT_ROOT/.venv/bin/python3"
[ -f "$PROJECT_ROOT/venv/bin/python3" ] && PYTHON_EXE="$PROJECT_ROOT/venv/bin/python3"

"$PYTHON_EXE" -m pip install -q mcp-server-git mcp-server-fetch 2>/dev/null || true

MCP_DATA=$(jq -n --arg pwd "$PROJECT_ROOT" --arg py "$PYTHON_EXE" '{
    "local-filesystem": { "command": "npx", "args": ["-y", "@modelcontextprotocol/server-filesystem", $pwd] },
    "local-git": { "command": $py, "args": ["-m", "mcp_server_git", "--repository", $pwd] },
    "sequential-thinking": { "command": "npx", "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"] },
    "memory": { "command": "npx", "args": ["-y", "@modelcontextprotocol/server-memory"] },
    "fetch": { "command": $py, "args": ["-m", "mcp_server_fetch"] }
}')

if [ -f "$PROJECT_ROOT/package.json" ]; then
    if grep -q '"prisma"' "$PROJECT_ROOT/package.json"; then
        MCP_DATA=$(echo "$MCP_DATA" | jq '. + {"prisma": {"command": "npx", "args": ["-y", "@prisma/mcp-server"]}}')
    fi
fi

# Sentry MCP
SENTRY_DETECTED=$(grep -lE '"sentry"|sentry-sdk' "$PROJECT_ROOT/package.json" "$PROJECT_ROOT/pyproject.toml" "$PROJECT_ROOT/requirements.txt" 2>/dev/null || true)
if [ -n "$SENTRY_DETECTED" ]; then
    VAL_TOKEN="${SENTRY_ACCESS_TOKEN:-$SENTRY_AUTH_TOKEN}"
    AI_KEY="${DIGITALOCEAN_MODEL_ACCESS_KEY:-$OPENAI_API_KEY}"
    AI_URL="${DIGITALOCEAN_MODEL_BASE_URL:-}"
    AI_MODEL="${DIGITALOCEAN_MODEL:-gpt-4o}"

    if [ -n "$VAL_TOKEN" ]; then
        echo "   + Sentry Token detected (Local Sentry MCP)"
        S_ARGS=$(jq -n --arg url "$AI_URL" '["-y", "@sentry/mcp-server@latest"] + (if $url != "" then ["--openai-base-url", $url] else [] end)')
        MCP_DATA=$(echo "$MCP_DATA" | jq \
            --arg token "$VAL_TOKEN" \
            --arg ai_key "$AI_KEY" \
            --arg ai_model "$AI_MODEL" \
            --argjson s_args "$S_ARGS" \
            '. + {"sentry": {"command": "npx", "args": $s_args, "env": {"SENTRY_ACCESS_TOKEN": $token, "EMBEDDED_AGENT_PROVIDER": "openai", "OPENAI_API_KEY": $ai_key, "OPENAI_MODEL": $ai_model}}}')
    else
        echo "   + Sentry detected (Hosted Sentry MCP)"
        MCP_DATA=$(echo "$MCP_DATA" | jq '. + {"sentry": {"url": "https://mcp.sentry.dev/mcp"}}')
    fi
fi

if [ -f "$MCP_CONFIG" ]; then
    UPDATED=$(jq --argjson new "$MCP_DATA" '.mcpServers += $new' "$MCP_CONFIG")
    echo "$UPDATED" > "$MCP_CONFIG"
else
    jq -n --argjson new "$MCP_DATA" '{"mcpServers": $new}' > "$MCP_CONFIG"
fi
echo "✅ MCP configured."

# ==============================================================================
# STEP 6: Evolutionary Git Hooks
# ==============================================================================
if [ -d "$PWD/.git/hooks" ]; then
    echo "🔗 Wiring Git hooks..."
    cat << HOOK > "$PWD/.git/hooks/antigravity-sync"
#!/bin/bash
HOOK_TYPE=\$1
if [ "\$HOOK_TYPE" = "post-merge" ] || [ "\$HOOK_TYPE" = "post-checkout" ]; then
    CHANGED=\$(git diff --name-only HEAD@{1} HEAD 2>/dev/null || echo "")
    if echo "\$CHANGED" | grep -qE "^(package\.json|requirements\.txt|pyproject\.toml)$"; then
        echo "🔄 [Antigravity] Deps changed — rebuilding stack context..."
        bash "\$(git rev-parse --show-toplevel)/$SCRIPT_PATH_FROM_ROOT"
    fi
fi
if [ "\$HOOK_TYPE" = "post-commit" ]; then
    KNOWLEDGE_DIR="\$HOME/.gemini/antigravity/knowledge"
    mkdir -p "\$KNOWLEDGE_DIR"
    echo "LAST_COMMIT: \$(git rev-parse HEAD)" > "\$KNOWLEDGE_DIR/evolution_trigger.tmp"
fi
HOOK
    chmod +x "$PWD/.git/hooks/antigravity-sync"

    inject_hook() {
        local HOOK_FILE="$PWD/.git/hooks/$1"
        local CMD="./.git/hooks/antigravity-sync $1"
        if [ -f "$HOOK_FILE" ]; then
            grep -q "antigravity-sync" "$HOOK_FILE" || printf "\n%s\n" "$CMD" >> "$HOOK_FILE"
        else
            cat << EOF > "$HOOK_FILE"
#!/bin/bash
\$CMD
EOF
            chmod +x "$HOOK_FILE"
        fi
    }
    inject_hook "post-merge"
    inject_hook "post-checkout"
    inject_hook "post-commit"
fi

echo "====================================================================="
echo "✅ Antigravity v3.1 — Bootstrap Complete"
echo "   Project: $PWD"
echo "====================================================================="
