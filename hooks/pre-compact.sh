#!/bin/bash
# breadcrumbs: pre-compact hook
# Captures session state to git notes before memory compaction
# Reads .breadcrumbs.yaml for configuration

set -e

# Read hook input from stdin
INPUT=$(cat)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

cd "${CWD:-$(pwd)}"

# Check if we're in a git repo
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo '{"ok": false, "message": "No git repo found"}'
    exit 0
fi

# Find config file (check current dir and git root)
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
CONFIG_FILE=""
if [ -f ".breadcrumbs.yaml" ]; then
    CONFIG_FILE=".breadcrumbs.yaml"
elif [ -f "$GIT_ROOT/.breadcrumbs.yaml" ]; then
    CONFIG_FILE="$GIT_ROOT/.breadcrumbs.yaml"
fi

# Simple YAML parser functions (no external deps)
yaml_get() {
    local key="$1"
    local file="$2"
    grep "^${key}:" "$file" 2>/dev/null | sed "s/^${key}:[[:space:]]*//" | tr -d '"'
}

yaml_get_nested() {
    local section="$1"
    local key="$2"
    local file="$3"
    sed -n "/^${section}:/,/^[a-z]/p" "$file" 2>/dev/null | grep "^[[:space:]]*${key}:" | sed "s/^[[:space:]]*${key}:[[:space:]]*//" | tr -d '"'
}

# Default config values
GIT_COMMITS=5
GIT_MODIFIED=true
GIT_BRANCH=true
EPISTEMIC_ENABLED=true
EPISTEMIC_SCALE="1-5"
TRACK_UNCERTAINTIES=true
TRACK_DECISIONS=true
TASK_EXTRACT=500

# Load config if exists
if [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
    GIT_COMMITS=$(yaml_get_nested "git" "recent_commits" "$CONFIG_FILE")
    GIT_COMMITS=${GIT_COMMITS:-5}

    val=$(yaml_get_nested "git" "modified_files" "$CONFIG_FILE")
    [ "$val" = "false" ] && GIT_MODIFIED=false

    val=$(yaml_get_nested "git" "current_branch" "$CONFIG_FILE")
    [ "$val" = "false" ] && GIT_BRANCH=false

    val=$(yaml_get_nested "epistemic" "enabled" "$CONFIG_FILE")
    [ "$val" = "false" ] && EPISTEMIC_ENABLED=false

    EPISTEMIC_SCALE=$(yaml_get_nested "epistemic" "scale" "$CONFIG_FILE")
    EPISTEMIC_SCALE=${EPISTEMIC_SCALE:-"1-5"}

    val=$(yaml_get_nested "epistemic" "track_uncertainties" "$CONFIG_FILE")
    [ "$val" = "false" ] && TRACK_UNCERTAINTIES=false

    val=$(yaml_get_nested "epistemic" "track_decisions" "$CONFIG_FILE")
    [ "$val" = "false" ] && TRACK_DECISIONS=false

    TASK_EXTRACT=$(yaml_get_nested "task" "extract_last_task" "$CONFIG_FILE")
    TASK_EXTRACT=${TASK_EXTRACT:-500}
fi

# Gather git context
BRANCH=""
if [ "$GIT_BRANCH" = "true" ]; then
    BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
fi

MODIFIED_FILES=""
if [ "$GIT_MODIFIED" = "true" ]; then
    MODIFIED_FILES=$(git status --porcelain 2>/dev/null | head -20 | sed 's/^/  /')
fi

RECENT_COMMITS=""
if [ "$GIT_COMMITS" -gt 0 ] 2>/dev/null; then
    RECENT_COMMITS=$(git log --oneline -"$GIT_COMMITS" 2>/dev/null | sed 's/^/  /')
fi

# Extract last task from transcript
LAST_TASK=""
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ] && [ "$TASK_EXTRACT" -gt 0 ]; then
    LAST_TASK=$(tail -100 "$TRANSCRIPT_PATH" 2>/dev/null | \
        grep -o '"role":"human"' -A 200 | \
        grep -o '"content":\[{"type":"text","text":"[^"]*"' | \
        tail -1 | \
        sed 's/.*"text":"//;s/"$//' | \
        head -c "$TASK_EXTRACT")
fi

# Build the breadcrumb note
NOTE="🍞 BREADCRUMBS - $(date -Iseconds)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -n "$BRANCH" ]; then
    NOTE="$NOTE

BRANCH: $BRANCH"
fi

NOTE="$NOTE

LAST_TASK:
${LAST_TASK:-[Could not extract from transcript]}"

if [ -n "$MODIFIED_FILES" ]; then
    NOTE="$NOTE

MODIFIED_FILES:
$MODIFIED_FILES"
else
    NOTE="$NOTE

MODIFIED_FILES: [Working tree clean]"
fi

if [ -n "$RECENT_COMMITS" ]; then
    NOTE="$NOTE

RECENT_COMMITS:
$RECENT_COMMITS"
fi

# Add epistemic section if enabled
if [ "$EPISTEMIC_ENABLED" = "true" ]; then
    NOTE="$NOTE

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EPISTEMIC STATE (self-assess on resume)

Please assess your current epistemic state:
- CONFIDENCE: Rate $EPISTEMIC_SCALE where you are on understanding this codebase/task"

    if [ "$TRACK_UNCERTAINTIES" = "true" ]; then
        NOTE="$NOTE
- UNCERTAINTIES: What are you unsure about? What needs verification?"
    fi

    if [ "$TRACK_DECISIONS" = "true" ]; then
        NOTE="$NOTE
- KEY_DECISIONS: What important decisions were made that you should remember?"
    fi
fi

NOTE="$NOTE

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Continue from where you left off."

# Save to git notes on HEAD
git notes add -f -m "$NOTE" HEAD 2>/dev/null || true

# Output for Claude's context
echo '{"ok": true, "message": "Breadcrumbs saved to git notes", "config": "'"${CONFIG_FILE:-default}"'"}'
exit 0
