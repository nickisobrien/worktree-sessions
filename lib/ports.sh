#!/bin/bash
# Port allocation management

# Get ports file for current project
get_ports_file() {
    get_state_file "ports"
}

# Get allocated port for a worktree
get_port() {
    local name="$1"
    local ports_file="$(get_ports_file)"
    grep "^${name}:" "$ports_file" 2>/dev/null | cut -d: -f2
}

# Check if port is in use on system
is_port_in_use() {
    local port="$1"
    lsof -i ":$port" >/dev/null 2>&1
}

# Find next available port
find_next_port() {
    local ports_file="$(get_ports_file)"
    local port=$WT_PORT_START

    while [[ $port -le $WT_PORT_END ]]; do
        # Check allocation file
        if grep -q ":${port}$" "$ports_file" 2>/dev/null; then
            port=$((port + 1))
            continue
        fi
        # Check system usage
        if is_port_in_use "$port"; then
            port=$((port + 1))
            continue
        fi
        echo "$port"
        return 0
    done

    error "No available ports in range $WT_PORT_START-$WT_PORT_END"
    return 1
}

# Allocate port for worktree
allocate_port() {
    local name="$1"
    local ports_file="$(get_ports_file)"

    # Return existing allocation
    local existing="$(get_port "$name")"
    if [[ -n "$existing" ]]; then
        echo "$existing"
        return 0
    fi

    # Allocate new port
    local port="$(find_next_port)"
    if [[ -n "$port" ]]; then
        echo "${name}:${port}" >> "$ports_file"
        echo "$port"
        return 0
    fi
    return 1
}

# Release port allocation
release_port() {
    local name="$1"
    local ports_file="$(get_ports_file)"

    if [[ -f "$ports_file" ]]; then
        local tmp="$(mktemp)"
        grep -v "^${name}:" "$ports_file" > "$tmp" || true
        mv "$tmp" "$ports_file"
    fi
}

# List all allocations
list_ports() {
    local ports_file="$(get_ports_file)"
    [[ -f "$ports_file" ]] && cat "$ports_file"
}

# Cleanup stale allocations
cleanup_ports() {
    local ports_file="$(get_ports_file)"
    [[ ! -f "$ports_file" ]] && return 0

    local tmp="$(mktemp)"
    while IFS=: read -r name port; do
        if worktree_exists "$name"; then
            echo "${name}:${port}" >> "$tmp"
        fi
    done < "$ports_file"
    mv "$tmp" "$ports_file"
}

# Command handler for 'wt ports'
wt_ports_cmd() {
    require_project

    case "${1:-list}" in
        get)      get_port "$2" ;;
        allocate) allocate_port "$2" ;;
        release)  release_port "$2" ;;
        list)     list_ports ;;
        cleanup)  cleanup_ports; success "Cleaned up stale port allocations" ;;
        next)     find_next_port ;;
        *)
            echo "Usage: wt ports {get|allocate|release|list|cleanup|next} [name]"
            ;;
    esac
}
