#!/bin/bash
# Tmux session and window management

# Check if we're inside tmux
in_tmux() {
    [[ -n "$TMUX" ]]
}

# Check if session exists
session_exists() {
    tmux has-session -t "$WT_TMUX_SESSION" 2>/dev/null
}

# Check if window exists
window_exists() {
    local name="$1"
    tmux list-windows -t "$WT_TMUX_SESSION" -F '#{window_name}' 2>/dev/null | grep -qx "$name"
}

# Ensure session exists with control window
ensure_session() {
    if ! session_exists; then
        tmux new-session -d -s "$WT_TMUX_SESSION" -n "control" -c "$WT_PROJECT_ROOT"
        tmux send-keys -t "$WT_TMUX_SESSION:control" "$WT_ROOT/wt control --loop" Enter
    elif ! window_exists "control"; then
        tmux new-window -t "$WT_TMUX_SESSION" -n "control" -c "$WT_PROJECT_ROOT"
        tmux send-keys -t "$WT_TMUX_SESSION:control" "$WT_ROOT/wt control --loop" Enter
    fi
}

# Create worktree window with configured layout
create_worktree_window() {
    local name="$1"
    local worktree_path="$2"
    local port="$3"

    if ! session_exists; then
        warn "tmux session '$WT_TMUX_SESSION' not running"
        return 1
    fi

    # Create window - starts with single pane
    tmux new-window -t "$WT_TMUX_SESSION" -n "$name" -c "$worktree_path"
    sleep 0.2

    # Get commands to run
    local main_cmd="${WT_MAIN_PANE_COMMAND:-}"
    local dev_cmd="${WT_DEV_COMMAND:-}"

    # Substitute $PORT in commands
    dev_cmd="${dev_cmd//\$PORT/$port}"
    dev_cmd="${dev_cmd//\${PORT}/$port}"

    case "$WT_PANE_LAYOUT" in
        main-left)
            # Main command on left (larger), dev + shell on right
            if [[ -n "$main_cmd" ]]; then
                tmux send-keys "$main_cmd" Enter
            fi

            if [[ -n "$dev_cmd" ]]; then
                tmux split-window -h -c "$worktree_path"
                sleep 0.2
                tmux send-keys "$dev_cmd" Enter

                # Add shell pane below dev
                tmux split-window -v -c "$worktree_path"

                # Go back to main pane
                tmux select-pane -L
            fi
            ;;
        main-right)
            # Dev + shell on left, main on right
            if [[ -n "$dev_cmd" ]]; then
                tmux send-keys "$dev_cmd" Enter
                tmux split-window -v -c "$worktree_path"
            fi

            if [[ -n "$main_cmd" ]]; then
                tmux split-window -h -c "$worktree_path"
                sleep 0.2
                tmux send-keys "$main_cmd" Enter
            fi
            ;;
        even-horizontal)
            # All panes side by side
            if [[ -n "$main_cmd" ]]; then
                tmux send-keys "$main_cmd" Enter
            fi
            if [[ -n "$dev_cmd" ]]; then
                tmux split-window -h -c "$worktree_path"
                tmux send-keys "$dev_cmd" Enter
            fi
            tmux split-window -h -c "$worktree_path"
            tmux select-layout even-horizontal
            tmux select-pane -t 0
            ;;
        even-vertical)
            # All panes stacked
            if [[ -n "$main_cmd" ]]; then
                tmux send-keys "$main_cmd" Enter
            fi
            if [[ -n "$dev_cmd" ]]; then
                tmux split-window -v -c "$worktree_path"
                tmux send-keys "$dev_cmd" Enter
            fi
            tmux split-window -v -c "$worktree_path"
            tmux select-layout even-vertical
            tmux select-pane -t 0
            ;;
        single)
            # Just one pane
            if [[ -n "$main_cmd" ]]; then
                tmux send-keys "$main_cmd" Enter
            fi
            ;;
        *)
            # Custom layout - just create window, let hook handle it
            ;;
    esac

    return 0
}

# Kill worktree window
kill_worktree_window() {
    local name="$1"

    if session_exists && window_exists "$name"; then
        tmux kill-window -t "$WT_TMUX_SESSION:$name" 2>/dev/null
        return 0
    fi
    return 1
}

# Switch to worktree window
switch_to_window() {
    local name="$1"

    if in_tmux; then
        tmux switch-client -t "$WT_TMUX_SESSION:$name" 2>/dev/null || \
            tmux select-window -t "$WT_TMUX_SESSION:$name" 2>/dev/null
    else
        tmux attach -t "$WT_TMUX_SESSION:$name"
    fi
}

# Attach to or switch to session
attach_session() {
    local window="${1:-control}"

    if in_tmux; then
        tmux switch-client -t "$WT_TMUX_SESSION:$window" 2>/dev/null || \
            tmux select-window -t "$WT_TMUX_SESSION:$window" 2>/dev/null
    else
        tmux attach -t "$WT_TMUX_SESSION"
    fi
}

# Get process status in pane
get_pane_process() {
    local window="$1"
    local pane="${2:-0}"

    tmux list-panes -t "$WT_TMUX_SESSION:$window" -F '#{pane_index}:#{pane_pid}:#{pane_current_command}' 2>/dev/null | \
        grep "^${pane}:" | cut -d: -f3
}
