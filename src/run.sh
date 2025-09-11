#!/bin/bash

# DockerKit Run Script
# Runs DockerKit in various modes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'

# Source Docker wrapper for sudo handling
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/docker-wrapper.sh"
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERKIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        DockerKit Run Script            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Default values
MODE="interactive"
PROFILE=""
DETACH=false
REMOVE=true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --mode)
            MODE="$2"
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
        --no-rm)
            REMOVE=false
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --mode MODE       Run mode (interactive, daemon, compose)"
            echo "  --profile PROFILE Docker-compose profile (api, ui, all)"
            echo "  -d, --detach      Run in background"
            echo "  --no-rm           Don't remove container after exit"
            echo "  --help            Show this help message"
            echo ""
            echo "Modes:"
            echo "  interactive  Run interactively with shell (default)"
            echo "  daemon       Run as daemon service"
            echo "  compose      Run with docker-compose"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Check Docker command
check_docker() {
    if ! command -v docker &>/dev/null; then
        echo -e "${RED}Error: Docker is not installed${NC}"
        exit 1
    fi
    
    if ! docker info &>/dev/null 2>&1; then
        if ! sudo docker info &>/dev/null 2>&1; then
            echo -e "${RED}Error: Docker daemon is not running${NC}"
            exit 1
        else
            DOCKER_CMD="sudo docker"
            COMPOSE_CMD="sudo docker-compose"
        fi
    else
        DOCKER_CMD="docker"
        COMPOSE_CMD="docker-compose"
    fi
}

# Run interactive mode
run_interactive() {
    echo -e "${YELLOW}Starting DockerKit in interactive mode...${NC}"
    
    RUN_ARGS=""
    
    if [[ "$REMOVE" == "true" ]]; then
        RUN_ARGS="$RUN_ARGS --rm"
    fi
    
    $DOCKER_CMD run -it $RUN_ARGS \
        --name dockerkit-session-$$ \
        -v /var/run/docker.sock:/var/run/docker.sock \
        --privileged \
        -e DOCKERKIT_MODE=interactive \
        dockerkit:latest \
        /bin/bash
}

# Run daemon mode
run_daemon() {
    echo -e "${YELLOW}Starting DockerKit as daemon...${NC}"
    
    # Check if already running
    if $DOCKER_CMD ps -q -f name=dockerkit &>/dev/null; then
        echo -e "${YELLOW}DockerKit is already running${NC}"
        echo "To attach: docker_run exec -it dockerkit bash"
        exit 0
    fi
    
    $DOCKER_CMD run -d \
        --name dockerkit \
        --restart unless-stopped \
        -v /var/run/docker.sock:/var/run/docker.sock \
        --privileged \
        -e DOCKERKIT_MODE=daemon \
        dockerkit:latest \
        tail -f /dev/null
    
    echo -e "${GREEN}✓ DockerKit daemon started${NC}"
    echo "To attach: docker_run exec -it dockerkit bash"
    echo "To stop: docker_run stop dockerkit"
}

# Run with docker-compose
run_compose() {
    echo -e "${YELLOW}Starting DockerKit with docker-compose...${NC}"
    
    cd "$DOCKERKIT_DIR"
    
    # Check if .env exists
    if [[ ! -f .env ]] && [[ -f .env.example ]]; then
        echo -e "${YELLOW}Creating .env from .env.example...${NC}"
        cp .env.example .env
    fi
    
    COMPOSE_ARGS=""
    
    if [[ -n "$PROFILE" ]]; then
        COMPOSE_ARGS="--profile $PROFILE"
    fi
    
    if [[ "$DETACH" == "true" ]]; then
        $COMPOSE_CMD $COMPOSE_ARGS up -d
        echo -e "${GREEN}✓ DockerKit started in background${NC}"
        echo "To view logs: docker-compose logs -f"
        echo "To attach: docker_run exec -it dockerkit bash"
    else
        $COMPOSE_CMD $COMPOSE_ARGS up
    fi
}

# Stop DockerKit
stop_dockerkit() {
    echo -e "${YELLOW}Stopping DockerKit containers only...${NC}"
    
    # IMPORTANT: Only stop/remove containers with exact name match
    # Never touch other containers on the system
    if $DOCKER_CMD ps -q -f name=^dockerkit$ &>/dev/null; then
        $DOCKER_CMD stop dockerkit
        $DOCKER_CMD rm dockerkit 2>/dev/null || true
        echo -e "${GREEN}✓ DockerKit container stopped${NC}"
    else
        echo -e "${YELLOW}DockerKit container is not running${NC}"
    fi
    
    # Also check for session containers
    for container in $($DOCKER_CMD ps -aq -f name=^dockerkit-session); do
        echo -e "${YELLOW}Stopping session container: $(basename $container)${NC}"
        $DOCKER_CMD stop "$container" 2>/dev/null || true
        $DOCKER_CMD rm "$container" 2>/dev/null || true
    done
    
    echo -e "${YELLOW}Note: Only DockerKit-specific containers were affected${NC}"
}

# Check image exists
check_image() {
    if ! $DOCKER_CMD images -q dockerkit:latest &>/dev/null; then
        echo -e "${YELLOW}DockerKit image not found. Building...${NC}"
        "$SCRIPT_DIR/build.sh"
    fi
}

# Main execution
main() {
    check_docker
    
    case "$MODE" in
        interactive)
            check_image
            run_interactive
            ;;
        daemon)
            check_image
            run_daemon
            ;;
        compose)
            run_compose
            ;;
        stop)
            stop_dockerkit
            ;;
        *)
            echo -e "${RED}Unknown mode: $MODE${NC}"
            echo "Valid modes: interactive, daemon, compose, stop"
            exit 1
            ;;
    esac
}

# Run main
main