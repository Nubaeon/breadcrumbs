#!/bin/bash
# breadcrumbs-doctor: Verify installation and diagnose issues
# Usage: bash ~/.claude/plugins/local/breadcrumbs/breadcrumbs-doctor.sh

echo "🍞 breadcrumbs doctor - checking installation..."
echo ""

ERRORS=0
WARNINGS=0

# ==================== DEPENDENCIES ====================

echo "━━━ Dependencies ━━━"

# git
if command -v git &>/dev/null; then
    echo "✅ git: $(git --version | head -1)"
else
    echo "❌ git: NOT FOUND"
    ((ERRORS++))
fi

# jq
if command -v jq &>/dev/null; then
    echo "✅ jq: $(jq --version)"
else
    echo "❌ jq: NOT FOUND (required for hooks)"
    echo "   Install: apt install jq (or brew install jq)"
    ((ERRORS++))
fi

# gh (optional)
if command -v gh &>/dev/null; then
    echo "✅ gh: $(gh --version | head -1) (optional, for PR context)"
else
    echo "⚪ gh: not installed (optional, for PR context)"
fi

echo ""

# ==================== GIT CONFIG ====================

echo "━━━ Git Configuration ━━━"

if git config user.email &>/dev/null; then
    echo "✅ user.email: $(git config user.email)"
else
    echo "❌ user.email: NOT SET (required for git notes)"
    echo "   Run: git config --global user.email 'you@example.com'"
    ((ERRORS++))
fi

if git config user.name &>/dev/null; then
    echo "✅ user.name: $(git config user.name)"
else
    echo "❌ user.name: NOT SET (required for git notes)"
    echo "   Run: git config --global user.name 'Your Name'"
    ((ERRORS++))
fi

echo ""

# ==================== PLUGIN FILES ====================

echo "━━━ Plugin Files ━━━"

PLUGIN_DIR="$HOME/.claude/plugins/local/breadcrumbs"

if [ -d "$PLUGIN_DIR" ]; then
    echo "✅ Plugin directory: $PLUGIN_DIR"
else
    echo "❌ Plugin directory: NOT FOUND"
    echo "   Run installer or clone manually"
    ((ERRORS++))
fi

if [ -f "$PLUGIN_DIR/hooks/pre-compact.sh" ]; then
    echo "✅ pre-compact.sh: present"
    if [ -x "$PLUGIN_DIR/hooks/pre-compact.sh" ]; then
        echo "   └─ executable: yes"
    else
        echo "   └─ ⚠️  executable: no (run: chmod +x)"
        ((WARNINGS++))
    fi
else
    echo "❌ pre-compact.sh: NOT FOUND"
    ((ERRORS++))
fi

if [ -f "$PLUGIN_DIR/hooks/session-start.sh" ]; then
    echo "✅ session-start.sh: present"
else
    echo "❌ session-start.sh: NOT FOUND"
    ((ERRORS++))
fi

echo ""

# ==================== MARKETPLACE ====================

echo "━━━ Marketplace Registration ━━━"

MARKETPLACE_FILE="$HOME/.claude/plugins/local/.claude-plugin/marketplace.json"

if [ -f "$MARKETPLACE_FILE" ]; then
    echo "✅ marketplace.json: present"
    if grep -q '"breadcrumbs"' "$MARKETPLACE_FILE" 2>/dev/null; then
        echo "   └─ breadcrumbs registered: yes"
    else
        echo "   └─ ⚠️  breadcrumbs not in plugins list"
        ((WARNINGS++))
    fi
else
    echo "⚠️  marketplace.json: NOT FOUND (may be okay if hooks configured manually)"
    ((WARNINGS++))
fi

echo ""

# ==================== CURRENT PROJECT ====================

echo "━━━ Current Project ━━━"

if git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "✅ In git repo: $(git rev-parse --show-toplevel)"

    # Check for project hooks
    if [ -f ".claude/settings.json" ]; then
        echo "✅ .claude/settings.json: present"
        if grep -q "pre-compact" ".claude/settings.json" 2>/dev/null; then
            echo "   └─ PreCompact hook: configured"
        else
            echo "   └─ ⚠️  PreCompact hook: NOT configured"
            ((WARNINGS++))
        fi
        if grep -q "session-start" ".claude/settings.json" 2>/dev/null; then
            echo "   └─ SessionStart hook: configured"
        else
            echo "   └─ ⚠️  SessionStart hook: NOT configured"
            ((WARNINGS++))
        fi
    else
        echo "⚠️  .claude/settings.json: NOT FOUND"
        echo "   Hooks need to be configured for breadcrumbs to work"
        ((WARNINGS++))
    fi

    # Check for existing notes (using breadcrumbs namespace)
    if git notes --ref=breadcrumbs show HEAD &>/dev/null; then
        echo "✅ Git notes on HEAD: present"
        echo "   └─ Preview:"
        git notes --ref=breadcrumbs show HEAD | head -5 | sed 's/^/      /'
    else
        echo "⚪ Git notes on HEAD: none (will be created on first compact)"
    fi

    # Check for config file
    if [ -f ".breadcrumbs.yaml" ]; then
        echo "✅ .breadcrumbs.yaml: present (custom config)"
    else
        echo "⚪ .breadcrumbs.yaml: not present (using defaults)"
    fi
else
    echo "⚪ Not in a git repository (cd to a project to check project-specific config)"
fi

echo ""

# ==================== FUNCTIONAL TEST ====================

echo "━━━ Functional Test ━━━"

if [ $ERRORS -eq 0 ] && git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "Running pre-compact hook test..."
    RESULT=$(echo '{"cwd": "'$(pwd)'"}' | bash "$PLUGIN_DIR/hooks/pre-compact.sh" 2>&1)

    if echo "$RESULT" | grep -q '"ok": true'; then
        echo "✅ pre-compact hook: WORKING"

        # Verify notes saved (using breadcrumbs namespace)
        if git notes --ref=breadcrumbs show HEAD &>/dev/null; then
            echo "✅ git notes: saved successfully"
        else
            echo "❌ git notes: save failed despite ok response"
            ((ERRORS++))
        fi
    else
        echo "❌ pre-compact hook: FAILED"
        echo "   Error: $RESULT"
        ((ERRORS++))
    fi
else
    echo "⚪ Skipping functional test (errors above or not in git repo)"
fi

echo ""

# ==================== SUMMARY ====================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✅ All checks passed! breadcrumbs is ready."
elif [ $ERRORS -eq 0 ]; then
    echo "⚠️  $WARNINGS warning(s) - breadcrumbs may work with limitations"
else
    echo "❌ $ERRORS error(s), $WARNINGS warning(s) - breadcrumbs needs attention"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
