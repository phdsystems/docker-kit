#!/bin/bash

# ==============================================================================
# DockerKit Image Build Script
# ==============================================================================
# Builds the optimized parallel DockerKit image with BuildKit
# ==============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DOCKERFILE="${SCRIPT_DIR}/Dockerfile.dockerkit"
IMAGE_NAME="${IMAGE_NAME:-dockerkit}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
NO_CACHE="${NO_CACHE:-false}"

# Feature flags
INSTALL_API="${INSTALL_API:-false}"
INSTALL_UI="${INSTALL_UI:-false}"
INSTALL_MONITORING="${INSTALL_MONITORING:-false}"
INSTALL_BACKUP_TOOLS="${INSTALL_BACKUP_TOOLS:-false}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-cache)
            NO_CACHE=true
            shift
            ;;
        --tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        --name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        --with-api)
            INSTALL_API=true
            shift
            ;;
        --with-ui)
            INSTALL_UI=true
            shift
            ;;
        --with-monitoring)
            INSTALL_MONITORING=true
            shift
            ;;
        --with-backup)
            INSTALL_BACKUP_TOOLS=true
            shift
            ;;
        --full)
            INSTALL_API=true
            INSTALL_UI=true
            INSTALL_MONITORING=true
            INSTALL_BACKUP_TOOLS=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --no-cache        Build without cache"
            echo "  --tag TAG         Image tag (default: latest)"
            echo "  --name NAME       Image name (default: dockerkit)"
            echo "  --with-api        Include API components"
            echo "  --with-ui         Include UI components"
            echo "  --with-monitoring Include monitoring tools"
            echo "  --with-backup     Include backup tools"
            echo "  --full            Include all optional components"
            echo "  --help            Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Print build configuration
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              DockerKit Image Builder                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo -e "  Image: ${GREEN}${IMAGE_NAME}:${IMAGE_TAG}${NC}"
echo -e "  Dockerfile: ${GREEN}${DOCKERFILE}${NC}"
echo -e "  BuildKit: ${GREEN}Enabled${NC}"
echo -e "  Cache: ${GREEN}$([ "$NO_CACHE" = "true" ] && echo "Disabled" || echo "Enabled")${NC}"
echo ""
echo -e "${YELLOW}Features:${NC}"
echo -e "  API: ${GREEN}$([ "$INSTALL_API" = "true" ] && echo "✓" || echo "✗")${NC}"
echo -e "  UI: ${GREEN}$([ "$INSTALL_UI" = "true" ] && echo "✓" || echo "✗")${NC}"
echo -e "  Monitoring: ${GREEN}$([ "$INSTALL_MONITORING" = "true" ] && echo "✓" || echo "✗")${NC}"
echo -e "  Backup Tools: ${GREEN}$([ "$INSTALL_BACKUP_TOOLS" = "true" ] && echo "✓" || echo "✗")${NC}"
echo ""

# Check if Docker is running
if ! sudo docker info >/dev/null 2>&1; then
    echo -e "${RED}Error: Docker daemon is not running${NC}"
    exit 1
fi

# Build command
BUILD_CMD="sudo DOCKER_BUILDKIT=1 docker build"

# Add no-cache flag if requested
if [ "$NO_CACHE" = "true" ]; then
    BUILD_CMD="$BUILD_CMD --no-cache"
    echo -e "${YELLOW}Building from scratch (no cache)...${NC}"
else
    echo -e "${YELLOW}Building with cache...${NC}"
fi

# Add build arguments
BUILD_CMD="$BUILD_CMD \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    --build-arg INSTALL_API=${INSTALL_API} \
    --build-arg INSTALL_UI=${INSTALL_UI} \
    --build-arg INSTALL_MONITORING=${INSTALL_MONITORING} \
    --build-arg INSTALL_BACKUP_TOOLS=${INSTALL_BACKUP_TOOLS} \
    -f $DOCKERFILE \
    -t ${IMAGE_NAME}:${IMAGE_TAG} \
    $PROJECT_ROOT"

# Execute build
echo -e "${BLUE}Executing build...${NC}"
echo ""

START_TIME=$(date +%s)

if eval "$BUILD_CMD"; then
    END_TIME=$(date +%s)
    BUILD_TIME=$((END_TIME - START_TIME))

    echo ""
    echo -e "${GREEN}✅ Build completed successfully in ${BUILD_TIME} seconds!${NC}"

    echo ""
    echo -e "${BLUE}Image Information:${NC}"
    sudo docker images | grep -E "REPOSITORY|${IMAGE_NAME}.*${IMAGE_TAG}"

    IMAGE_SIZE=$(sudo docker images --format "{{.Size}}" ${IMAGE_NAME}:${IMAGE_TAG})

    echo ""
    echo -e "${BLUE}Build Optimizations:${NC}"
    echo "  • Parallel build stages for faster builds"
    echo "  • BuildKit cache mounts for package managers"
    echo "  • Optimized layer caching"
    echo "  • Image size: ${IMAGE_SIZE}"
    echo "  • Build time: ${BUILD_TIME} seconds"
    echo ""

    echo -e "${YELLOW}To run DockerKit:${NC}"
    echo "  docker run -it --rm -v /var/run/docker.sock:/var/run/docker.sock ${IMAGE_NAME}:${IMAGE_TAG}"
    echo ""
    echo -e "${YELLOW}To run with persistent data:${NC}"
    echo "  docker run -it --rm \\"
    echo "    -v /var/run/docker.sock:/var/run/docker.sock \\"
    echo "    -v dockerkit-data:/var/lib/dockerkit/data \\"
    echo "    -v dockerkit-logs:/var/lib/dockerkit/logs \\"
    echo "    ${IMAGE_NAME}:${IMAGE_TAG}"
else
    echo ""
    echo -e "${RED}❌ Build failed!${NC}"
    exit 1
fi
