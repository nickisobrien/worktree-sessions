#!/bin/bash
# Initialize wt in a project

wt_init() {
    local project_root="${1:-$PWD}"
    local project_name="$(basename "$project_root")"
    local wt_dir="$project_root/.wt"

    # Check if already initialized
    if [[ -d "$wt_dir" ]]; then
        warn "Project already initialized at $wt_dir"
        echo "Edit $wt_dir/config.sh to modify settings"
        return 0
    fi

    # Check if this is a git repo
    if ! git -C "$project_root" rev-parse --git-dir &>/dev/null; then
        error "Not a git repository: $project_root"
        return 1
    fi

    info "Initializing wt in $project_root..."

    # Create directory structure
    mkdir -p "$wt_dir/hooks"

    # Create config file
    cat > "$wt_dir/config.sh" << EOF
#!/bin/bash
# wt configuration for $project_name
# Edit these values to customize your worktree setup

# Project identification
WT_PROJECT_NAME="$project_name"

# Where to store worktrees (default: ~/.wt/worktrees/<project>)
# WT_WORKTREE_BASE="\$HOME/.wt/worktrees/$project_name"

# tmux session name (default: wt-<project>)
# WT_TMUX_SESSION="wt-$project_name"

# Branch to base new worktrees on
WT_BRANCH_BASE="origin/main"

# Port range for dev servers
WT_PORT_START=3001
WT_PORT_END=3099

# Commands to run in tmux panes
# Use \$PORT for the allocated port number

# Main pane command (left side) - e.g., your coding tool
# WT_MAIN_PANE_COMMAND=""

# Dev server command (right side)
# WT_DEV_COMMAND="npm run dev -- --port \$PORT"

# Pane layout: main-left, main-right, even-horizontal, even-vertical, single
WT_PANE_LAYOUT="main-left"
EOF

    # Create example hooks
    cat > "$wt_dir/hooks/post-create.example" << 'EOF'
#!/bin/bash
# Post-create hook - runs after worktree is created
# Available variables:
#   $WORKTREE_NAME - name of the worktree
#   $WORKTREE_PATH - full path to worktree
#   $WORKTREE_BRANCH - branch name
#   $WORKTREE_PORT - allocated port

# Example: Copy environment file
# if [[ -f "$WT_PROJECT_ROOT/.env" ]]; then
#     cp "$WT_PROJECT_ROOT/.env" "$WORKTREE_PATH/.env"
# fi

# Example: Link node_modules (hard links for speed)
# if [[ -d "$WT_PROJECT_ROOT/node_modules" ]]; then
#     cp -Rl "$WT_PROJECT_ROOT/node_modules" "$WORKTREE_PATH/node_modules"
# fi

# Example: Create .env.local with port overrides
# cat > "$WORKTREE_PATH/.env.local" << ENVEOF
# PORT=$WORKTREE_PORT
# NEXT_PUBLIC_APP_URL=http://localhost:$WORKTREE_PORT
# ENVEOF

echo "post-create hook completed for $WORKTREE_NAME"
EOF

    cat > "$wt_dir/hooks/pre-delete.example" << 'EOF'
#!/bin/bash
# Pre-delete hook - runs before worktree is removed
# Available variables:
#   $WORKTREE_NAME - name of the worktree
#   $WORKTREE_PATH - full path to worktree

# Example: Drop database
# docker exec postgres dropdb -U postgres "myapp_wt_$WORKTREE_NAME" 2>/dev/null

echo "pre-delete hook completed for $WORKTREE_NAME"
EOF

    success "Initialized wt in $wt_dir"
    echo ""
    echo "Next steps:"
    echo "  1. Edit ${CYAN}$wt_dir/config.sh${NC} to configure your project"
    echo "  2. Copy and customize hooks in ${CYAN}$wt_dir/hooks/${NC}"
    echo "  3. Run ${CYAN}wt new <name>${NC} to create your first worktree"
    echo ""
    echo "Optionally add .wt/ to .gitignore if you don't want to share config"
}
