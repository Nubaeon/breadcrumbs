#!/bin/bash
# breadcrumbs v2: pre-compact hook
# Captures session state to git notes before memory compaction
# Enhanced with: git user check, build status, PR context, better errors

set -e

# Read hook input from stdin
INPUT=$(cat)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

cd "${CWD:-$(pwd)}"

# ==================== PRE-FLIGHT CHECKS ====================

# Check if we're in a git repo
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo '{"ok": false, "error": "Not a git repository"}'
    exit 0
fi

# Check git user is configured (required for git notes)
if ! git config user.email &>/dev/null; then
    echo '{"ok": false, "error": "Git user not configured", "hint": "Run: git config --global user.email you@example.com && git config --global user.name \"Your Name\""}'
    exit 1
fi

# Check jq is available
if ! command -v jq &>/dev/null; then
    echo '{"ok": false, "error": "jq not installed", "hint": "Run: apt install jq"}'
    exit 1
fi

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)

# ==================== CONFIG LOADING ====================

CONFIG_FILE=""
if [ -f ".breadcrumbs.yaml" ]; then
    CONFIG_FILE=".breadcrumbs.yaml"
elif [ -f "$GIT_ROOT/.breadcrumbs.yaml" ]; then
    CONFIG_FILE="$GIT_ROOT/.breadcrumbs.yaml"
fi

# Simple YAML parser (no external deps)
yaml_get_nested() {
    local section="$1"
    local key="$2"
    local file="$3"
    sed -n "/^${section}:/,/^[a-z]/p" "$file" 2>/dev/null | grep "^[[:space:]]*${key}:" | sed "s/^[[:space:]]*${key}:[[:space:]]*//" | tr -d '"'
}

# Defaults
GIT_COMMITS=5
GIT_MODIFIED=true
GIT_BRANCH=true
EPISTEMIC_ENABLED=true
EPISTEMIC_SCALE="1-5"
TRACK_UNCERTAINTIES=true
TRACK_DECISIONS=true
TASK_EXTRACT=500
# New v2 options
BUILD_STATUS=true
TEST_STATUS=false
PR_CONTEXT=true
TODO_SCAN=false

# Load config
if [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
    GIT_COMMITS=$(yaml_get_nested "git" "recent_commits" "$CONFIG_FILE"); GIT_COMMITS=${GIT_COMMITS:-5}
    [ "$(yaml_get_nested "git" "modified_files" "$CONFIG_FILE")" = "false" ] && GIT_MODIFIED=false
    [ "$(yaml_get_nested "git" "current_branch" "$CONFIG_FILE")" = "false" ] && GIT_BRANCH=false
    [ "$(yaml_get_nested "epistemic" "enabled" "$CONFIG_FILE")" = "false" ] && EPISTEMIC_ENABLED=false
    EPISTEMIC_SCALE=$(yaml_get_nested "epistemic" "scale" "$CONFIG_FILE"); EPISTEMIC_SCALE=${EPISTEMIC_SCALE:-"1-5"}
    [ "$(yaml_get_nested "epistemic" "track_uncertainties" "$CONFIG_FILE")" = "false" ] && TRACK_UNCERTAINTIES=false
    [ "$(yaml_get_nested "epistemic" "track_decisions" "$CONFIG_FILE")" = "false" ] && TRACK_DECISIONS=false
    TASK_EXTRACT=$(yaml_get_nested "task" "extract_last_task" "$CONFIG_FILE"); TASK_EXTRACT=${TASK_EXTRACT:-500}
    # v2 options
    [ "$(yaml_get_nested "build" "enabled" "$CONFIG_FILE")" = "false" ] && BUILD_STATUS=false
    [ "$(yaml_get_nested "test" "enabled" "$CONFIG_FILE")" = "true" ] && TEST_STATUS=true
    [ "$(yaml_get_nested "pr" "enabled" "$CONFIG_FILE")" = "false" ] && PR_CONTEXT=false
    [ "$(yaml_get_nested "todos" "enabled" "$CONFIG_FILE")" = "true" ] && TODO_SCAN=true
fi

# ==================== GATHER CONTEXT ====================

BRANCH=""
[ "$GIT_BRANCH" = "true" ] && BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")

MODIFIED_FILES=""
[ "$GIT_MODIFIED" = "true" ] && MODIFIED_FILES=$(git status --porcelain 2>/dev/null | head -20 | sed 's/^/  /')

RECENT_COMMITS=""
[ "$GIT_COMMITS" -gt 0 ] 2>/dev/null && RECENT_COMMITS=$(git log --oneline -"$GIT_COMMITS" 2>/dev/null | sed 's/^/  /')

# Extract last task from transcript
LAST_TASK=""
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ] && [ "$TASK_EXTRACT" -gt 0 ]; then
    LAST_TASK=$(tail -100 "$TRANSCRIPT_PATH" 2>/dev/null | \
        grep -o '"role":"human"' -A 200 | \
        grep -o '"content":\[{"type":"text","text":"[^"]*"' | \
        tail -1 | \
        sed 's/.*"text":"//;s/"$//' | \
        head -c "$TASK_EXTRACT" 2>/dev/null) || true
fi

# NEW: Build status (detect build system and check last result)
BUILD_INFO=""
if [ "$BUILD_STATUS" = "true" ]; then
    if [ -f "package.json" ]; then
        # Check for recent build errors in common locations
        if [ -f ".next/build-manifest.json" ]; then
            BUILD_INFO="Next.js build present"
        elif [ -f "dist/index.js" ] || [ -d "dist" ]; then
            BUILD_INFO="dist/ exists (built)"
        elif [ -f "node_modules/.cache/.eslintcache" ]; then
            BUILD_INFO="ESLint cache present"
        else
            BUILD_INFO="No build artifacts detected"
        fi
    elif [ -f "Cargo.toml" ]; then
        [ -d "target/release" ] && BUILD_INFO="Rust release build present" || BUILD_INFO="No release build"
    elif [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
        [ -d "dist" ] || [ -d "*.egg-info" ] && BUILD_INFO="Python package built" || BUILD_INFO="Not built"
    fi
fi

# NEW: PR context (if gh CLI available)
PR_INFO=""
if [ "$PR_CONTEXT" = "true" ] && command -v gh &>/dev/null; then
    PR_INFO=$(gh pr view --json number,title,state 2>/dev/null | jq -r '"PR #\(.number): \(.title) [\(.state)]"' 2>/dev/null) || true
fi

# NEW: TODO scan
TODOS=""
if [ "$TODO_SCAN" = "true" ]; then
    TODOS=$(grep -rn "TODO\|FIXME\|HACK\|XXX" --include="*.ts" --include="*.js" --include="*.py" --include="*.rs" . 2>/dev/null | head -10 | sed 's/^/  /') || true
fi

# ==================== BUILD NOTE ====================

NOTE="🍞 BREADCRUMBS v2 - $(date -Iseconds)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

[ -n "$BRANCH" ] && NOTE="$NOTE

BRANCH: $BRANCH"

[ -n "$PR_INFO" ] && NOTE="$NOTE
$PR_INFO"

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

[ -n "$RECENT_COMMITS" ] && NOTE="$NOTE

RECENT_COMMITS:
$RECENT_COMMITS"

[ -n "$BUILD_INFO" ] && NOTE="$NOTE

BUILD_STATUS: $BUILD_INFO"

[ -n "$TODOS" ] && NOTE="$NOTE

IN-CODE TODOs:
$TODOS"

# Epistemic section
if [ "$EPISTEMIC_ENABLED" = "true" ]; then
    NOTE="$NOTE

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EPISTEMIC STATE (self-assess on resume)

Assess your current state:
- CONFIDENCE: Rate $EPISTEMIC_SCALE on understanding this codebase/task"
    [ "$TRACK_UNCERTAINTIES" = "true" ] && NOTE="$NOTE
- UNCERTAINTIES: What needs verification?"
    [ "$TRACK_DECISIONS" = "true" ] && NOTE="$NOTE
- KEY_DECISIONS: Important decisions to remember?"
    NOTE="$NOTE
- NEXT_STEPS: What were you about to do?"
fi

NOTE="$NOTE

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Continue from where you left off."

# ==================== SAVE ====================

if git notes add -f -m "$NOTE" HEAD 2>&1; then
    echo '{"ok": true, "message": "Breadcrumbs saved to git notes", "config": "'"${CONFIG_FILE:-default}"'", "version": "2.0"}'
else
    echo '{"ok": false, "error": "Failed to save git notes"}'
    exit 1
fi
