#!/bin/bash
# Create a new worktree

source "$WT_ROOT/lib/ports.sh"
source "$WT_ROOT/lib/tmux.sh"

wt_new() {
    require_project

    local name=""
    local branch=""
    local use_existing=false
    local no_tmux=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --branch|-b)
                branch="$2"
                shift 2
                ;;
            --existing|-e)
                use_existing=true
                shift
                ;;
            --no-tmux)
                no_tmux=true
                shift
                ;;
            -*)
                error "Unknown option: $1"
                return 1
                ;;
            *)
                name="$1"
                shift
                ;;
        esac
    done

    # Interactive mode if no name
    if [[ -z "$name" ]]; then
        echo -e "${BOLD}Create New Worktree${NC}"
        echo ""
        read -p "Worktree name: " name
        if [[ -z "$name" ]]; then
            error "Name is required"
            return 1
        fi
    fi

    # Validate name
    validate_name "$name" || return 1

    # Check if already exists
    if worktree_exists "$name"; then
        error "Worktree '$name' already exists"
        return 1
    fi

    # Determine branch name
    if [[ -z "$branch" ]]; then
        branch="${WT_BRANCH_PREFIX}${name}"
    fi

    local worktree_path="$(get_worktree_path "$name")"

    # Ensure base directory exists
    mkdir -p "$WT_WORKTREE_BASE"

    # Fetch from remote
    info "Fetching from origin..."
    if [[ "$use_existing" == true ]]; then
        git -C "$WT_PROJECT_ROOT" fetch origin 2>/dev/null || true
    else
        git -C "$WT_PROJECT_ROOT" fetch origin "${WT_BRANCH_BASE#origin/}" 2>/dev/null || true
    fi

    # Create worktree
    info "Creating worktree '$name' with branch '$branch'..."

    if [[ "$use_existing" == true ]]; then
        # Check for existing branch
        if git -C "$WT_PROJECT_ROOT" show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
            git -C "$WT_PROJECT_ROOT" worktree add "$worktree_path" "$branch"
        elif git -C "$WT_PROJECT_ROOT" show-ref --verify --quiet "refs/remotes/origin/$branch" 2>/dev/null; then
            git -C "$WT_PROJECT_ROOT" worktree add --track -b "$branch" "$worktree_path" "origin/$branch"
        else
            error "Branch '$branch' not found locally or on origin"
            return 1
        fi
    else
        # Create new branch from base
        git -C "$WT_PROJECT_ROOT" branch --no-track "$branch" "$WT_BRANCH_BASE" 2>/dev/null || true
        git -C "$WT_PROJECT_ROOT" worktree add "$worktree_path" "$branch"
    fi

    success "  Created worktree at $worktree_path"

    # Allocate port
    local port="$(allocate_port "$name")"
    success "  Allocated port $port"

    # Export variables for hooks
    export WORKTREE_NAME="$name"
    export WORKTREE_PATH="$worktree_path"
    export WORKTREE_BRANCH="$branch"
    export WORKTREE_PORT="$port"

    # Run post-create hook
    run_hook "post-create"

    # Create tmux window
    if [[ "$no_tmux" == false ]]; then
        info "Creating tmux window..."
        ensure_session
        if create_worktree_window "$name" "$worktree_path" "$port"; then
            success "  Created tmux window '$name'"
        fi
    fi

    echo ""
    success "Worktree '$name' created!"
    echo ""
    echo -e "  ${BOLD}Path:${NC}   $worktree_path"
    echo -e "  ${BOLD}Branch:${NC} $branch"
    echo -e "  ${BOLD}Port:${NC}   $port"
    echo ""

    if [[ "$no_tmux" == false ]] && session_exists; then
        echo -e "Switch to it: ${CYAN}wt${NC} then select '$name'"
    else
        echo -e "To start working:"
        echo -e "  ${CYAN}cd $worktree_path${NC}"
    fi
}
