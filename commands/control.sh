#!/bin/bash
# Interactive control center

source "$WT_ROOT/lib/ports.sh"
source "$WT_ROOT/lib/tmux.sh"

# Check for gum
check_gum() {
    if ! command -v gum &>/dev/null; then
        echo "The control center requires gum for interactive UI."
        echo ""
        echo "Install with: brew install gum"
        echo ""
        echo "Or use commands directly:"
        echo "  wt new <name>"
        echo "  wt list"
        echo "  wt kill <name>"
        return 1
    fi
    return 0
}

# Get status for a worktree (for menu display)
get_worktree_status() {
    local name="$1"
    local port="$(get_port "$name")"
    local port_str=":${port:-????}"

    # Status indicators
    source "$WT_ROOT/commands/list.sh"
    local main_status="$(get_status_indicator "$name" "$port")"
    local main_icon
    case "$main_status" in
        processing) main_icon="⚡" ;;
        idle)       main_icon="✓" ;;
        off)        main_icon="✗" ;;
    esac

    local dev_icon="✗"
    if check_dev_running "$port"; then
        dev_icon="✓"
    fi

    printf "%-20s %s  main:%s  dev:%s" "$name" "$port_str" "$main_icon" "$dev_icon"
}

# Build menu options
build_menu() {
    local options=()

    # Add worktrees
    for name in $(list_worktree_names); do
        options+=("$(get_worktree_status "$name")")
    done

    # Add actions
    options+=("───────────────────────────────────────")
    options+=("➕ New worktree")
    options+=("💀 Kill all worktrees")
    options+=("❌ Quit")

    printf '%s\n' "${options[@]}"
}

# Main control loop
control_loop() {
    while true; do
        clear

        gum style \
            --border double \
            --border-foreground 212 \
            --padding "0 2" \
            --margin "1 0" \
            --bold \
            --foreground 87 \
            "WORKTREE CONTROL CENTER"

        gum style --foreground 245 "Project: $WT_PROJECT_NAME"
        echo ""
        gum style --foreground 240 --italic "Return here: Ctrl-b w → 'control', or 'wt'"
        echo ""

        # Get selection
        local selection
        selection=$(build_menu | gum choose --cursor.foreground 212 --selected.foreground 212)

        # Handle selection
        case "$selection" in
            "───────────────────────────────────────")
                continue
                ;;
            "➕ New worktree")
                echo ""

                # Check branch prefix
                if [[ -z "$WT_BRANCH_PREFIX" ]]; then
                    gum style --foreground 212 --bold "Set your branch prefix:"
                    gum style --foreground 245 "This is saved globally (e.g., 'nick/' creates 'nick/my-feature')"
                    echo ""
                    local prefix=$(gum input --placeholder "nick/" --prompt "Branch prefix: " --prompt.foreground 212)
                    if [[ -n "$prefix" ]]; then
                        source "$WT_ROOT/commands/config.sh"
                        wt_config prefix "$prefix"
                        WT_BRANCH_PREFIX="$prefix"
                    fi
                    echo ""
                fi

                gum style --foreground 212 --bold "Create New Worktree"
                echo ""

                local branch_choice=$(gum choose --cursor.foreground 212 \
                    "New branch (${WT_BRANCH_PREFIX}<name>)" \
                    "Existing branch")

                [[ -z "$branch_choice" ]] && continue

                local name=""
                local branch_arg=""

                if [[ "$branch_choice" == "Existing"* ]]; then
                    local branch=$(gum input --placeholder "user/feature-branch" --prompt "Branch name: " --prompt.foreground 212)
                    [[ -z "$branch" ]] && continue

                    local default_name=$(echo "$branch" | sed 's|.*/||')
                    name=$(gum input --placeholder "$default_name" --prompt "Worktree name: " --prompt.foreground 212 --value "$default_name")
                    [[ -z "$name" ]] && continue
                    branch_arg="--branch $branch --existing"
                else
                    name=$(gum input --placeholder "my-feature" --prompt "Worktree name: " --prompt.foreground 212)
                    [[ -z "$name" ]] && continue
                fi

                if [[ -n "$name" ]]; then
                    source "$WT_ROOT/commands/new.sh"
                    eval wt_new "$name" $branch_arg
                    echo ""
                    gum style --foreground 245 "Press Enter to continue..."
                    read -r
                fi
                ;;
            "💀 Kill all worktrees")
                echo ""
                if gum confirm "Kill ALL worktrees?" --prompt.foreground 196; then
                    local remove_files=false
                    if gum confirm "Also remove git worktree files?" --prompt.foreground 212; then
                        remove_files=true
                    fi
                    echo ""
                    source "$WT_ROOT/commands/kill-all.sh"
                    if [[ "$remove_files" == true ]]; then
                        wt_kill_all --remove --force
                    else
                        wt_kill_all --force
                    fi
                    echo ""
                    gum style --foreground 245 "Press Enter to continue..."
                    read -r
                fi
                ;;
            "❌ Quit")
                clear
                gum style --foreground 87 "Exiting control center. tmux session remains active."
                echo "Re-attach with: tmux attach -t $WT_TMUX_SESSION"
                exit 0
                ;;
            "")
                continue
                ;;
            *)
                # Extract worktree name
                local wt_name=$(echo "$selection" | awk '{print $1}')
                if [[ -n "$wt_name" && ! "$wt_name" =~ ^[➕💀❌─] ]]; then
                    echo ""
                    local action=$(gum choose --cursor.foreground 212 \
                        "Switch to $wt_name" \
                        "Delete $wt_name" \
                        "Back")

                    case "$action" in
                        "Switch to"*)
                            switch_to_window "$wt_name"
                            ;;
                        "Delete"*)
                            echo ""
                            if gum confirm "Delete worktree '$wt_name'?" --prompt.foreground 196; then
                                local remove_files=false
                                if gum confirm "Also remove git worktree files?" --prompt.foreground 212; then
                                    remove_files=true
                                fi
                                echo ""
                                source "$WT_ROOT/commands/kill.sh"
                                if [[ "$remove_files" == true ]]; then
                                    wt_kill "$wt_name" --remove --force
                                else
                                    wt_kill "$wt_name" --force
                                fi
                                echo ""
                                gum style --foreground 245 "Press Enter to continue..."
                                read -r
                            fi
                            ;;
                    esac
                fi
                ;;
        esac
    done
}

wt_control() {
    require_project

    case "${1:-}" in
        --loop)
            check_gum || exit 1
            control_loop
            ;;
        *)
            ensure_session
            attach_session "control"
            ;;
    esac
}
