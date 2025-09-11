#!/bin/bash

# DockerKit Container Execution and Logs
# Provides exec, logs, attach, cp operations for containers

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
COMMAND=""
INTERACTIVE=false
TTY=false
USER=""
WORKDIR=""
ENV_VARS=()
FOLLOW=false
TAIL="all"
SINCE=""
TIMESTAMPS=false
DETAILS=false

# Show help
show_help() {
    cat << EOF
DockerKit Container Execution and Logs

USAGE:
    $(basename "$0") <action> <container> [options]

ACTIONS:
    exec        Execute command in running container
    logs        View container logs
    attach      Attach to running container
    cp          Copy files to/from container
    top         Display running processes
    diff        Show filesystem changes
    port        Show port mappings
    wait        Wait for container to stop

EXEC OPTIONS:
    -i, --interactive   Keep STDIN open
    -t, --tty          Allocate pseudo-TTY
    -u, --user USER    Username or UID
    -w, --workdir DIR  Working directory
    -e, --env VAR=VAL  Set environment variable
    -d, --detach       Run in background

LOGS OPTIONS:
    -f, --follow       Follow log output
    -n, --tail NUM     Number of lines to show from end
    --since TIME       Show logs since timestamp
    -t, --timestamps   Show timestamps
    --details          Show extra details

CP OPTIONS:
    -a, --archive      Archive mode (preserve attributes)
    -L, --follow-link  Follow symbolic links

EXAMPLES:
    # Execute interactive bash shell
    $(basename "$0") exec my-container -it bash

    # Execute command as specific user
    $(basename "$0") exec my-app -u www-data ls -la /var/www

    # View last 100 lines of logs
    $(basename "$0") logs my-app --tail 100

    # Follow logs with timestamps
    $(basename "$0") logs my-app -f --timestamps

    # Copy file to container
    $(basename "$0") cp ./config.json my-app:/app/config.json

    # Copy from container to host
    $(basename "$0") cp my-app:/var/log/app.log ./app.log

    # Attach to running container
    $(basename "$0") attach my-container

    # Show running processes
    $(basename "$0") top my-container

    # Show port mappings
    $(basename "$0") port my-app

EOF
}

# Validate container exists and is running
validate_container() {
    local require_running="${1:-true}"
    
    if ! $DOCKER_CMD ps -a --format "{{.Names}}" | grep -q "^${CONTAINER}$"; then
        echo -e "${RED}Error: Container '$CONTAINER' not found${NC}"
        exit 1
    fi
    
    if [[ "$require_running" == "true" ]]; then
        if ! $DOCKER_CMD ps --format "{{.Names}}" | grep -q "^${CONTAINER}$"; then
            echo -e "${RED}Error: Container '$CONTAINER' is not running${NC}"
            exit 1
        fi
    fi
}

# Execute command in container
exec_container() {
    validate_container true
    
    local exec_args=""
    
    if [[ "$INTERACTIVE" == "true" ]]; then
        exec_args="$exec_args -i"
    fi
    
    if [[ "$TTY" == "true" ]]; then
        exec_args="$exec_args -t"
    fi
    
    if [[ -n "$USER" ]]; then
        exec_args="$exec_args -u $USER"
    fi
    
    if [[ -n "$WORKDIR" ]]; then
        exec_args="$exec_args -w $WORKDIR"
    fi
    
    for env_var in "${ENV_VARS[@]}"; do
        exec_args="$exec_args -e $env_var"
    done
    
    if [[ -z "$COMMAND" ]]; then
        echo -e "${RED}Error: No command specified${NC}"
        exit 1
    fi
    
    echo -e "${CYAN}Executing in container $CONTAINER: $COMMAND${NC}"
    
    # Execute the command
    $DOCKER_CMD exec $exec_args "$CONTAINER" $COMMAND
}

# View container logs
view_logs() {
    validate_container false
    
    local log_args=""
    
    if [[ "$FOLLOW" == "true" ]]; then
        log_args="$log_args -f"
    fi
    
    if [[ "$TAIL" != "all" ]]; then
        log_args="$log_args --tail $TAIL"
    fi
    
    if [[ -n "$SINCE" ]]; then
        log_args="$log_args --since $SINCE"
    fi
    
    if [[ "$TIMESTAMPS" == "true" ]]; then
        log_args="$log_args -t"
    fi
    
    if [[ "$DETAILS" == "true" ]]; then
        log_args="$log_args --details"
    fi
    
    echo -e "${CYAN}Viewing logs for container: $CONTAINER${NC}"
    
    # View the logs
    $DOCKER_CMD logs $log_args "$CONTAINER"
}

# Attach to container
attach_container() {
    validate_container true
    
    echo -e "${CYAN}Attaching to container: $CONTAINER${NC}"
    echo -e "${YELLOW}Use CTRL-p CTRL-q to detach${NC}"
    
    $DOCKER_CMD attach "$CONTAINER"
}

# Copy files to/from container
copy_files() {
    local source="$1"
    local dest="$2"
    local archive="${3:-false}"
    local follow_link="${4:-false}"
    
    if [[ -z "$source" ]] || [[ -z "$dest" ]]; then
        echo -e "${RED}Error: Source and destination required${NC}"
        echo "Usage: $(basename "$0") cp <source> <destination>"
        exit 1
    fi
    
    local cp_args=""
    
    if [[ "$archive" == "true" ]]; then
        cp_args="$cp_args -a"
    fi
    
    if [[ "$follow_link" == "true" ]]; then
        cp_args="$cp_args -L"
    fi
    
    # Check if source or dest contains container reference
    if [[ "$source" =~ : ]]; then
        # Copying from container
        local container_part="${source%%:*}"
        validate_container false
        echo -e "${CYAN}Copying from container $container_part to $dest${NC}"
    elif [[ "$dest" =~ : ]]; then
        # Copying to container
        local container_part="${dest%%:*}"
        validate_container false
        echo -e "${CYAN}Copying from $source to container $container_part${NC}"
    else
        echo -e "${RED}Error: Either source or destination must reference a container${NC}"
        echo "Format: container:path or path"
        exit 1
    fi
    
    $DOCKER_CMD cp $cp_args "$source" "$dest"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Files copied successfully${NC}"
    else
        echo -e "${RED}✗ Failed to copy files${NC}"
        exit 1
    fi
}

# Show running processes
show_processes() {
    validate_container true
    
    echo -e "${CYAN}Processes in container: $CONTAINER${NC}"
    $DOCKER_CMD top "$CONTAINER"
}

# Show filesystem changes
show_diff() {
    validate_container false
    
    echo -e "${CYAN}Filesystem changes in container: $CONTAINER${NC}"
    
    local changes
    changes=$($DOCKER_CMD diff "$CONTAINER")
    
    if [[ -z "$changes" ]]; then
        echo -e "${GREEN}No filesystem changes${NC}"
    else
        echo "$changes" | while IFS= read -r line; do
            case "${line:0:1}" in
                A)
                    echo -e "${GREEN}$line${NC}"
                    ;;
                D)
                    echo -e "${RED}$line${NC}"
                    ;;
                C)
                    echo -e "${YELLOW}$line${NC}"
                    ;;
                *)
                    echo "$line"
                    ;;
            esac
        done
    fi
}

# Show port mappings
show_ports() {
    validate_container true
    
    echo -e "${CYAN}Port mappings for container: $CONTAINER${NC}"
    
    local ports
    ports=$($DOCKER_CMD port "$CONTAINER")
    
    if [[ -z "$ports" ]]; then
        echo -e "${YELLOW}No port mappings${NC}"
    else
        echo "$ports"
    fi
}

# Wait for container to stop
wait_container() {
    validate_container false
    
    echo -e "${CYAN}Waiting for container to stop: $CONTAINER${NC}"
    
    local exit_code
    exit_code=$($DOCKER_CMD wait "$CONTAINER")
    
    echo -e "${GREEN}Container stopped with exit code: $exit_code${NC}"
    exit "$exit_code"
}

# Export container
export_container() {
    validate_container false
    
    local output_file="${2:-${CONTAINER}.tar}"
    
    echo -e "${CYAN}Exporting container $CONTAINER to $output_file${NC}"
    
    $DOCKER_CMD export "$CONTAINER" > "$output_file"
    
    if [[ $? -eq 0 ]]; then
        local size
        size=$(du -h "$output_file" | cut -f1)
        echo -e "${GREEN}✓ Container exported successfully (${size})${NC}"
    else
        echo -e "${RED}✗ Failed to export container${NC}"
        exit 1
    fi
}

# Parse arguments
shift_count=0

while [[ $# -gt 0 ]]; do
    case $1 in
        exec|logs|attach|cp|top|diff|port|wait|export)
            ACTION="$1"
            shift
            if [[ "$ACTION" != "cp" ]] && [[ $# -gt 0 ]] && [[ ! "$1" =~ ^- ]]; then
                CONTAINER="$1"
                shift
            fi
            ;;
        -i|--interactive)
            INTERACTIVE=true
            shift
            ;;
        -t|--tty)
            TTY=true
            shift
            ;;
        -it|-ti)
            INTERACTIVE=true
            TTY=true
            shift
            ;;
        -u|--user)
            USER="$2"
            shift 2
            ;;
        -w|--workdir)
            WORKDIR="$2"
            shift 2
            ;;
        -e|--env)
            ENV_VARS+=("$2")
            shift 2
            ;;
        -f|--follow)
            FOLLOW=true
            shift
            ;;
        -n|--tail)
            TAIL="$2"
            shift 2
            ;;
        --since)
            SINCE="$2"
            shift 2
            ;;
        --timestamps)
            TIMESTAMPS=true
            shift
            ;;
        --details)
            DETAILS=true
            shift
            ;;
        -a|--archive)
            ARCHIVE=true
            shift
            ;;
        -L|--follow-link)
            FOLLOW_LINK=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            if [[ "$ACTION" == "exec" ]] && [[ -z "$COMMAND" ]]; then
                # Rest of arguments are the command
                COMMAND="$*"
                break
            elif [[ "$ACTION" == "cp" ]]; then
                # Handle cp arguments
                SOURCE="$1"
                DEST="$2"
                shift 2
                break
            else
                echo -e "${RED}Error: Unknown option: $1${NC}"
                show_help
                exit 1
            fi
            ;;
    esac
done

# Validate input
if [[ -z "$ACTION" ]]; then
    echo -e "${RED}Error: No action specified${NC}"
    show_help
    exit 1
fi

# Execute action
case "$ACTION" in
    exec)
        if [[ -z "$CONTAINER" ]]; then
            echo -e "${RED}Error: No container specified${NC}"
            exit 1
        fi
        exec_container
        ;;
    logs)
        if [[ -z "$CONTAINER" ]]; then
            echo -e "${RED}Error: No container specified${NC}"
            exit 1
        fi
        view_logs
        ;;
    attach)
        if [[ -z "$CONTAINER" ]]; then
            echo -e "${RED}Error: No container specified${NC}"
            exit 1
        fi
        attach_container
        ;;
    cp)
        copy_files "$SOURCE" "$DEST" "${ARCHIVE:-false}" "${FOLLOW_LINK:-false}"
        ;;
    top)
        if [[ -z "$CONTAINER" ]]; then
            echo -e "${RED}Error: No container specified${NC}"
            exit 1
        fi
        show_processes
        ;;
    diff)
        if [[ -z "$CONTAINER" ]]; then
            echo -e "${RED}Error: No container specified${NC}"
            exit 1
        fi
        show_diff
        ;;
    port)
        if [[ -z "$CONTAINER" ]]; then
            echo -e "${RED}Error: No container specified${NC}"
            exit 1
        fi
        show_ports
        ;;
    wait)
        if [[ -z "$CONTAINER" ]]; then
            echo -e "${RED}Error: No container specified${NC}"
            exit 1
        fi
        wait_container
        ;;
    export)
        if [[ -z "$CONTAINER" ]]; then
            echo -e "${RED}Error: No container specified${NC}"
            exit 1
        fi
        export_container "$CONTAINER" "$2"
        ;;
    *)
        echo -e "${RED}Error: Unknown action: $ACTION${NC}"
        exit 1
        ;;
esac