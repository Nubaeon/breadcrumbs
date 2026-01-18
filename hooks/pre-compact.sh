#!/bin/bash
# breadcrumbs: pre-compact hook
# Captures session state to git notes before memory compaction
# Reads .breadcrumbs.yaml for configuration

set -e

# Debug mode (set BREADCRUMBS_DEBUG=1 to enable)
debug() {
    [ "${BREADCRUMBS_DEBUG:-0}" = "1" ] && echo "[breadcrumbs] $*" >&2
    return 0  # Always succeed (don't fail with set -e)
}

# Read hook input from stdin
INPUT=$(cat)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

debug "transcript_path=$TRANSCRIPT_PATH"
debug "cwd=$CWD"

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
    # Extract value, strip quotes and whitespace
    sed -n "/^${section}:/,/^[a-z]/p" "$file" 2>/dev/null | \
        grep "^[[:space:]]*${key}:" | \
        sed "s/^[[:space:]]*${key}:[[:space:]]*//" | \
        tr -d '"' | \
        tr -d "'" | \
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
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
debug "config_file=$CONFIG_FILE"
if [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
    debug "Loading config from $CONFIG_FILE"
    GIT_COMMITS=$(yaml_get_nested "git" "recent_commits" "$CONFIG_FILE")
    GIT_COMMITS=${GIT_COMMITS:-5}

    val=$(yaml_get_nested "git" "modified_files" "$CONFIG_FILE")
    [ "$val" = "false" ] && GIT_MODIFIED=false

    val=$(yaml_get_nested "git" "current_branch" "$CONFIG_FILE")
    [ "$val" = "false" ] && GIT_BRANCH=false

    val=$(yaml_get_nested "epistemic" "enabled" "$CONFIG_FILE")
    # Only disable if explicitly set to "false" or "no" or "0"
    case "$val" in
        false|no|0|False|No|FALSE|NO) EPISTEMIC_ENABLED=false ;;
    esac

    EPISTEMIC_SCALE=$(yaml_get_nested "epistemic" "scale" "$CONFIG_FILE")
    EPISTEMIC_SCALE=${EPISTEMIC_SCALE:-"1-5"}

    val=$(yaml_get_nested "epistemic" "track_uncertainties" "$CONFIG_FILE")
    case "$val" in
        false|no|0|False|No|FALSE|NO) TRACK_UNCERTAINTIES=false ;;
    esac

    val=$(yaml_get_nested "epistemic" "track_decisions" "$CONFIG_FILE")
    case "$val" in
        false|no|0|False|No|FALSE|NO) TRACK_DECISIONS=false ;;
    esac

    TASK_EXTRACT=$(yaml_get_nested "task" "extract_last_task" "$CONFIG_FILE")
    TASK_EXTRACT=${TASK_EXTRACT:-500}

    debug "epistemic_enabled=$EPISTEMIC_ENABLED scale=$EPISTEMIC_SCALE"
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

# Extract last task from transcript using jq for proper JSON parsing
# Claude Code transcripts are JSONL format with nested message structure:
# Human input: {type: "user", message: {role: "user", content: "string"}}
# Tool result: {type: "user", message: {..., content: [{type: "tool_result", ...}]}}
LAST_TASK=""
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ] && [ "$TASK_EXTRACT" -gt 0 ]; then
    debug "Extracting last task from: $TRANSCRIPT_PATH"
    # Read file in reverse, find first user message with actual human text (not tool results)
    # Human input has content as STRING; tool results have content as ARRAY
    LAST_TASK=$(tac "$TRANSCRIPT_PATH" 2>/dev/null | while IFS= read -r line; do
        # Skip empty lines
        [ -z "$line" ] && continue
        # Check if this is a user message (outer type field)
        msg_type=$(echo "$line" | jq -r '.type // empty' 2>/dev/null)
        if [ "$msg_type" = "user" ]; then
            # Check if content is a string (human input) vs array (tool result)
            text=$(echo "$line" | jq -r '
                if (.message.content | type) == "string" then
                    .message.content
                elif (.message.content | type) == "array" then
                    .message.content[] | select(.type == "text") | .text
                else
                    empty
                end // empty
            ' 2>/dev/null | head -1)
            # Skip interrupt messages and empty text
            if [ -n "$text" ] && [ "$text" != "[Request interrupted by user]" ] && [ "$text" != "[Request interrupted by user for tool use]" ]; then
                echo "$text"
                break
            fi
        fi
    done | head -c "$TASK_EXTRACT")
    debug "Extracted task length: ${#LAST_TASK}"
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

# Save to git notes on HEAD (using 'breadcrumbs' namespace to avoid conflicts)
git notes --ref=breadcrumbs add -f -m "$NOTE" HEAD 2>/dev/null || true

# Output for Claude's context
echo '{"ok": true, "message": "Breadcrumbs saved to git notes", "config": "'"${CONFIG_FILE:-default}"'"}'
exit 0
