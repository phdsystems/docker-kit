#!/bin/bash

# DockerKit Container Lifecycle Management
# Provides start, stop, restart, remove, kill operations for containers

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'

# Source Docker wrapper for sudo handling
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/docker-wrapper.sh"
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Check Docker command with sudo support
if docker info &>/dev/null 2>&1; then
    DOCKER_CMD="docker"
elif sudo docker info &>/dev/null 2>&1; then
    DOCKER_CMD="sudo docker"
else
    echo -e "${RED}Error: Docker is not accessible${NC}"
    exit 1
fi

# Default values
ACTION=""
CONTAINER=""
FORCE=false
ALL=false
TIME=10
SIGNAL="TERM"
REMOVE_VOLUMES=false

# Show help
show_help() {
    cat << EOF
DockerKit Container Lifecycle Management

USAGE:
    $(basename "$0") <action> [container] [options]

ACTIONS:
    start       Start stopped container(s)
    stop        Stop running container(s)
    restart     Restart container(s)
    remove|rm   Remove container(s)
    kill        Kill running container(s)
    pause       Pause container(s)
    unpause     Unpause container(s)

OPTIONS:
    -a, --all           Apply to all containers
    -f, --force         Force operation
    -t, --time TIME     Seconds to wait before killing (default: 10)
    -s, --signal SIG    Signal to send (default: TERM)
    -v, --volumes       Remove volumes when removing container
    --filter FILTER     Filter containers (e.g., label=app=web)
    -h, --help          Show this help message

EXAMPLES:
    # Start a specific container
    $(basename "$0") start my-container

    # Stop all running containers
    $(basename "$0") stop --all

    # Restart container with custom timeout
    $(basename "$0") restart my-app --time 30

    # Force remove container and its volumes
    $(basename "$0") remove my-container --force --volumes

    # Kill container with specific signal
    $(basename "$0") kill my-app --signal KILL

    # Stop containers matching filter
    $(basename "$0") stop --filter "label=env=dev"

SAFETY NOTES:
    - Use --force carefully as it bypasses safety checks
    - Removing with --volumes permanently deletes volume data
    - Killing containers may cause data corruption
    - Always prefer stop over kill when possible

EOF
}

# Get container list based on filters
get_containers() {
    local filter="$1"
    local state="$2"
    
    if [[ "$ALL" == "true" ]]; then
        if [[ -n "$state" ]]; then
            $DOCKER_CMD ps -a --filter "status=$state" --format "{{.Names}}"
        else
            $DOCKER_CMD ps -a --format "{{.Names}}"
        fi
    elif [[ -n "$filter" ]]; then
        if [[ -n "$state" ]]; then
            $DOCKER_CMD ps -a --filter "$filter" --filter "status=$state" --format "{{.Names}}"
        else
            $DOCKER_CMD ps -a --filter "$filter" --format "{{.Names}}"
        fi
    elif [[ -n "$CONTAINER" ]]; then
        echo "$CONTAINER"
    else
        echo ""
    fi
}

# Confirm dangerous operations
confirm_operation() {
    local message="$1"
    
    if [[ "$FORCE" == "true" ]]; then
        return 0
    fi
    
    echo -e "${YELLOW}$message${NC}"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Operation cancelled${NC}"
        return 1
    fi
    return 0
}

# Start containers
start_containers() {
    local containers
    containers=$(get_containers "" "exited")
    
    if [[ -z "$containers" ]]; then
        echo -e "${YELLOW}No stopped containers to start${NC}"
        return 0
    fi
    
    echo -e "${CYAN}Starting containers...${NC}"
    
    local count=0
    local failed=0
    
    while IFS= read -r container; do
        if [[ -n "$container" ]]; then
            echo -n "Starting $container... "
            if $DOCKER_CMD start "$container" &>/dev/null; then
                echo -e "${GREEN}✓${NC}"
                ((count++))
            else
                echo -e "${RED}✗${NC}"
                ((failed++))
            fi
        fi
    done <<< "$containers"
    
    echo -e "${GREEN}Started $count container(s)${NC}"
    if [[ $failed -gt 0 ]]; then
        echo -e "${RED}Failed to start $failed container(s)${NC}"
    fi
}

# Stop containers
stop_containers() {
    local containers
    containers=$(get_containers "" "running")
    
    if [[ -z "$containers" ]]; then
        echo -e "${YELLOW}No running containers to stop${NC}"
        return 0
    fi
    
    echo -e "${CYAN}Stopping containers (timeout: ${TIME}s)...${NC}"
    
    local count=0
    local failed=0
    
    while IFS= read -r container; do
        if [[ -n "$container" ]]; then
            echo -n "Stopping $container... "
            if $DOCKER_CMD stop -t "$TIME" "$container" &>/dev/null; then
                echo -e "${GREEN}✓${NC}"
                ((count++))
            else
                echo -e "${RED}✗${NC}"
                ((failed++))
            fi
        fi
    done <<< "$containers"
    
    echo -e "${GREEN}Stopped $count container(s)${NC}"
    if [[ $failed -gt 0 ]]; then
        echo -e "${RED}Failed to stop $failed container(s)${NC}"
    fi
}

# Restart containers
restart_containers() {
    local containers
    containers=$(get_containers "" "running")
    
    if [[ -z "$containers" ]]; then
        echo -e "${YELLOW}No running containers to restart${NC}"
        return 0
    fi
    
    echo -e "${CYAN}Restarting containers (timeout: ${TIME}s)...${NC}"
    
    local count=0
    local failed=0
    
    while IFS= read -r container; do
        if [[ -n "$container" ]]; then
            echo -n "Restarting $container... "
            if $DOCKER_CMD restart -t "$TIME" "$container" &>/dev/null; then
                echo -e "${GREEN}✓${NC}"
                ((count++))
            else
                echo -e "${RED}✗${NC}"
                ((failed++))
            fi
        fi
    done <<< "$containers"
    
    echo -e "${GREEN}Restarted $count container(s)${NC}"
    if [[ $failed -gt 0 ]]; then
        echo -e "${RED}Failed to restart $failed container(s)${NC}"
    fi
}

# Remove containers
remove_containers() {
    local containers
    containers=$(get_containers "" "")
    
    if [[ -z "$containers" ]]; then
        echo -e "${YELLOW}No containers to remove${NC}"
        return 0
    fi
    
    # Count containers
    local container_count
    container_count=$(echo "$containers" | wc -l)
    
    # Confirm if removing multiple or with volumes
    if [[ $container_count -gt 1 ]] || [[ "$REMOVE_VOLUMES" == "true" ]]; then
        local msg="This will remove $container_count container(s)"
        if [[ "$REMOVE_VOLUMES" == "true" ]]; then
            msg="$msg and their volumes"
        fi
        
        if ! confirm_operation "$msg"; then
            return 1
        fi
    fi
    
    echo -e "${CYAN}Removing containers...${NC}"
    
    local count=0
    local failed=0
    local rm_args=""
    
    if [[ "$FORCE" == "true" ]]; then
        rm_args="$rm_args -f"
    fi
    
    if [[ "$REMOVE_VOLUMES" == "true" ]]; then
        rm_args="$rm_args -v"
    fi
    
    while IFS= read -r container; do
        if [[ -n "$container" ]]; then
            echo -n "Removing $container... "
            if $DOCKER_CMD rm $rm_args "$container" &>/dev/null; then
                echo -e "${GREEN}✓${NC}"
                ((count++))
            else
                echo -e "${RED}✗${NC}"
                ((failed++))
            fi
        fi
    done <<< "$containers"
    
    echo -e "${GREEN}Removed $count container(s)${NC}"
    if [[ $failed -gt 0 ]]; then
        echo -e "${RED}Failed to remove $failed container(s)${NC}"
        echo -e "${YELLOW}Tip: Use --force to remove running containers${NC}"
    fi
}

# Kill containers
kill_containers() {
    local containers
    containers=$(get_containers "" "running")
    
    if [[ -z "$containers" ]]; then
        echo -e "${YELLOW}No running containers to kill${NC}"
        return 0
    fi
    
    # Count containers
    local container_count
    container_count=$(echo "$containers" | wc -l)
    
    # Warn about killing
    if ! confirm_operation "This will forcefully kill $container_count container(s) with signal $SIGNAL"; then
        return 1
    fi
    
    echo -e "${CYAN}Killing containers with signal $SIGNAL...${NC}"
    
    local count=0
    local failed=0
    
    while IFS= read -r container; do
        if [[ -n "$container" ]]; then
            echo -n "Killing $container... "
            if $DOCKER_CMD kill -s "$SIGNAL" "$container" &>/dev/null; then
                echo -e "${GREEN}✓${NC}"
                ((count++))
            else
                echo -e "${RED}✗${NC}"
                ((failed++))
            fi
        fi
    done <<< "$containers"
    
    echo -e "${GREEN}Killed $count container(s)${NC}"
    if [[ $failed -gt 0 ]]; then
        echo -e "${RED}Failed to kill $failed container(s)${NC}"
    fi
}

# Pause containers
pause_containers() {
    local containers
    containers=$(get_containers "" "running")
    
    if [[ -z "$containers" ]]; then
        echo -e "${YELLOW}No running containers to pause${NC}"
        return 0
    fi
    
    echo -e "${CYAN}Pausing containers...${NC}"
    
    local count=0
    local failed=0
    
    while IFS= read -r container; do
        if [[ -n "$container" ]]; then
            echo -n "Pausing $container... "
            if $DOCKER_CMD pause "$container" &>/dev/null; then
                echo -e "${GREEN}✓${NC}"
                ((count++))
            else
                echo -e "${RED}✗${NC}"
                ((failed++))
            fi
        fi
    done <<< "$containers"
    
    echo -e "${GREEN}Paused $count container(s)${NC}"
    if [[ $failed -gt 0 ]]; then
        echo -e "${RED}Failed to pause $failed container(s)${NC}"
    fi
}

# Unpause containers
unpause_containers() {
    local containers
    containers=$(get_containers "" "paused")
    
    if [[ -z "$containers" ]]; then
        echo -e "${YELLOW}No paused containers to unpause${NC}"
        return 0
    fi
    
    echo -e "${CYAN}Unpausing containers...${NC}"
    
    local count=0
    local failed=0
    
    while IFS= read -r container; do
        if [[ -n "$container" ]]; then
            echo -n "Unpausing $container... "
            if $DOCKER_CMD unpause "$container" &>/dev/null; then
                echo -e "${GREEN}✓${NC}"
                ((count++))
            else
                echo -e "${RED}✗${NC}"
                ((failed++))
            fi
        fi
    done <<< "$containers"
    
    echo -e "${GREEN}Unpaused $count container(s)${NC}"
    if [[ $failed -gt 0 ]]; then
        echo -e "${RED}Failed to unpause $failed container(s)${NC}"
    fi
}

# Parse arguments
FILTER=""

while [[ $# -gt 0 ]]; do
    case $1 in
        start|stop|restart|remove|rm|kill|pause|unpause)
            ACTION="$1"
            if [[ "$ACTION" == "rm" ]]; then
                ACTION="remove"
            fi
            shift
            if [[ $# -gt 0 ]] && [[ ! "$1" =~ ^- ]]; then
                CONTAINER="$1"
                shift
            fi
            ;;
        -a|--all)
            ALL=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -t|--time)
            TIME="$2"
            shift 2
            ;;
        -s|--signal)
            SIGNAL="$2"
            shift 2
            ;;
        -v|--volumes)
            REMOVE_VOLUMES=true
            shift
            ;;
        --filter)
            FILTER="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            if [[ -z "$ACTION" ]]; then
                echo -e "${RED}Error: Unknown action: $1${NC}"
                show_help
                exit 1
            elif [[ -z "$CONTAINER" ]]; then
                CONTAINER="$1"
            fi
            shift
            ;;
    esac
done

# Validate input
if [[ -z "$ACTION" ]]; then
    echo -e "${RED}Error: No action specified${NC}"
    show_help
    exit 1
fi

if [[ -z "$CONTAINER" ]] && [[ "$ALL" != "true" ]] && [[ -z "$FILTER" ]]; then
    echo -e "${RED}Error: No container specified${NC}"
    echo "Use --all for all containers or specify a container name"
    exit 1
fi

# Execute action
case "$ACTION" in
    start)
        start_containers
        ;;
    stop)
        stop_containers
        ;;
    restart)
        restart_containers
        ;;
    remove)
        remove_containers
        ;;
    kill)
        kill_containers
        ;;
    pause)
        pause_containers
        ;;
    unpause)
        unpause_containers
        ;;
    *)
        echo -e "${RED}Error: Unknown action: $ACTION${NC}"
        exit 1
        ;;
esac