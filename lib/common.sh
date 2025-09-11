#!/usr/bin/env bash
#
# Common functions and utilities for DCK scripts
#

# Logging functions
log_info() {
    echo -e "${COLOR_BLUE}ℹ️  $*${COLOR_RESET}"
}

log_success() {
    echo -e "${COLOR_GREEN}✅ $*${COLOR_RESET}"
}

log_warning() {
    echo -e "${COLOR_YELLOW}⚠️  $*${COLOR_RESET}"
}

log_error() {
    echo -e "${COLOR_RED}❌ $*${COLOR_RESET}" >&2
}

# Check if a command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Check if running as root
is_root() {
    [[ $EUID -eq 0 ]]
}

# Get container ID from name
get_container_id() {
    local name="$1"
    docker ps -aq --filter "name=$name" | head -n1
}

# Check if container exists
container_exists() {
    local container="$1"
    docker inspect "$container" &>/dev/null 2>&1
}

# Check if image exists
image_exists() {
    local image="$1"
    docker image inspect "$image" &>/dev/null 2>&1
}

# Check if volume exists
volume_exists() {
    local volume="$1"
    docker volume inspect "$volume" &>/dev/null 2>&1
}

# Check if network exists
network_exists() {
    local network="$1"
    docker network inspect "$network" &>/dev/null 2>&1
}

# Format bytes to human readable
format_bytes() {
    local bytes=$1
    if [[ $bytes -gt 1073741824 ]]; then
        echo "$(( bytes / 1073741824 ))GB"
    elif [[ $bytes -gt 1048576 ]]; then
        echo "$(( bytes / 1048576 ))MB"
    elif [[ $bytes -gt 1024 ]]; then
        echo "$(( bytes / 1024 ))KB"
    else
        echo "${bytes}B"
    fi
}

# Get age of a timestamp
get_age() {
    local timestamp="$1"
    local now=$(date +%s)
    local then=$(date -d "$timestamp" +%s 2>/dev/null || echo 0)
    local diff=$((now - then))
    
    if [[ $diff -lt 60 ]]; then
        echo "${diff}s"
    elif [[ $diff -lt 3600 ]]; then
        echo "$((diff / 60))m"
    elif [[ $diff -lt 86400 ]]; then
        echo "$((diff / 3600))h"
    else
        echo "$((diff / 86400))d"
    fi
}

# Validate Docker object name
validate_name() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]; then
        log_error "Invalid name: $name"
        return 1
    fi
    return 0
}

# Confirm action
confirm_action() {
    local prompt="${1:-Are you sure?}"
    local response
    
    read -p "$prompt (y/N): " response
    [[ "$response" =~ ^[Yy]$ ]]
}

# Export functions
export -f log_info log_success log_warning log_error
export -f command_exists is_root
export -f get_container_id container_exists image_exists volume_exists network_exists
export -f format_bytes get_age validate_name confirm_action