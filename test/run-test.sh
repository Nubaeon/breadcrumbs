#!/bin/bash
# Quick test script for breadcrumbs plugin

set -e

echo "🍞 breadcrumbs plugin test"
echo "=========================="
echo ""

# Check requirements
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Install docker first."
    exit 1
fi

if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo "❌ ANTHROPIC_API_KEY not set"
    echo "   export ANTHROPIC_API_KEY=your-key"
    exit 1
fi

cd "$(dirname "$0")"

echo "Building test container..."
docker-compose build

echo ""
echo "Starting Claude Code with breadcrumbs plugin..."
echo "Try: 'create a file called test.txt with hello world'"
echo "Then: wait for compact or type /compact"
echo "Then: start new session and check if breadcrumbs loaded"
echo ""

docker-compose run --rm breadcrumbs-test
