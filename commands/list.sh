#!/bin/bash
# List worktrees with status

source "$WT_ROOT/lib/ports.sh"
source "$WT_ROOT/lib/tmux.sh"

# Get branch for worktree
get_branch() {
    local path="$1"
    git -C "$path" branch --show-current 2>/dev/null
}

# Check if dev server is running
check_dev_running() {
    local port="$1"
    [[ -n "$port" ]] && is_port_in_use "$port"
}

# Check if main process is running in tmux
check_main_running() {
    local name="$1"

    if ! session_exists || ! window_exists "$name"; then
        return 1
    fi

    local pane_cmd="$(get_pane_process "$name" 0)"
    [[ -n "$pane_cmd" && "$pane_cmd" != "bash" && "$pane_cmd" != "zsh" ]]
}

# Get status indicator
get_status_indicator() {
    local name="$1"
    local port="$2"

    # Check for custom status file (written by hooks)
    local status_file="/tmp/wt-status-${WT_PROJECT_NAME}-${name}"
    if [[ -f "$status_file" ]]; then
        local status="$(cat "$status_file" 2>/dev/null | tr -d '[:space:]')"
        case "$status" in
            processing|active) echo "processing"; return ;;
        esac
    fi

    # Fall back to process check
    if check_main_running "$name"; then
        echo "idle"
    else
        echo "off"
    fi
}

wt_list() {
    require_project

    local format="${1:-pretty}"

    case "$format" in
        --simple|-s)
            list_worktree_names
            ;;
        --json|-j)
            echo "["
            local first=true
            for name in $(list_worktree_names); do
                local path="$(get_worktree_path "$name")"
                local port="$(get_port "$name")"
                local branch="$(get_branch "$path")"

                [[ "$first" == true ]] && first=false || echo ","
                printf '  {"name": "%s", "port": %s, "branch": "%s", "path": "%s"}' \
                    "$name" "${port:-null}" "$branch" "$path"
            done
            echo ""
            echo "]"
            ;;
        *)
            # Pretty format
            echo -e "${BOLD}${CYAN}WORKTREES${NC} ${DIM}($WT_PROJECT_NAME)${NC}"
            echo -e "${CYAN}─────────────────────────────────────────────${NC}"
            echo ""

            local found=0
            local index=1

            for name in $(list_worktree_names); do
                found=1
                local path="$(get_worktree_path "$name")"
                local port="$(get_port "$name")"
                local branch="$(get_branch "$path")"

                # Status indicators
                local main_status="$(get_status_indicator "$name" "$port")"
                local main_icon
                case "$main_status" in
                    processing) main_icon="${YELLOW}⚡${NC}" ;;
                    idle)       main_icon="${GREEN}✓${NC}" ;;
                    off)        main_icon="${RED}✗${NC}" ;;
                esac

                local dev_icon="${RED}✗${NC}"
                if check_dev_running "$port"; then
                    dev_icon="${GREEN}✓${NC}"
                fi

                local port_str=":${port:-????}"
                echo -e " ${BOLD}[$index]${NC} $(printf '%-18s' "$name") ${YELLOW}${port_str}${NC}  main $main_icon  dev $dev_icon"

                index=$((index + 1))
            done

            if [[ $found -eq 0 ]]; then
                echo -e " ${YELLOW}No worktrees created yet${NC}"
                echo ""
                echo -e " Run ${CYAN}wt new <name>${NC} to create one"
            fi

            echo ""
            ;;
    esac
}
