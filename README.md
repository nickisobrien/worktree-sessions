# wt - Git Worktree Session Manager

Manage multiple development sessions with git worktrees and tmux. Each worktree gets an isolated branch, port, and tmux window.

Perfect for parallel feature development, especially when using AI coding assistants.

## Features

- **Isolated environments** - Each worktree has its own branch, port, and tmux window
- **Instant setup** - Hard-link node_modules, copy configs, allocate ports automatically
- **Interactive TUI** - Beautiful control center powered by [gum](https://github.com/charmbracelet/gum)
- **Extensible hooks** - Customize setup/teardown with shell scripts
- **Project-agnostic** - Works with any git repository, any tech stack

## Quick Start

```bash
# Install (add to PATH)
git clone https://github.com/nickisobrien/worktree-sessions.git ~/.wt
echo 'export PATH="$HOME/.wt:$PATH"' >> ~/.zshrc

# Initialize in your project
cd your-project
wt init

# Edit configuration
vim .wt/config.sh

# Create your first worktree
wt new my-feature

# Launch control center
wt
```

## Requirements

- **tmux** - Terminal multiplexer (usually pre-installed on macOS)
- **gum** - Interactive prompts: `brew install gum`

## Commands

| Command | Description |
|---------|-------------|
| `wt` | Launch/return to control center |
| `wt new <name>` | Create new worktree |
| `wt list` | List all worktrees with status |
| `wt kill <name>` | Kill a worktree |
| `wt kill-all` | Kill all worktrees |
| `wt config` | View/edit configuration |
| `wt config prefix <val>` | Set branch prefix (e.g., `nick/`) |

## Configuration

### Project Config (`.wt/config.sh`)

Created by `wt init`:

```bash
# Project identification
WT_PROJECT_NAME="my-app"

# Branch to base new worktrees on
WT_BRANCH_BASE="origin/main"

# Port range for dev servers
WT_PORT_START=3001
WT_PORT_END=3099

# Commands to run in tmux panes
WT_MAIN_PANE_COMMAND="claude --dangerously-skip-permissions"
WT_DEV_COMMAND="yarn dev --port $PORT"

# Pane layout: main-left, main-right, even-horizontal, even-vertical, single
WT_PANE_LAYOUT="main-left"
```

### Global Config (`~/.config/wt/config.sh`)

User-wide settings:

```bash
# Branch prefix for all projects
WT_BRANCH_PREFIX="yourname/"
```

## Hooks

Add executable scripts to `.wt/hooks/` for custom setup:

- **`post-create`** - Runs after worktree is created
- **`pre-delete`** - Runs before worktree is removed

Available variables in hooks:
- `$WORKTREE_NAME` - Name of the worktree
- `$WORKTREE_PATH` - Full path to worktree
- `$WORKTREE_BRANCH` - Branch name
- `$WORKTREE_PORT` - Allocated port

### Example Hooks

Copy from `examples/hooks/`:

```bash
# Link node_modules instantly
cp examples/hooks/node-modules.sh .wt/hooks/post-create
chmod +x .wt/hooks/post-create

# Or chain multiple hooks
cat > .wt/hooks/post-create << 'EOF'
#!/bin/bash
source "$(dirname "$0")/../../examples/hooks/node-modules.sh"
source "$(dirname "$0")/../../examples/hooks/env-copy.sh"
source "$(dirname "$0")/../../examples/hooks/postgres-database.sh"
EOF
```

## Tmux Window Layout

Each worktree gets a tmux window with your configured layout:

### `main-left` (default)
```
┌─────────────────────┬─────────────────────┐
│                     │  dev server         │
│  main command       │  (WT_DEV_COMMAND)   │
│  (WT_MAIN_PANE_CMD) ├─────────────────────┤
│                     │  empty shell        │
└─────────────────────┴─────────────────────┘
```

### Navigation

- **Ctrl-b w** - List all windows, select to switch
- **wt** - Return to control center from any terminal

## Directory Structure

```
~/.wt/
├── state/<project>/     # Port allocations, etc.
└── worktrees/<project>/ # Worktree directories

<project>/.wt/
├── config.sh            # Project configuration
└── hooks/
    ├── post-create      # Runs after worktree creation
    └── pre-delete       # Runs before worktree deletion
```

## Tips

### Quick Aliases

Add to `~/.zshrc`:

```bash
# Quick worktree control
alias wtc='wt'
alias wtn='wt new'
alias wtl='wt list'
```

### tmux Keybinding

Add to `~/.tmux.conf`:

```bash
# Ctrl-b C to jump to control center
bind-key C select-window -t wt-*:control
```

## Comparison with Plain Git Worktrees

| Feature | Plain git worktree | wt |
|---------|-------------------|-----|
| Branch isolation | ✓ | ✓ |
| Port allocation | Manual | Automatic |
| tmux integration | Manual | Automatic |
| Dependency linking | Manual | Hook-based |
| Database per worktree | Manual | Hook-based |
| Interactive UI | No | Yes |

## License

MIT
