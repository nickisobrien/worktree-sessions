#!/bin/bash
# Example wt configuration for a Next.js project
# Copy to: .wt/config.sh

WT_PROJECT_NAME="my-nextjs-app"

# Base branch for new worktrees
WT_BRANCH_BASE="origin/main"

# Port range
WT_PORT_START=3001
WT_PORT_END=3099

# Command for main pane (e.g., your AI coding tool)
WT_MAIN_PANE_COMMAND="claude --dangerously-skip-permissions"

# Dev server command ($PORT is substituted)
WT_DEV_COMMAND="yarn dev --port \$PORT"

# Layout: main-left puts claude on left, dev server on right
WT_PANE_LAYOUT="main-left"
