#!/bin/bash

# DockerKit Development Script
# Provides development utilities and helpers

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'

# Source Docker wrapper for sudo handling
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/docker-wrapper.sh"
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERKIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    DockerKit Development Utilities     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Default action
ACTION="${1:-help}"

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

# Development build
dev_build() {
    echo -e "${YELLOW}Building DockerKit in development mode...${NC}"
    
    cd "$DOCKERKIT_DIR"
    
    # Build with cache mounting for faster rebuilds
    $DOCKER_CMD build \
        --cache-from dockerkit:dev \
        --build-arg BUILDKIT_INLINE_CACHE=1 \
        -t dockerkit:dev \
        -f Dockerfile \
        .
    
    echo -e "${GREEN}✓ Development build complete${NC}"
}

# Run development container
dev_run() {
    echo -e "${YELLOW}Starting development container...${NC}"
    
    cd "$DOCKERKIT_DIR"
    
    # Run with volume mounts for live code updates
    $DOCKER_CMD run -it --rm \
        --name dockerkit-dev \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v "$DOCKERKIT_DIR:/opt/dockerkit:rw" \
        -v "$DOCKERKIT_DIR/scripts:/opt/dockerkit/scripts:rw" \
        --privileged \
        -e DOCKERKIT_DEV_MODE=true \
        -e DOCKERKIT_DEBUG=true \
        dockerkit:dev \
        /bin/bash
}

# Run tests in container
dev_test() {
    echo -e "${YELLOW}Running tests in container...${NC}"
    
    cd "$DOCKERKIT_DIR"
    
    $DOCKER_CMD run --rm \
        --name dockerkit-test \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v "$DOCKERKIT_DIR:/opt/dockerkit:ro" \
        --privileged \
        dockerkit:dev \
        /opt/dockerkit/tests/run_tests.sh "$@"
}

# Shell into running container
dev_shell() {
    echo -e "${YELLOW}Connecting to development container...${NC}"
    
    if $DOCKER_CMD ps -q -f name=dockerkit-dev &>/dev/null; then
        $DOCKER_CMD exec -it dockerkit-dev /bin/bash
    else
        echo -e "${RED}No development container running${NC}"
        echo "Start one with: $0 run"
        exit 1
    fi
}

# Watch logs
dev_logs() {
    echo -e "${YELLOW}Watching DockerKit logs...${NC}"
    
    if [[ -n "$2" ]]; then
        $COMPOSE_CMD logs -f "$2"
    else
        $COMPOSE_CMD logs -f
    fi
}

# Clean development environment
dev_clean() {
    echo -e "${YELLOW}Cleaning DockerKit development environment only...${NC}"
    echo -e "${YELLOW}Note: Only DockerKit-specific resources will be removed${NC}"
    
    # IMPORTANT: Only stop/remove DockerKit-specific containers
    # Never touch other containers on the system
    
    # Stop containers (exact name match only)
    if $DOCKER_CMD ps -q -f name=^dockerkit-dev$ &>/dev/null; then
        $DOCKER_CMD stop dockerkit-dev 2>/dev/null || true
        $DOCKER_CMD rm dockerkit-dev 2>/dev/null || true
        echo "✓ Removed dockerkit-dev container"
    fi
    
    if $DOCKER_CMD ps -q -f name=^dockerkit-test$ &>/dev/null; then
        $DOCKER_CMD stop dockerkit-test 2>/dev/null || true
        $DOCKER_CMD rm dockerkit-test 2>/dev/null || true
        echo "✓ Removed dockerkit-test container"
    fi
    
    # Remove only DockerKit development images
    if $DOCKER_CMD images -q dockerkit:dev &>/dev/null; then
        $DOCKER_CMD rmi dockerkit:dev 2>/dev/null || true
        echo "✓ Removed dockerkit:dev image"
    fi
    
    echo -e "${GREEN}✓ DockerKit development environment cleaned${NC}"
    echo -e "${GREEN}✓ Other Docker resources were NOT affected${NC}"
}

# Lint scripts
dev_lint() {
    echo -e "${YELLOW}Linting scripts...${NC}"
    
    if command -v shellcheck &>/dev/null; then
        find "$DOCKERKIT_DIR/scripts" -name "*.sh" -exec shellcheck {} \;
        find "$DOCKERKIT_DIR/tests" -name "*.sh" -exec shellcheck {} \;
        echo -e "${GREEN}✓ Linting complete${NC}"
    else
        echo -e "${YELLOW}Installing shellcheck...${NC}"
        if command -v apt-get &>/dev/null; then
            sudo apt-get update && sudo apt-get install -y shellcheck
        elif command -v brew &>/dev/null; then
            brew install shellcheck
        else
            echo -e "${RED}Please install shellcheck manually${NC}"
            exit 1
        fi
    fi
}

# Format scripts
dev_format() {
    echo -e "${YELLOW}Formatting scripts...${NC}"
    
    if command -v shfmt &>/dev/null; then
        shfmt -w -i 4 "$DOCKERKIT_DIR/scripts"/*.sh
        shfmt -w -i 4 "$DOCKERKIT_DIR/tests"/*.sh
        echo -e "${GREEN}✓ Formatting complete${NC}"
    else
        echo -e "${YELLOW}shfmt not found. Install with:${NC}"
        echo "  GO111MODULE=on go get mvdan.cc/sh/v3/cmd/shfmt"
    fi
}

# Generate documentation
dev_docs() {
    echo -e "${YELLOW}Generating documentation...${NC}"
    
    cd "$DOCKERKIT_DIR"
    
    # Extract help from scripts
    mkdir -p docs/generated
    
    for script in scripts/docker-search-*.sh; do
        if [[ -f "$script" ]]; then
            name=$(basename "$script" .sh)
            echo "# $name" > "docs/generated/$name.md"
            echo "" >> "docs/generated/$name.md"
            "$script" --help >> "docs/generated/$name.md" 2>/dev/null || true
        fi
    done
    
    echo -e "${GREEN}✓ Documentation generated in docs/generated/${NC}"
}

# Development status
dev_status() {
    echo -e "${YELLOW}Development Status:${NC}"
    echo ""
    
    # Check running containers
    echo "Running containers:"
    $DOCKER_CMD ps --filter "name=dockerkit" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    
    # Check images
    echo "Docker images:"
    $DOCKER_CMD images --filter "reference=dockerkit*" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
    echo ""
    
    # Check volumes
    echo "Docker volumes:"
    $DOCKER_CMD volume ls --filter "name=dockerkit" --format "table {{.Name}}\t{{.Driver}}"
}

# Show help
show_help() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  build      Build development Docker image"
    echo "  run        Run development container with live mounts"
    echo "  test       Run tests in container"
    echo "  shell      Shell into running development container"
    echo "  logs       Watch container logs"
    echo "  clean      Clean development environment"
    echo "  lint       Lint shell scripts"
    echo "  format     Format shell scripts"
    echo "  docs       Generate documentation"
    echo "  status     Show development status"
    echo "  help       Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 build                 # Build development image"
    echo "  $0 run                   # Start development container"
    echo "  $0 test                  # Run all tests"
    echo "  $0 test --unit          # Run unit tests only"
    echo "  $0 shell                 # Connect to running container"
    echo "  $0 logs dockerkit        # Watch specific service logs"
}

# Main execution
main() {
    check_docker
    
    case "$ACTION" in
        build)
            dev_build
            ;;
        run)
            dev_run
            ;;
        test)
            shift
            dev_test "$@"
            ;;
        shell)
            dev_shell
            ;;
        logs)
            dev_logs "$@"
            ;;
        clean)
            dev_clean
            ;;
        lint)
            dev_lint
            ;;
        format)
            dev_format
            ;;
        docs)
            dev_docs
            ;;
        status)
            dev_status
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}Unknown command: $ACTION${NC}"
            show_help
            exit 1
            ;;
    esac
}

# Run main
main "$@"