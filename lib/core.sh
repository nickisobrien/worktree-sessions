#!/bin/bash
# Core utilities and configuration loading

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Logging
error() { echo -e "${RED}Error: $1${NC}" >&2; }
warn() { echo -e "${YELLOW}$1${NC}"; }
info() { echo -e "${CYAN}$1${NC}"; }
success() { echo -e "${GREEN}$1${NC}"; }
debug() { [[ "${WT_DEBUG:-}" == "1" ]] && echo -e "${DIM}[debug] $1${NC}" >&2 || true; }

# Default configuration
WT_PROJECT_NAME=""
WT_PROJECT_ROOT=""
WT_WORKTREE_BASE=""
WT_TMUX_SESSION=""
WT_DEV_COMMAND=""
WT_MAIN_PANE_COMMAND=""
WT_BRANCH_BASE="origin/main"
WT_BRANCH_PREFIX=""
WT_PORT_START=3001
WT_PORT_END=3099
WT_PANE_LAYOUT="main-left"  # main-left, main-right, even-horizontal, even-vertical

# Config file locations
WT_GLOBAL_CONFIG="$HOME/.config/wt/config.sh"
WT_PROJECT_CONFIG=".wt/config.sh"

# Find project root by looking for .wt directory or .git
find_project_root() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/.wt" ]]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done

    # Fall back to git root if no .wt found
    git rev-parse --show-toplevel 2>/dev/null
}

# Load configuration files
load_project_config() {
    # Load global config first
    if [[ -f "$WT_GLOBAL_CONFIG" ]]; then
        debug "Loading global config: $WT_GLOBAL_CONFIG"
        source "$WT_GLOBAL_CONFIG"
    fi

    # Find and load project config
    WT_PROJECT_ROOT="$(find_project_root)"
    if [[ -n "$WT_PROJECT_ROOT" && -f "$WT_PROJECT_ROOT/$WT_PROJECT_CONFIG" ]]; then
        debug "Loading project config: $WT_PROJECT_ROOT/$WT_PROJECT_CONFIG"
        source "$WT_PROJECT_ROOT/$WT_PROJECT_CONFIG"
    fi

    # Set defaults based on project
    if [[ -z "$WT_PROJECT_NAME" && -n "$WT_PROJECT_ROOT" ]]; then
        WT_PROJECT_NAME="$(basename "$WT_PROJECT_ROOT")"
    fi

    if [[ -z "$WT_WORKTREE_BASE" && -n "$WT_PROJECT_NAME" ]]; then
        WT_WORKTREE_BASE="$HOME/.wt/worktrees/$WT_PROJECT_NAME"
    fi

    if [[ -z "$WT_TMUX_SESSION" && -n "$WT_PROJECT_NAME" ]]; then
        WT_TMUX_SESSION="wt-$WT_PROJECT_NAME"
    fi

    # Export for use in subprocesses
    export WT_PROJECT_NAME WT_PROJECT_ROOT WT_WORKTREE_BASE WT_TMUX_SESSION
    export WT_DEV_COMMAND WT_MAIN_PANE_COMMAND WT_BRANCH_BASE WT_BRANCH_PREFIX
    export WT_PORT_START WT_PORT_END WT_PANE_LAYOUT
}

# Ensure project is initialized
require_project() {
    if [[ -z "$WT_PROJECT_ROOT" ]]; then
        error "Not in a wt project. Run 'wt init' first."
        exit 1
    fi
}

# Get config/state file path for current project
get_state_file() {
    local name="$1"
    local state_dir="$HOME/.wt/state/$WT_PROJECT_NAME"
    mkdir -p "$state_dir"
    echo "$state_dir/$name"
}

# Run hook if it exists
run_hook() {
    local hook_name="$1"
    shift
    local hook_file="$WT_PROJECT_ROOT/.wt/hooks/$hook_name"

    if [[ -x "$hook_file" ]]; then
        debug "Running hook: $hook_name"
        "$hook_file" "$@"
        return $?
    elif [[ -f "$hook_file" ]]; then
        debug "Running hook (source): $hook_name"
        source "$hook_file" "$@"
        return $?
    fi
    return 0
}

# Check for required dependencies
check_dependency() {
    local cmd="$1"
    local install_hint="${2:-}"

    if ! command -v "$cmd" &>/dev/null; then
        error "$cmd is required but not installed."
        [[ -n "$install_hint" ]] && echo "  Install with: $install_hint"
        return 1
    fi
    return 0
}

# Validate worktree name
validate_name() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        error "Name must contain only letters, numbers, hyphens, and underscores"
        return 1
    fi
    return 0
}

# Get worktree path
get_worktree_path() {
    local name="$1"
    echo "$WT_WORKTREE_BASE/$name"
}

# Check if worktree exists
worktree_exists() {
    local name="$1"
    [[ -d "$(get_worktree_path "$name")" ]]
}

# List worktree names (simple)
list_worktree_names() {
    if [[ ! -d "$WT_WORKTREE_BASE" ]]; then
        return 0
    fi

    git -C "$WT_PROJECT_ROOT" worktree list --porcelain 2>/dev/null | \
        grep "^worktree " | cut -d' ' -f2- | while read -r path; do
        if [[ "$path" == "$WT_WORKTREE_BASE"* && "$path" != "$WT_PROJECT_ROOT" ]]; then
            basename "$path"
        fi
    done
}
