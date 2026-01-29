#!/bin/bash
# Interactive setup wizard for wt
# Launches Claude with a prompt to help configure wt for your project

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Check if we're in a git repo
if ! git rev-parse --git-dir &>/dev/null; then
    echo "Error: Not in a git repository"
    echo "Run this from your project directory: cd your-project && ~/.wt/setup.sh"
    exit 1
fi

# Check if already initialized
if [[ -d ".wt" ]]; then
    echo -e "${CYAN}Project already initialized with wt${NC}"
    echo ""
    echo "To reconfigure, edit .wt/config.sh"
    echo "To start the control center, run: wt"
    exit 0
fi

PROJECT_NAME="$(basename "$PWD")"
PROJECT_PATH="$PWD"

echo -e "${BOLD}wt Setup Wizard${NC}"
echo ""
echo -e "This will launch Claude to help configure wt for ${CYAN}$PROJECT_NAME${NC}"
echo ""

# Build the prompt
PROMPT=$(cat << 'PROMPT_EOF'
I need help setting up wt (worktree-sessions) for this project. wt is a git worktree session manager that creates isolated development environments with tmux.

Please help me configure it by:

1. First, look at my project structure to understand what kind of project this is (check package.json, Cargo.toml, go.mod, etc.)

2. Run `~/.wt/wt init` to create the basic .wt/ directory structure

3. Then help me configure .wt/config.sh with appropriate settings:
   - WT_DEV_COMMAND: The command to start my dev server (e.g., "yarn dev --port $PORT", "cargo run", "go run .")
   - WT_MAIN_PANE_COMMAND: What to run in the main pane (default: leave empty for shell, or "claude --dangerously-skip-permissions")
   - WT_BRANCH_BASE: The base branch (usually "origin/main")

4. Set up appropriate hooks in .wt/hooks/ based on my project type:
   - For Node.js: Copy node-modules.sh and env-copy.sh hooks
   - For projects with .env files: Set up env copying
   - For projects with Docker postgres: Set up database hooks

5. Ask me about my branch naming preference and set it globally with `wt config prefix <myname>/`

The hook examples are in ~/.wt/examples/hooks/. You can cat them to see their contents.

After setup, show me how to create my first worktree with `wt new <name>`.
PROMPT_EOF
)

# Check if claude is available
if ! command -v claude &>/dev/null; then
    echo "Error: claude CLI not found"
    echo "Install Claude Code first: https://claude.ai/code"
    exit 1
fi

# Launch claude with the prompt
exec claude "$PROMPT"
