#!/bin/bash
# breadcrumbs installer - one-line install for Claude Code
# Usage: curl -fsSL https://raw.githubusercontent.com/Nubaeon/breadcrumbs/main/install.sh | bash

set -e

PLUGIN_DIR="$HOME/.claude/plugins/local/breadcrumbs"
MARKETPLACE_DIR="$HOME/.claude/plugins/local/.claude-plugin"

echo "🍞 Installing breadcrumbs plugin for Claude Code..."

# ==================== PRE-FLIGHT CHECKS ====================

# Check git is available
if ! command -v git &>/dev/null; then
    echo "❌ Error: git is required but not installed"
    exit 1
fi

# Check jq is available (needed by hooks)
if ! command -v jq &>/dev/null; then
    echo "⚠️  Warning: jq not installed. Install with: apt install jq (or brew install jq)"
    echo "   The plugin will fail without jq."
fi

# Check git user is configured
if ! git config --global user.email &>/dev/null; then
    echo "⚠️  Warning: Git user not configured. Required for git notes."
    echo "   Run: git config --global user.email 'you@example.com'"
    echo "   Run: git config --global user.name 'Your Name'"
fi

# ==================== INSTALL ====================

# Create directories
mkdir -p "$HOME/.claude/plugins/local"
mkdir -p "$MARKETPLACE_DIR"

# Clone or update
if [ -d "$PLUGIN_DIR" ]; then
    echo "📦 Updating existing installation..."
    cd "$PLUGIN_DIR"
    git pull --ff-only origin main 2>/dev/null || git pull origin main
else
    echo "📦 Cloning breadcrumbs..."
    git clone https://github.com/Nubaeon/breadcrumbs.git "$PLUGIN_DIR"
fi

# Create marketplace.json if not exists
if [ ! -f "$MARKETPLACE_DIR/marketplace.json" ]; then
    echo "📝 Creating local marketplace config..."
    cat > "$MARKETPLACE_DIR/marketplace.json" << 'EOF'
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "local",
  "description": "Local plugins",
  "owner": { "name": "Local", "email": "dev@localhost" },
  "plugins": []
}
EOF
fi

# Add breadcrumbs to marketplace if not already present
if ! grep -q '"name": "breadcrumbs"' "$MARKETPLACE_DIR/marketplace.json" 2>/dev/null; then
    echo "📝 Registering plugin in marketplace..."
    # Use jq if available, otherwise use sed
    if command -v jq &>/dev/null; then
        jq '.plugins += [{
            "name": "breadcrumbs",
            "description": "Survive context compacts with git notes",
            "version": "2.0.0",
            "author": { "name": "Nubaeon", "email": "nubaeon@getempirica.com" },
            "source": "./breadcrumbs",
            "category": "productivity"
        }]' "$MARKETPLACE_DIR/marketplace.json" > "$MARKETPLACE_DIR/marketplace.json.tmp"
        mv "$MARKETPLACE_DIR/marketplace.json.tmp" "$MARKETPLACE_DIR/marketplace.json"
    else
        echo "⚠️  jq not available - please manually add breadcrumbs to marketplace.json"
    fi
fi

# Make hooks executable
chmod +x "$PLUGIN_DIR/hooks/"*.sh 2>/dev/null || true

# ==================== VERIFY ====================

echo ""
echo "✅ breadcrumbs installed successfully!"
echo ""
echo "📍 Location: $PLUGIN_DIR"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "HOOKS AUTO-DISCOVERY:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Hooks are configured via hooks/hooks.json and should"
echo "auto-discover when Claude Code loads the plugin."
echo ""
echo "If hooks don't auto-load, add to ~/.claude/settings.json:"
echo ""
cat << 'EOF'
{
  "hooks": {
    "PreCompact": [{
      "matcher": "auto|manual",
      "hooks": [{
        "type": "command",
        "command": "bash ~/.claude/plugins/local/breadcrumbs/hooks/pre-compact.sh"
      }]
    }],
    "SessionStart": [{
      "matcher": "compact|resume",
      "hooks": [{
        "type": "command",
        "command": "bash ~/.claude/plugins/local/breadcrumbs/hooks/session-start.sh"
      }]
    }]
  }
}
EOF
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "OPTIONAL: Create .breadcrumbs.yaml in your project root"
echo "to customize what context is captured."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🍞 Happy breadcrumb-ing!"
