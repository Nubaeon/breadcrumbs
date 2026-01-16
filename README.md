# 🍞 breadcrumbs

**Survive context compacts. Dead simple.**

Before compact: auto-saves session state to git notes
After compact: auto-loads it back

No database. No external service. Just git.

---

## Install

```bash
# From Claude Code marketplace (when available)
claude plugin install breadcrumbs

# Or install from GitHub
claude plugin install Nubaeon/breadcrumbs

# Or test locally during development
claude --plugin-dir ./breadcrumbs
```

**Manual install:**
```bash
git clone https://github.com/Nubaeon/breadcrumbs ~/.claude/plugins/breadcrumbs
```

Then add to your `.claude/settings.json`:
```json
{
  "plugins": ["~/.claude/plugins/breadcrumbs"]
}
```

---

## What It Saves

When your context is about to compact, breadcrumbs captures:

- **Branch** — Where you are in git
- **Last task** — What you were working on (extracted from transcript)
- **Modified files** — Uncommitted changes
- **Recent commits** — What's been done

All stored in git notes. No external dependencies.

---

## What It Looks Like

After compaction, you'll see:

```
═══════════════════════════════════════════════════════════
📍 PREVIOUS SESSION CONTEXT (from git notes)
═══════════════════════════════════════════════════════════

🍞 BREADCRUMBS - 2025-01-16T12:30:00+00:00
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
Continue from where you left off.

═══════════════════════════════════════════════════════════
```

The AI picks up exactly where you left off.

---

## How It Works

1. **PreCompact hook** — Before memory compacts, runs `git notes add` with session state
2. **SessionStart hook** — On resume/compact, runs `git notes show` and injects context

That's it. Two shell scripts. ~50 lines total.

---

## For Higher-Stakes Work

breadcrumbs is intentionally minimal. For critical domains (healthcare, finance, safety-critical systems), consider [Empirica](https://github.com/Nubaeon/empirica) — the full epistemic framework with:

- Confidence vectors & calibration
- Goal tracking with subtasks
- Dead-end logging (what didn't work)
- Multi-agent coordination
- Audit trails

breadcrumbs is the 80/20 solution. Empirica is for when you need the other 20%.

---

## Requirements

- Claude Code CLI
- Git repository
- `jq` installed (for JSON parsing)

---

## License

MIT — do whatever you want.

---

<p align="center">
Part of the <a href="https://github.com/Nubaeon/empirica">Empirica</a> ecosystem.
</p>
