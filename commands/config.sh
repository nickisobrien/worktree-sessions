#!/bin/bash
# Configuration management

wt_config() {
    local cmd="${1:-show}"
    shift 2>/dev/null || true

    case "$cmd" in
        show)
            echo -e "${BOLD}wt Configuration${NC}"
            echo ""

            # Global config
            echo -e "${CYAN}Global${NC} ($WT_GLOBAL_CONFIG):"
            if [[ -f "$WT_GLOBAL_CONFIG" ]]; then
                echo -e "${DIM}$(cat "$WT_GLOBAL_CONFIG")${NC}"
            else
                echo -e "${DIM}(no global config)${NC}"
            fi
            echo ""

            # Project config
            if [[ -n "$WT_PROJECT_ROOT" ]]; then
                echo -e "${CYAN}Project${NC} ($WT_PROJECT_ROOT/$WT_PROJECT_CONFIG):"
                if [[ -f "$WT_PROJECT_ROOT/$WT_PROJECT_CONFIG" ]]; then
                    echo -e "${DIM}$(cat "$WT_PROJECT_ROOT/$WT_PROJECT_CONFIG")${NC}"
                else
                    echo -e "${DIM}(no project config - run 'wt init')${NC}"
                fi
                echo ""
            fi

            # Effective values
            echo -e "${CYAN}Effective Values:${NC}"
            echo "  WT_PROJECT_NAME=$WT_PROJECT_NAME"
            echo "  WT_PROJECT_ROOT=$WT_PROJECT_ROOT"
            echo "  WT_WORKTREE_BASE=$WT_WORKTREE_BASE"
            echo "  WT_TMUX_SESSION=$WT_TMUX_SESSION"
            echo "  WT_BRANCH_BASE=$WT_BRANCH_BASE"
            echo "  WT_BRANCH_PREFIX=$WT_BRANCH_PREFIX"
            echo "  WT_PORT_START=$WT_PORT_START"
            echo "  WT_PORT_END=$WT_PORT_END"
            echo "  WT_DEV_COMMAND=$WT_DEV_COMMAND"
            echo "  WT_MAIN_PANE_COMMAND=$WT_MAIN_PANE_COMMAND"
            echo "  WT_PANE_LAYOUT=$WT_PANE_LAYOUT"
            ;;

        prefix)
            # Get or set branch prefix in global config
            local value="$1"

            if [[ -n "$value" ]]; then
                # Set prefix
                mkdir -p "$(dirname "$WT_GLOBAL_CONFIG")"

                if [[ -f "$WT_GLOBAL_CONFIG" ]]; then
                    # Update existing
                    local tmp="$(mktemp)"
                    grep -v "^WT_BRANCH_PREFIX=" "$WT_GLOBAL_CONFIG" > "$tmp" || true
                    echo "WT_BRANCH_PREFIX=\"$value\"" >> "$tmp"
                    mv "$tmp" "$WT_GLOBAL_CONFIG"
                else
                    echo "WT_BRANCH_PREFIX=\"$value\"" > "$WT_GLOBAL_CONFIG"
                fi

                success "Branch prefix set to: $value"
                echo "New branches will be: ${value}<name>"
            else
                # Get prefix
                if [[ -n "$WT_BRANCH_PREFIX" ]]; then
                    echo "$WT_BRANCH_PREFIX"
                else
                    echo "(no prefix set)"
                fi
            fi
            ;;

        edit)
            # Open config in editor
            local config_file="${1:-project}"
            local file_path

            case "$config_file" in
                global)
                    mkdir -p "$(dirname "$WT_GLOBAL_CONFIG")"
                    file_path="$WT_GLOBAL_CONFIG"
                    ;;
                project)
                    require_project
                    file_path="$WT_PROJECT_ROOT/$WT_PROJECT_CONFIG"
                    ;;
                *)
                    error "Unknown config: $config_file (use 'global' or 'project')"
                    return 1
                    ;;
            esac

            ${EDITOR:-vim} "$file_path"
            ;;

        *)
            echo "Usage: wt config <command>"
            echo ""
            echo "Commands:"
            echo "  show              Show all configuration"
            echo "  prefix [value]    Get or set branch prefix"
            echo "  edit [global|project]  Edit config file"
            ;;
    esac
}
