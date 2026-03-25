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
