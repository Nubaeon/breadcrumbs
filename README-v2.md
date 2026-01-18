# 🍞 breadcrumbs v2

**Survive context compacts. Dead simple.**

Before compact: auto-saves session state to git notes
After compact: auto-loads it back + prompts for epistemic self-assessment

No database. No external service. Just git.

---

## Why This Exists

Claude Code sessions can run for hours. When context compacts (automatically or via `/compact`), you lose:
- What you were working on
- What decisions you made and why
- What uncertainties remained
- What you were about to do next

**breadcrumbs** captures this context before compaction and reinjects it on resume.

---

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/Nubaeon/breadcrumbs/main/install.sh | bash
```

Or manual:
```bash
mkdir -p ~/.claude/plugins/local
git clone https://github.com/Nubaeon/breadcrumbs ~/.claude/plugins/local/breadcrumbs
```

Then add hooks to your project (see Configuration below).

---

## What It Captures

| Context | Description |
|---------|-------------|
| **Branch** | Current git branch |
| **Last task** | Extracted from conversation transcript |
| **Modified files** | Uncommitted changes (git status) |
| **Recent commits** | What's been done recently |
| **PR context** | If working on a PR (requires `gh` CLI) |
| **Build status** | Detects build artifacts |
| **In-code TODOs** | Scans for TODO/FIXME comments |
| **Epistemic prompts** | Confidence, uncertainties, decisions, next steps |

All stored in git notes on HEAD. Zero external dependencies beyond git + jq.

---

## Configuration

### 1. Add Hooks to Project

Add to your project's `.claude/settings.json`:

```json
{
  "hooks": {
    "PreCompact": [{
      "matcher": "auto|manual",
      "hooks": [{
        "type": "command",
        "command": "bash ~/.claude/plugins/local/breadcrumbs/hooks/pre-compact.sh",
        "timeout": 30
      }]
    }],
    "SessionStart": [{
      "matcher": "compact|resume",
      "hooks": [{
        "type": "command",
        "command": "bash ~/.claude/plugins/local/breadcrumbs/hooks/session-start.sh",
        "timeout": 10
      }]
    }]
  }
}
```

### 2. Customize Capture (Optional)

Create `.breadcrumbs.yaml` in your project root:

```yaml
# Git context
git:
  recent_commits: 5
  modified_files: true
  current_branch: true

# Epistemic tracking
epistemic:
  enabled: true
  scale: "1-5 (1=guessing, 3=reasonable, 5=certain)"
  track_uncertainties: true
  track_decisions: true

# Task extraction
task:
  extract_last_task: 500  # chars from transcript

# v2 features
build:
  enabled: true   # Detect build artifacts
pr:
  enabled: true   # Show PR context (requires gh CLI)
todos:
  enabled: false  # Scan for TODO/FIXME (can be noisy)
```

---

## 🔄 Ralph Wiggum Integration

**breadcrumbs** pairs perfectly with [ralph-wiggum](https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum) for autonomous loops.

### The Problem Ralph Has

Ralph keeps Claude looping until task completion. But during long loops:
1. Context compacts happen (automatically at ~100k tokens)
2. Claude loses its *reasoning* about why it made decisions
3. Files persist, but the mental state doesn't

### The Solution

```
Ralph Loop Iteration N
        ↓
    [working...]
        ↓
    Context Compact Triggered
        ↓
    🍞 breadcrumbs PreCompact hook saves:
       - What was being worked on
       - Uncertainties remaining
       - Key decisions made
       - Next planned steps
        ↓
    Context Compacted
        ↓
    🍞 breadcrumbs SessionStart hook injects saved context
        ↓
    Claude resumes with epistemic continuity
        ↓
Ralph Loop Iteration N+1
```

### Combined Setup

```json
{
  "hooks": {
    "PreCompact": [{
      "matcher": "auto|manual",
      "hooks": [{
        "type": "command",
        "command": "bash ~/.claude/plugins/local/breadcrumbs/hooks/pre-compact.sh",
        "timeout": 30
      }]
    }],
    "SessionStart": [{
      "matcher": "compact|resume",
      "hooks": [{
        "type": "command",
        "command": "bash ~/.claude/plugins/local/breadcrumbs/hooks/session-start.sh",
        "timeout": 10
      }]
    }],
    "Stop": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "bash ~/.claude/plugins/local/ralph-wiggum/hooks/stop-hook.sh"
      }]
    }]
  }
}
```

---

## Prerequisites

- **git** - For git notes storage
- **jq** - For JSON parsing (`apt install jq`)
- **git user configured** - Required for git notes:
  ```bash
  git config --global user.email "you@example.com"
  git config --global user.name "Your Name"
  ```

---

## How It Works

### PreCompact Hook
1. Reads session transcript to extract last task
2. Gathers git context (branch, status, recent commits)
3. Optionally checks PR context, build status, TODOs
4. Saves everything to `git notes` on HEAD

### SessionStart Hook
1. Reads git notes from HEAD
2. Displays context in a formatted box
3. Prompts for epistemic self-assessment

### Storage
- Notes stored in default git notes ref (`refs/notes/commits`)
- Survives across sessions (persisted in git)
- Visible with `git notes show HEAD`
- Pushed with `git push origin refs/notes/*:refs/notes/*`

---

## Troubleshooting

### "Failed to save git notes"
```bash
# Check git user is configured
git config user.email
git config user.name

# If empty, configure:
git config --global user.email "you@example.com"
git config --global user.name "Your Name"
```

### "jq: command not found"
```bash
# Ubuntu/Debian
apt install jq

# macOS
brew install jq
```

### Notes not appearing after compact
Check hooks are registered:
```bash
cat .claude/settings.json | jq '.hooks'
```

### Verify manually
```bash
# Test pre-compact
echo '{"cwd": "'$(pwd)'"}' | bash ~/.claude/plugins/local/breadcrumbs/hooks/pre-compact.sh

# Check notes
git notes show HEAD

# Test session-start
echo '{"trigger": "compact", "cwd": "'$(pwd)'"}' | bash ~/.claude/plugins/local/breadcrumbs/hooks/session-start.sh
```

---

## License

MIT

---

## Credits

- Built for the [Claude Code](https://github.com/anthropics/claude-code) ecosystem
- Inspired by epistemic tracking in [Empirica](https://github.com/Nubaeon/empirica)
- Designed to complement [ralph-wiggum](https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum)

**Two shell scripts. ~200 lines. Epistemic continuity.**
