#!/bin/bash
# breadcrumbs: session-start hook
# Loads previous session state from git notes

set -e

# Read hook input from stdin
INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
TRIGGER=$(echo "$INPUT" | jq -r '.trigger // "unknown"')

cd "${CWD:-$(pwd)}"

# Check if we're in a git repo
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "🍞 breadcrumbs: No git repo found - session context unavailable"
    exit 0
fi

# Try to read git notes from HEAD
NOTES=$(git notes show HEAD 2>/dev/null || echo "")

# If no notes, check parent commits (in case of new commits since checkpoint)
if [ -z "$NOTES" ]; then
    for i in 1 2 3 4 5; do
        NOTES=$(git notes show HEAD~$i 2>/dev/null || echo "")
        if [ -n "$NOTES" ]; then
            break
        fi
    done
fi

# If we found breadcrumbs, inject them as context
if [ -n "$NOTES" ] && echo "$NOTES" | grep -q "BREADCRUMBS"; then
    # Output goes to Claude as additional context
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "📍 PREVIOUS SESSION CONTEXT (from git notes)"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "$NOTES"
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo ""
fi

exit 0
