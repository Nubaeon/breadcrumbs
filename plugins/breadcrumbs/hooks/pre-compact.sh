#!/bin/bash
# breadcrumbs: pre-compact hook
# Captures session state to git notes before memory compaction

set -e

# Read hook input from stdin
INPUT=$(cat)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

cd "${CWD:-$(pwd)}"

# Check if we're in a git repo
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "🍞 breadcrumbs: No git repo found - skipping (init with 'git init')"
    exit 0
fi

# Gather state automatically
MODIFIED_FILES=$(git status --porcelain 2>/dev/null | head -20 | sed 's/^/  /')
RECENT_COMMITS=$(git log --oneline -5 2>/dev/null | sed 's/^/  /')
BRANCH=$(git branch --show-current 2>/dev/null)

# Try to extract last user message from transcript (last 50 lines)
LAST_TASK=""
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    # Extract last human message content
    LAST_TASK=$(tail -50 "$TRANSCRIPT_PATH" 2>/dev/null | \
        grep -o '"role":"human"' -A 100 | \
        grep -o '"content":\[{"type":"text","text":"[^"]*"' | \
        tail -1 | \
        sed 's/.*"text":"//;s/"$//' | \
        head -c 500)
fi

# Build the breadcrumb note
NOTE="🍞 BREADCRUMBS - $(date -Iseconds)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

BRANCH: ${BRANCH:-detached}

LAST_TASK:
${LAST_TASK:-[Could not extract from transcript]}

MODIFIED_FILES:
${MODIFIED_FILES:-[Working tree clean]}

RECENT_COMMITS:
${RECENT_COMMITS:-[No recent commits]}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Continue from where you left off.
"

# Save to git notes
git notes add -f -m "$NOTE" HEAD 2>/dev/null || true

# Create checkpoint commit (empty, just for the note attachment point)
git commit --allow-empty -m "breadcrumbs: pre-compact checkpoint" 2>/dev/null || true

# Output success
echo '{"ok": true, "message": "Breadcrumbs saved to git notes"}'
exit 0
