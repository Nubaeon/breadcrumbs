#!/bin/bash
# breadcrumbs: session-start hook
# Loads previous session state from git notes after compaction/resume
# Also loads Bayesian calibration from .breadcrumbs.yaml if present (Empirica integration)

set -e

# Read hook input from stdin
INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
SOURCE=$(echo "$INPUT" | jq -r '.source // "unknown"')

cd "${CWD:-$(pwd)}"

# Check if we're in a git repo
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    # Silent exit - no git repo, no breadcrumbs
    exit 0
fi

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)

# ==================== CALIBRATION (from .breadcrumbs.yaml) ====================
# Empirica exports Bayesian calibration to .breadcrumbs.yaml on POSTFLIGHT
# This provides instant calibration without DB queries

CALIBRATION=""
CONFIG_FILE=""
if [ -f ".breadcrumbs.yaml" ]; then
    CONFIG_FILE=".breadcrumbs.yaml"
elif [ -f "$GIT_ROOT/.breadcrumbs.yaml" ]; then
    CONFIG_FILE="$GIT_ROOT/.breadcrumbs.yaml"
fi

if [ -n "$CONFIG_FILE" ] && grep -q "^calibration:" "$CONFIG_FILE" 2>/dev/null; then
    # Extract calibration section (from "calibration:" to next top-level key or EOF)
    CALIBRATION=$(sed -n '/^calibration:/,/^[a-z]/p' "$CONFIG_FILE" 2>/dev/null | sed '$d')
    # If sed '$d' removed too much (EOF case), re-extract
    if [ -z "$CALIBRATION" ]; then
        CALIBRATION=$(sed -n '/^calibration:/,$p' "$CONFIG_FILE" 2>/dev/null)
    fi
fi

# ==================== GIT NOTES (task context from breadcrumbs) ====================
# Try to read git notes from HEAD (using 'breadcrumbs' namespace)
BREADCRUMBS_NOTES=$(git notes --ref=breadcrumbs show HEAD 2>/dev/null || echo "")

# If no notes on HEAD, check recent commits (in case of new commits since checkpoint)
if [ -z "$BREADCRUMBS_NOTES" ]; then
    for i in 1 2 3 4 5 6 7 8 9 10; do
        BREADCRUMBS_NOTES=$(git notes --ref=breadcrumbs show HEAD~$i 2>/dev/null || echo "")
        if [ -n "$BREADCRUMBS_NOTES" ] && echo "$BREADCRUMBS_NOTES" | grep -q "BREADCRUMBS"; then
            break
        fi
        BREADCRUMBS_NOTES=""
    done
fi

# ==================== GIT NOTES (epistemic state from empirica) ====================
# Try to read git notes from HEAD (using 'empirica-precompact' namespace)
EMPIRICA_NOTES=$(git notes --ref=empirica-precompact show HEAD 2>/dev/null || echo "")

# If no notes on HEAD, check recent commits
if [ -z "$EMPIRICA_NOTES" ]; then
    for i in 1 2 3 4 5 6 7 8 9 10; do
        EMPIRICA_NOTES=$(git notes --ref=empirica-precompact show HEAD~$i 2>/dev/null || echo "")
        if [ -n "$EMPIRICA_NOTES" ] && echo "$EMPIRICA_NOTES" | grep -q "EMPIRICA"; then
            break
        fi
        EMPIRICA_NOTES=""
    done
fi

# ==================== OUTPUT ====================
HAS_CONTEXT=false

# Output calibration if present
if [ -n "$CALIBRATION" ]; then
    HAS_CONTEXT=true
    cat << 'EOF'

╔═══════════════════════════════════════════════════════════════════╗
║  📊 BAYESIAN CALIBRATION (from .breadcrumbs.yaml)                 ║
╚═══════════════════════════════════════════════════════════════════╝

EOF
    echo "$CALIBRATION"
    cat << 'EOF'

Apply these bias corrections to your self-assessments.
EOF
fi

# Output breadcrumbs (task context) if present
if [ -n "$BREADCRUMBS_NOTES" ] && echo "$BREADCRUMBS_NOTES" | grep -q "BREADCRUMBS"; then
    HAS_CONTEXT=true
    cat << 'EOF'

╔═══════════════════════════════════════════════════════════════════╗
║  📍 TASK CONTEXT (from breadcrumbs git notes)                     ║
╚═══════════════════════════════════════════════════════════════════╝

EOF
    echo "$BREADCRUMBS_NOTES"
fi

# Output empirica epistemic state if present
if [ -n "$EMPIRICA_NOTES" ] && echo "$EMPIRICA_NOTES" | grep -q "EMPIRICA"; then
    HAS_CONTEXT=true
    cat << 'EOF'

╔═══════════════════════════════════════════════════════════════════╗
║  🧠 EPISTEMIC STATE (from empirica-precompact git notes)          ║
╚═══════════════════════════════════════════════════════════════════╝

EOF
    echo "$EMPIRICA_NOTES"
fi

# Final prompt if we loaded any context
if [ "$HAS_CONTEXT" = "true" ]; then
    cat << 'EOF'

╔═══════════════════════════════════════════════════════════════════╗
║  ⚡ Context loaded. Assess your epistemic state and continue.     ║
╚═══════════════════════════════════════════════════════════════════╝

EOF
fi

exit 0
