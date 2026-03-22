#!/bin/bash

# DockerKit Build Script
# Builds the DockerKit Docker image and related components

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
echo -e "${BLUE}║      DockerKit Build Script            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Parse arguments
BUILD_PROFILE=""
NO_CACHE=false
PUSH=false
TAG="latest"

while [[ $# -gt 0 ]]; do
    case $1 in
        --profile)
            BUILD_PROFILE="$2"
            shift 2
            ;;
        --no-cache)
            NO_CACHE=true
            shift
            ;;
        --push)
            PUSH=true
            shift
            ;;
        --tag)
            TAG="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --profile PROFILE  Build specific profile (api, ui, all)"
            echo "  --no-cache        Build without using cache"
            echo "  --push            Push images to registry"
            echo "  --tag TAG         Tag for the images (default: latest)"
            echo "  --help            Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Check Docker
check_docker() {
    echo -e "${YELLOW}Checking Docker...${NC}"
    
    if ! command -v docker &>/dev/null; then
        echo -e "${RED}Error: Docker is not installed${NC}"
        exit 1
    fi
    
    if ! docker_run info &>/dev/null 2>&1; then
        if ! sudo docker info &>/dev/null 2>&1; then
            echo -e "${RED}Error: Docker daemon is not running${NC}"
            exit 1
        else
            echo -e "${YELLOW}Using sudo for Docker commands${NC}"
            DOCKER_CMD="sudo docker"
            COMPOSE_CMD="sudo docker-compose"
        fi
    else
        DOCKER_CMD="docker"
        COMPOSE_CMD="docker-compose"
    fi
    
    echo -e "${GREEN}✓ Docker is available${NC}"
}

# Build core image
build_core() {
    echo -e "\n${YELLOW}Building DockerKit core image...${NC}"
    
    cd "$DOCKERKIT_DIR"
    
    BUILD_ARGS=""
    if [[ "$NO_CACHE" == "true" ]]; then
        BUILD_ARGS="--no-cache"
    fi
    
    # IMPORTANT: Only tag with dockerkit-specific names
    # Never delete or overwrite other images
    $DOCKER_CMD build $BUILD_ARGS -t dockerkit:$TAG -f Dockerfile .
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Core image built successfully${NC}"
    else
        echo -e "${RED}✗ Failed to build core image${NC}"
        exit 1
    fi
}

# Build API image
build_api() {
    echo -e "\n${YELLOW}Building DockerKit API image...${NC}"
    
    if [[ ! -f "$DOCKERKIT_DIR/Dockerfile.api" ]]; then
        echo -e "${YELLOW}Creating Dockerfile.api...${NC}"
        cat > "$DOCKERKIT_DIR/Dockerfile.api" << 'EOF'
FROM dockerkit:latest

# Install API dependencies
RUN apk add --no-cache python3 py3-pip

# Install Python packages
RUN pip3 install --no-cache-dir \
    flask \
    docker \
    flask-cors \
    gunicorn

# Create API directory
WORKDIR /opt/dockerkit-api

# Copy API files (to be implemented)
# COPY api/ .

# Expose API port
EXPOSE 8080

# Run API server
CMD ["python3", "-m", "flask", "run", "--host=0.0.0.0", "--port=8080"]
EOF
    fi
    
    BUILD_ARGS=""
    if [[ "$NO_CACHE" == "true" ]]; then
        BUILD_ARGS="--no-cache"
    fi
    
    $DOCKER_CMD build $BUILD_ARGS -t dockerkit-api:$TAG -f Dockerfile.api .
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ API image built successfully${NC}"
    else
        echo -e "${RED}✗ Failed to build API image${NC}"
        exit 1
    fi
}

# Build UI image
build_ui() {
    echo -e "\n${YELLOW}Building DockerKit UI image...${NC}"
    
    if [[ ! -f "$DOCKERKIT_DIR/Dockerfile.ui" ]]; then
        echo -e "${YELLOW}Creating Dockerfile.ui...${NC}"
        cat > "$DOCKERKIT_DIR/Dockerfile.ui" << 'EOF'
FROM node:18-alpine

# Create UI directory
WORKDIR /opt/dockerkit-ui

# Copy UI files (to be implemented)
# COPY ui/package*.json ./
# RUN npm ci --only=production
# COPY ui/ .

# Expose UI port
EXPOSE 3000

# Run UI server
CMD ["npm", "start"]
EOF
    fi
    
    BUILD_ARGS=""
    if [[ "$NO_CACHE" == "true" ]]; then
        BUILD_ARGS="--no-cache"
    fi
    
    $DOCKER_CMD build $BUILD_ARGS -t dockerkit-ui:$TAG -f Dockerfile.ui .
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ UI image built successfully${NC}"
    else
        echo -e "${RED}✗ Failed to build UI image${NC}"
        exit 1
    fi
}

# Build with docker-compose
build_compose() {
    echo -e "\n${YELLOW}Building with docker-compose...${NC}"
    
    cd "$DOCKERKIT_DIR"
    
    BUILD_ARGS=""
    if [[ "$NO_CACHE" == "true" ]]; then
        BUILD_ARGS="--no-cache"
    fi
    
    if [[ -n "$BUILD_PROFILE" ]]; then
        $COMPOSE_CMD --profile $BUILD_PROFILE build $BUILD_ARGS
    else
        $COMPOSE_CMD build $BUILD_ARGS
    fi
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Docker-compose build successful${NC}"
    else
        echo -e "${RED}✗ Docker-compose build failed${NC}"
        exit 1
    fi
}

# Push images
push_images() {
    echo -e "\n${YELLOW}Pushing images to registry...${NC}"
    
    # You would need to tag with your registry here
    echo -e "${YELLOW}Note: Configure your registry before pushing${NC}"
    
    # Example:
    # $DOCKER_CMD tag dockerkit:$TAG your-registry/dockerkit:$TAG
    # $DOCKER_CMD push your-registry/dockerkit:$TAG
}

# Show summary
show_summary() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         Build Complete!                ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""
    
    echo "Built DockerKit images:"
    # Only show dockerkit-specific images
    $DOCKER_CMD images --filter "reference=dockerkit*" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
    
    echo ""
    echo "To run DockerKit:"
    echo "  docker-compose up -d"
    echo "  docker_run exec -it dockerkit bash"
    echo ""
    echo "Or run directly:"
    echo "  docker_run run -it --rm -v /var/run/docker.sock:/var/run/docker.sock dockerkit:$TAG"
    echo ""
    echo -e "${YELLOW}Note: DockerKit only manages its own images (dockerkit*)${NC}"
    echo -e "${YELLOW}Other Docker images on your system are never modified.${NC}"
}

# Main build process
main() {
    check_docker
    
    if [[ "$BUILD_PROFILE" == "all" ]]; then
        build_core
        build_api
        build_ui
    elif [[ "$BUILD_PROFILE" == "api" ]]; then
        build_core
        build_api
    elif [[ "$BUILD_PROFILE" == "ui" ]]; then
        build_core
        build_ui
    elif [[ -n "$BUILD_PROFILE" ]]; then
        build_compose
    else
        build_core
    fi
    
    if [[ "$PUSH" == "true" ]]; then
        push_images
    fi
    
    show_summary
}

# Run main build
main