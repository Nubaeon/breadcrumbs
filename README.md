# 🍞 breadcrumbs

**Survive context compacts. Dead simple.**

Before compact: auto-saves session state to git notes
After compact: auto-loads it back

No database. No external service. Just git.

---

## Install

**Local installation:**
```bash
# Clone to your local plugins directory
mkdir -p ~/.claude/plugins/local
git clone https://github.com/Nubaeon/breadcrumbs ~/.claude/plugins/local/breadcrumbs
```

Then add a local marketplace config at `~/.claude/plugins/local/.claude-plugin/marketplace.json`:
```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "local",
  "description": "Local plugins",
  "owner": { "name": "Local", "email": "dev@localhost" },
  "plugins": [{
    "name": "breadcrumbs",
    "description": "Survive context compacts with git notes",
    "version": "0.1.0",
    "author": { "name": "Nubaeon", "email": "nubaeon@getempirica.com" },
    "source": "./breadcrumbs",
    "category": "productivity"
  }]
}
```

---

## What It Saves

When your context is about to compact, breadcrumbs captures:

- **Branch** — Where you are in git
- **Last task** — What you were working on (extracted from transcript)
- **Modified files** — Uncommitted changes
- **Recent commits** — What's been done
- **Epistemic state** — Prompts for confidence assessment

All stored in git notes. No external dependencies.

---

## Configuration

Create `.breadcrumbs.yaml` in your project root to customize:

```yaml
# Git context to capture
git:
  recent_commits: 5          # Number of recent commits
  modified_files: true       # List modified/staged files
  current_branch: true       # Show current branch

# Epistemic state tracking
epistemic:
  enabled: true
  scale: "1-5 (1=guessing, 3=reasonable, 5=certain)"
  track_uncertainties: true  # Prompt for what's unclear
  track_decisions: true      # Prompt for key decisions made

# Task context
task:
  extract_last_task: 500     # Max chars from transcript
```

Without a config file, sensible defaults are used.

---

## Epistemic Tracking

breadcrumbs prompts Claude to self-assess after context restoration:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EPISTEMIC STATE (self-assess on resume)

Please assess your current epistemic state:
- CONFIDENCE: Rate 1-5 where you are on understanding this codebase/task
- UNCERTAINTIES: What are you unsure about? What needs verification?
- KEY_DECISIONS: What important decisions were made that you should remember?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Why this matters:** Claude can meaningfully assess its own uncertainty without heavy infrastructure. This proves AI can be trusted to quantify epistemic state when given the right prompts.

---

## What It Looks Like

After compaction:

```
╔═══════════════════════════════════════════════════════════════════╗
║  📍 SESSION CONTEXT RESTORED (breadcrumbs from git notes)         ║
╚═══════════════════════════════════════════════════════════════════╝

🍞 BREADCRUMBS - 2026-01-17T12:30:00+00:00
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

BRANCH: feature/auth-flow

LAST_TASK:
implement the OAuth callback handler

MODIFIED_FILES:
  M src/auth/callback.ts
  M src/config.ts

RECENT_COMMITS:
  abc1234 feat: add OAuth initiation
  def5678 refactor: extract auth utils

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EPISTEMIC STATE (self-assess on resume)

Please assess your current epistemic state:
- CONFIDENCE: Rate 1-5 where you are on understanding this codebase/task
- UNCERTAINTIES: What are you unsure about? What needs verification?
- KEY_DECISIONS: What important decisions were made that you should remember?

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Continue from where you left off.

╔═══════════════════════════════════════════════════════════════════╗
║  ⚡ Context loaded. Assess your epistemic state and continue.     ║
╚═══════════════════════════════════════════════════════════════════╝
```

---

## How It Works

1. **PreCompact hook** — Before memory compacts, saves state to `git notes`
2. **SessionStart hook** — On compact/resume, reads `git notes` and injects context

Two shell scripts. ~150 lines total. Zero external dependencies beyond git and jq.

---

## For Higher-Stakes Work

breadcrumbs is intentionally minimal. For critical domains (healthcare, finance, safety-critical systems), consider [Empirica](https://github.com/Nubaeon/empirica) — the full epistemic framework with:

- 13-dimensional confidence vectors & calibration
- Goal tracking with subtasks
- Dead-end logging (what didn't work)
- Multi-agent coordination
- Bayesian belief updating
- Audit trails

breadcrumbs is the 80/20 solution. Empirica is for when you need the other 20%.

---

## Requirements

- Claude Code CLI (v2.0.76+ for SessionStart fix)
- Git repository
- `jq` installed (for JSON parsing)

---

## License

MIT — do whatever you want.

---

<p align="center">
Part of the <a href="https://github.com/Nubaeon/empirica">Empirica</a> ecosystem.
</p>
