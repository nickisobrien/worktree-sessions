#!/bin/bash
# Kill all worktrees

source "$WT_ROOT/lib/ports.sh"
source "$WT_ROOT/lib/tmux.sh"

wt_kill_all() {
    require_project

    local remove_files=false
    local force=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --remove|-r)
                remove_files=true
                shift
                ;;
            --force|-f)
                force=true
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    # Get worktrees
    local worktrees=($(list_worktree_names))
    local count=${#worktrees[@]}

    if [[ $count -eq 0 ]]; then
        warn "No worktrees to kill"
        return 0
    fi

    echo -e "${BOLD}${RED}Kill All Worktrees${NC}"
    echo ""
    echo -e "This will kill ${BOLD}$count${NC} worktree(s):"
    for name in "${worktrees[@]}"; do
        echo "  - $name"
    done
    echo ""

    # Confirm unless forced
    if [[ "$force" == false ]]; then
        read -p "Kill all tmux windows? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "Aborted"
            return 0
        fi

        read -p "Also remove git worktree files? (y/N): " remove_confirm
        if [[ "$remove_confirm" =~ ^[Yy]$ ]]; then
            remove_files=true
        fi
    fi

    echo ""

    # Kill each worktree
    for name in "${worktrees[@]}"; do
        info "Killing $name..."
        if [[ "$remove_files" == true ]]; then
            source "$WT_ROOT/commands/kill.sh"
            wt_kill "$name" --remove --force
        else
            source "$WT_ROOT/commands/kill.sh"
            wt_kill "$name" --force
        fi
    done

    echo ""
    success "All worktrees killed"
}
