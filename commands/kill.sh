#!/bin/bash
# Kill a worktree

source "$WT_ROOT/lib/ports.sh"
source "$WT_ROOT/lib/tmux.sh"

wt_kill() {
    require_project

    local name=""
    local remove_worktree=false
    local force=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --remove|-r)
                remove_worktree=true
                shift
                ;;
            --force|-f)
                force=true
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
        echo -e "${BOLD}Kill Worktree${NC}"
        echo ""
        source "$WT_ROOT/commands/list.sh"
        wt_list
        echo ""
        read -p "Worktree name to kill: " name
        if [[ -z "$name" ]]; then
            error "Name is required"
            return 1
        fi
    fi

    local worktree_path="$(get_worktree_path "$name")"

    # Check if exists
    if ! worktree_exists "$name"; then
        error "Worktree '$name' does not exist"
        return 1
    fi

    # Ask about removal if not specified
    if [[ "$remove_worktree" == false && "$force" == false ]]; then
        echo ""
        read -p "Also remove git worktree files? (y/N): " remove_answer
        if [[ "$remove_answer" =~ ^[Yy]$ ]]; then
            remove_worktree=true
        fi
    fi

    # Export for hooks
    export WORKTREE_NAME="$name"
    export WORKTREE_PATH="$worktree_path"

    # Run pre-delete hook
    run_hook "pre-delete"

    # Kill tmux window
    if kill_worktree_window "$name"; then
        success "  Killed tmux window '$name'"
    else
        warn "  No tmux window found for '$name'"
    fi

    # Release port
    info "Releasing port..."
    release_port "$name"
    success "  Released port"

    # Remove worktree if requested
    if [[ "$remove_worktree" == true ]]; then
        info "Removing git worktree..."

        # Check for uncommitted changes
        if [[ "$force" == false ]]; then
            if ! git -C "$worktree_path" diff --quiet 2>/dev/null || \
               ! git -C "$worktree_path" diff --cached --quiet 2>/dev/null; then
                warn "Worktree has uncommitted changes"
                read -p "Force removal? (y/N): " force_answer
                if [[ ! "$force_answer" =~ ^[Yy]$ ]]; then
                    echo "Aborted. Worktree files kept at: $worktree_path"
                    return 0
                fi
                force=true
            fi
        fi

        # Remove worktree
        if [[ "$force" == true ]]; then
            git -C "$WT_PROJECT_ROOT" worktree remove "$worktree_path" --force 2>/dev/null || rm -rf "$worktree_path"
        else
            git -C "$WT_PROJECT_ROOT" worktree remove "$worktree_path" 2>/dev/null || rm -rf "$worktree_path"
        fi
        success "  Removed worktree"

        # Optionally delete branch
        local branch="$(git -C "$WT_PROJECT_ROOT" branch --list "*$name*" 2>/dev/null | head -1 | tr -d ' *')"
        if [[ -n "$branch" && "$force" == false ]]; then
            read -p "Delete branch '$branch'? (y/N): " delete_branch
            if [[ "$delete_branch" =~ ^[Yy]$ ]]; then
                git -C "$WT_PROJECT_ROOT" branch -D "$branch" 2>/dev/null || true
                success "  Deleted branch '$branch'"
            fi
        fi
    else
        echo ""
        warn "Worktree files kept at: $worktree_path"
        echo -e "Run with ${CYAN}--remove${NC} to also delete files"
    fi

    # Clean up status file
    rm -f "/tmp/wt-status-${WT_PROJECT_NAME}-${name}" 2>/dev/null

    echo ""
    success "Worktree '$name' killed!"
}
