#!/bin/bash
# breadcrumbs: session-start hook
# Loads previous session state from git notes after compaction/resume

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

# Try to read git notes from HEAD (using 'breadcrumbs' namespace)
NOTES=$(git notes --ref=breadcrumbs show HEAD 2>/dev/null || echo "")

# If no notes on HEAD, check recent commits (in case of new commits since checkpoint)
if [ -z "$NOTES" ]; then
    for i in 1 2 3 4 5 6 7 8 9 10; do
        NOTES=$(git notes --ref=breadcrumbs show HEAD~$i 2>/dev/null || echo "")
        if [ -n "$NOTES" ] && echo "$NOTES" | grep -q "BREADCRUMBS"; then
            break
        fi
        NOTES=""
    done
fi

# If we found breadcrumbs, output them for Claude's context
if [ -n "$NOTES" ] && echo "$NOTES" | grep -q "BREADCRUMBS"; then
    cat << 'EOF'

╔═══════════════════════════════════════════════════════════════════╗
║  📍 SESSION CONTEXT RESTORED (breadcrumbs from git notes)         ║
╚═══════════════════════════════════════════════════════════════════╝

EOF
    echo "$NOTES"
    cat << 'EOF'

╔═══════════════════════════════════════════════════════════════════╗
║  ⚡ Context loaded. Assess your epistemic state and continue.     ║
╚═══════════════════════════════════════════════════════════════════╝

EOF
fi

exit 0
