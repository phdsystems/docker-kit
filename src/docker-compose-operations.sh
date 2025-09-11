#!/bin/bash

# DockerKit Docker Compose Operations
# Provides Docker Compose management capabilities

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

# Check Docker and Docker Compose
if docker info &>/dev/null 2>&1; then
    DOCKER_CMD="docker"
elif sudo docker info &>/dev/null 2>&1; then
    DOCKER_CMD="sudo docker"
else
    echo -e "${RED}Error: Docker is not accessible${NC}"
    exit 1
fi

# Check for docker-compose or docker compose
if command -v docker-compose &>/dev/null; then
    COMPOSE_CMD="docker-compose"
elif $DOCKER_CMD compose version &>/dev/null 2>&1; then
    COMPOSE_CMD="$DOCKER_CMD compose"
else
    echo -e "${RED}Error: Docker Compose is not installed${NC}"
    echo "Install with: pip install docker-compose or use Docker Desktop"
    exit 1
fi

# Default values
ACTION=""
PROJECT=""
SERVICE=""
FILE="docker-compose.yml"
ENV_FILE=".env"
DETACH=false
BUILD=false
FORCE_RECREATE=false
NO_DEPS=false
REMOVE_ORPHANS=false
SCALE=""
PROFILE=""
TIMEOUT=10

# Show help
show_help() {
    cat << EOF
DockerKit Docker Compose Operations

USAGE:
    $(basename "$0") <action> [options]

ACTIONS:
    up          Create and start services
    down        Stop and remove services
    start       Start existing services
    stop        Stop running services
    restart     Restart services
    ps          List containers
    logs        View service logs
    exec        Execute command in service
    build       Build or rebuild services
    pull        Pull service images
    push        Push service images
    config      Validate and view configuration
    top         Display running processes
    port        Print public port for a port binding
    version     Show Docker Compose version

UP OPTIONS:
    -d, --detach            Run in background
    --build                 Build images before starting
    --force-recreate        Recreate containers
    --no-deps               Don't start linked services
    --remove-orphans        Remove orphaned containers
    --scale SERVICE=NUM     Scale service instances
    --profile PROFILE       Activate profiles

DOWN OPTIONS:
    -v, --volumes           Remove volumes
    --rmi TYPE              Remove images (all/local)
    -t, --timeout TIMEOUT   Shutdown timeout

COMMON OPTIONS:
    -f, --file FILE         Compose file (default: docker-compose.yml)
    -p, --project NAME      Project name
    --env-file FILE         Environment file (default: .env)
    --profile PROFILE       Specify profile to enable

EXAMPLES:
    # Start all services
    $(basename "$0") up -d

    # Start with build
    $(basename "$0") up -d --build

    # Start specific service
    $(basename "$0") up -d web

    # Scale service
    $(basename "$0") up -d --scale worker=3

    # Stop all services
    $(basename "$0") down

    # Stop and remove volumes
    $(basename "$0") down -v

    # View logs
    $(basename "$0") logs -f

    # View specific service logs
    $(basename "$0") logs -f web

    # Execute command in service
    $(basename "$0") exec web bash

    # Rebuild services
    $(basename "$0") build --no-cache

    # Validate compose file
    $(basename "$0") config

    # Show running containers
    $(basename "$0") ps

EOF
}

# Set compose file and project options
get_compose_args() {
    local args=""
    
    if [[ -n "$FILE" ]] && [[ -f "$FILE" ]]; then
        args="$args -f $FILE"
    fi
    
    if [[ -n "$PROJECT" ]]; then
        args="$args -p $PROJECT"
    fi
    
    if [[ -n "$ENV_FILE" ]] && [[ -f "$ENV_FILE" ]]; then
        args="$args --env-file $ENV_FILE"
    fi
    
    if [[ -n "$PROFILE" ]]; then
        args="$args --profile $PROFILE"
    fi
    
    echo "$args"
}

# Up - Create and start services
compose_up() {
    local compose_args
    compose_args=$(get_compose_args)
    
    local up_args=""
    
    if [[ "$DETACH" == "true" ]]; then
        up_args="$up_args -d"
    fi
    
    if [[ "$BUILD" == "true" ]]; then
        up_args="$up_args --build"
    fi
    
    if [[ "$FORCE_RECREATE" == "true" ]]; then
        up_args="$up_args --force-recreate"
    fi
    
    if [[ "$NO_DEPS" == "true" ]]; then
        up_args="$up_args --no-deps"
    fi
    
    if [[ "$REMOVE_ORPHANS" == "true" ]]; then
        up_args="$up_args --remove-orphans"
    fi
    
    if [[ -n "$SCALE" ]]; then
        up_args="$up_args --scale $SCALE"
    fi
    
    echo -e "${CYAN}Starting Docker Compose services...${NC}"
    
    if [[ -n "$SERVICE" ]]; then
        echo -e "${CYAN}Service: $SERVICE${NC}"
        $COMPOSE_CMD $compose_args up $up_args "$SERVICE"
    else
        $COMPOSE_CMD $compose_args up $up_args
    fi
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Services started successfully${NC}"
        
        if [[ "$DETACH" == "true" ]]; then
            echo -e "\n${CYAN}Running containers:${NC}"
            $COMPOSE_CMD $compose_args ps
        fi
    else
        echo -e "${RED}✗ Failed to start services${NC}"
        exit 1
    fi
}

# Down - Stop and remove services
compose_down() {
    local compose_args
    compose_args=$(get_compose_args)
    
    local down_args=""
    
    if [[ "$VOLUMES" == "true" ]]; then
        down_args="$down_args -v"
    fi
    
    if [[ -n "$RMI" ]]; then
        down_args="$down_args --rmi $RMI"
    fi
    
    if [[ -n "$TIMEOUT" ]]; then
        down_args="$down_args -t $TIMEOUT"
    fi
    
    echo -e "${CYAN}Stopping Docker Compose services...${NC}"
    
    $COMPOSE_CMD $compose_args down $down_args
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Services stopped and removed${NC}"
    else
        echo -e "${RED}✗ Failed to stop services${NC}"
        exit 1
    fi
}

# Start existing services
compose_start() {
    local compose_args
    compose_args=$(get_compose_args)
    
    echo -e "${CYAN}Starting services...${NC}"
    
    if [[ -n "$SERVICE" ]]; then
        $COMPOSE_CMD $compose_args start "$SERVICE"
    else
        $COMPOSE_CMD $compose_args start
    fi
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Services started${NC}"
    else
        echo -e "${RED}✗ Failed to start services${NC}"
        exit 1
    fi
}

# Stop running services
compose_stop() {
    local compose_args
    compose_args=$(get_compose_args)
    
    echo -e "${CYAN}Stopping services...${NC}"
    
    local stop_args=""
    if [[ -n "$TIMEOUT" ]]; then
        stop_args="-t $TIMEOUT"
    fi
    
    if [[ -n "$SERVICE" ]]; then
        $COMPOSE_CMD $compose_args stop $stop_args "$SERVICE"
    else
        $COMPOSE_CMD $compose_args stop $stop_args
    fi
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Services stopped${NC}"
    else
        echo -e "${RED}✗ Failed to stop services${NC}"
        exit 1
    fi
}

# Restart services
compose_restart() {
    local compose_args
    compose_args=$(get_compose_args)
    
    echo -e "${CYAN}Restarting services...${NC}"
    
    local restart_args=""
    if [[ -n "$TIMEOUT" ]]; then
        restart_args="-t $TIMEOUT"
    fi
    
    if [[ -n "$SERVICE" ]]; then
        $COMPOSE_CMD $compose_args restart $restart_args "$SERVICE"
    else
        $COMPOSE_CMD $compose_args restart $restart_args
    fi
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Services restarted${NC}"
    else
        echo -e "${RED}✗ Failed to restart services${NC}"
        exit 1
    fi
}

# List containers
compose_ps() {
    local compose_args
    compose_args=$(get_compose_args)
    
    echo -e "${CYAN}Docker Compose containers:${NC}"
    
    $COMPOSE_CMD $compose_args ps "$@"
}

# View logs
compose_logs() {
    local compose_args
    compose_args=$(get_compose_args)
    
    local log_args=""
    
    if [[ "$FOLLOW" == "true" ]]; then
        log_args="$log_args -f"
    fi
    
    if [[ -n "$TAIL" ]]; then
        log_args="$log_args --tail $TAIL"
    fi
    
    if [[ "$TIMESTAMPS" == "true" ]]; then
        log_args="$log_args -t"
    fi
    
    echo -e "${CYAN}Viewing Docker Compose logs...${NC}"
    
    if [[ -n "$SERVICE" ]]; then
        $COMPOSE_CMD $compose_args logs $log_args "$SERVICE"
    else
        $COMPOSE_CMD $compose_args logs $log_args
    fi
}

# Execute command in service
compose_exec() {
    local compose_args
    compose_args=$(get_compose_args)
    
    if [[ -z "$SERVICE" ]]; then
        echo -e "${RED}Error: Service name required${NC}"
        exit 1
    fi
    
    if [[ -z "$COMMAND" ]]; then
        echo -e "${RED}Error: Command required${NC}"
        exit 1
    fi
    
    local exec_args=""
    
    if [[ "$NO_TTY" == "true" ]]; then
        exec_args="$exec_args -T"
    fi
    
    if [[ -n "$USER" ]]; then
        exec_args="$exec_args -u $USER"
    fi
    
    if [[ -n "$WORKDIR" ]]; then
        exec_args="$exec_args -w $WORKDIR"
    fi
    
    echo -e "${CYAN}Executing in service $SERVICE: $COMMAND${NC}"
    
    $COMPOSE_CMD $compose_args exec $exec_args "$SERVICE" $COMMAND
}

# Build services
compose_build() {
    local compose_args
    compose_args=$(get_compose_args)
    
    local build_args=""
    
    if [[ "$NO_CACHE" == "true" ]]; then
        build_args="$build_args --no-cache"
    fi
    
    if [[ "$PULL" == "true" ]]; then
        build_args="$build_args --pull"
    fi
    
    if [[ "$PARALLEL" == "true" ]]; then
        build_args="$build_args --parallel"
    fi
    
    echo -e "${CYAN}Building Docker Compose services...${NC}"
    
    if [[ -n "$SERVICE" ]]; then
        $COMPOSE_CMD $compose_args build $build_args "$SERVICE"
    else
        $COMPOSE_CMD $compose_args build $build_args
    fi
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Services built successfully${NC}"
    else
        echo -e "${RED}✗ Failed to build services${NC}"
        exit 1
    fi
}

# Pull service images
compose_pull() {
    local compose_args
    compose_args=$(get_compose_args)
    
    echo -e "${CYAN}Pulling Docker Compose images...${NC}"
    
    local pull_args=""
    
    if [[ "$QUIET" == "true" ]]; then
        pull_args="$pull_args -q"
    fi
    
    if [[ -n "$SERVICE" ]]; then
        $COMPOSE_CMD $compose_args pull $pull_args "$SERVICE"
    else
        $COMPOSE_CMD $compose_args pull $pull_args
    fi
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Images pulled successfully${NC}"
    else
        echo -e "${RED}✗ Failed to pull images${NC}"
        exit 1
    fi
}

# Push service images
compose_push() {
    local compose_args
    compose_args=$(get_compose_args)
    
    echo -e "${CYAN}Pushing Docker Compose images...${NC}"
    
    if [[ -n "$SERVICE" ]]; then
        $COMPOSE_CMD $compose_args push "$SERVICE"
    else
        $COMPOSE_CMD $compose_args push
    fi
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Images pushed successfully${NC}"
    else
        echo -e "${RED}✗ Failed to push images${NC}"
        exit 1
    fi
}

# Validate configuration
compose_config() {
    local compose_args
    compose_args=$(get_compose_args)
    
    echo -e "${CYAN}Validating Docker Compose configuration...${NC}"
    
    local config_args=""
    
    if [[ "$QUIET" == "true" ]]; then
        config_args="$config_args -q"
    fi
    
    if [[ "$SERVICES" == "true" ]]; then
        config_args="$config_args --services"
    fi
    
    if [[ "$VOLUMES_FLAG" == "true" ]]; then
        config_args="$config_args --volumes"
    fi
    
    $COMPOSE_CMD $compose_args config $config_args
    
    if [[ $? -eq 0 ]]; then
        if [[ "$QUIET" != "true" ]]; then
            echo -e "${GREEN}✓ Configuration is valid${NC}"
        fi
    else
        echo -e "${RED}✗ Configuration is invalid${NC}"
        exit 1
    fi
}

# Show running processes
compose_top() {
    local compose_args
    compose_args=$(get_compose_args)
    
    echo -e "${CYAN}Docker Compose processes:${NC}"
    
    if [[ -n "$SERVICE" ]]; then
        $COMPOSE_CMD $compose_args top "$SERVICE"
    else
        $COMPOSE_CMD $compose_args top
    fi
}

# Show port mapping
compose_port() {
    local compose_args
    compose_args=$(get_compose_args)
    
    if [[ -z "$SERVICE" ]] || [[ -z "$PORT" ]]; then
        echo -e "${RED}Error: Service and port required${NC}"
        echo "Usage: $(basename "$0") port <service> <port>"
        exit 1
    fi
    
    $COMPOSE_CMD $compose_args port "$SERVICE" "$PORT"
}

# Show version
compose_version() {
    echo -e "${CYAN}Docker Compose version:${NC}"
    $COMPOSE_CMD version
}

# Parse arguments
VOLUMES=false
RMI=""
FOLLOW=false
TAIL=""
TIMESTAMPS=false
NO_CACHE=false
PULL=false
PARALLEL=false
QUIET=false
SERVICES=false
VOLUMES_FLAG=false
NO_TTY=false
USER=""
WORKDIR=""
COMMAND=""
PORT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        up|down|start|stop|restart|ps|logs|exec|build|pull|push|config|top|port|version)
            ACTION="$1"
            shift
            if [[ "$ACTION" == "port" ]] && [[ $# -ge 2 ]]; then
                SERVICE="$1"
                PORT="$2"
                shift 2
            elif [[ "$ACTION" == "exec" ]] && [[ $# -gt 0 ]] && [[ ! "$1" =~ ^- ]]; then
                SERVICE="$1"
                shift
                # Rest are command args
                COMMAND="$*"
                break
            elif [[ $# -gt 0 ]] && [[ ! "$1" =~ ^- ]]; then
                SERVICE="$1"
                shift
            fi
            ;;
        -f|--file)
            FILE="$2"
            shift 2
            ;;
        -p|--project)
            PROJECT="$2"
            shift 2
            ;;
        --env-file)
            ENV_FILE="$2"
            shift 2
            ;;
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        -d|--detach)
            DETACH=true
            shift
            ;;
        --build)
            BUILD=true
            shift
            ;;
        --force-recreate)
            FORCE_RECREATE=true
            shift
            ;;
        --no-deps)
            NO_DEPS=true
            shift
            ;;
        --remove-orphans)
            REMOVE_ORPHANS=true
            shift
            ;;
        --scale)
            SCALE="$2"
            shift 2
            ;;
        -v|--volumes)
            VOLUMES=true
            VOLUMES_FLAG=true
            shift
            ;;
        --rmi)
            RMI="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --follow|-f)
            FOLLOW=true
            shift
            ;;
        --tail)
            TAIL="$2"
            shift 2
            ;;
        --timestamps)
            TIMESTAMPS=true
            shift
            ;;
        --no-cache)
            NO_CACHE=true
            shift
            ;;
        --pull)
            PULL=true
            shift
            ;;
        --parallel)
            PARALLEL=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        --services)
            SERVICES=true
            shift
            ;;
        -T)
            NO_TTY=true
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
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            if [[ -z "$SERVICE" ]]; then
                SERVICE="$1"
            fi
            shift
            ;;
    esac
done

# Execute action
case "$ACTION" in
    up)
        compose_up
        ;;
    down)
        compose_down
        ;;
    start)
        compose_start
        ;;
    stop)
        compose_stop
        ;;
    restart)
        compose_restart
        ;;
    ps)
        compose_ps
        ;;
    logs)
        compose_logs
        ;;
    exec)
        compose_exec
        ;;
    build)
        compose_build
        ;;
    pull)
        compose_pull
        ;;
    push)
        compose_push
        ;;
    config)
        compose_config
        ;;
    top)
        compose_top
        ;;
    port)
        compose_port
        ;;
    version)
        compose_version
        ;;
    *)
        echo -e "${RED}Error: No action specified${NC}"
        show_help
        exit 1
        ;;
esac