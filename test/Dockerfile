# Test environment for breadcrumbs plugin
# No Empirica, just Claude Code + git + jq

FROM node:20-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    git \
    jq \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# Create test user
RUN useradd -m -s /bin/bash tester
USER tester
WORKDIR /home/tester

# Copy breadcrumbs plugin
COPY --chown=tester:tester . /home/tester/.claude/plugins/breadcrumbs/

# Create a test git repo
RUN mkdir -p /home/tester/test-project && \
    cd /home/tester/test-project && \
    git init && \
    git config user.email "test@test.com" && \
    git config user.name "Tester" && \
    echo "# Test Project" > README.md && \
    git add . && \
    git commit -m "Initial commit"

WORKDIR /home/tester/test-project

# Start with bash - user controls when to launch claude
CMD ["bash"]
