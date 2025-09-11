#!/bin/bash

# ==============================================================================
# DockerKit Build Orchestrator
# ==============================================================================
# Main build script for DockerKit
# ==============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Show help
show_help() {
    echo -e "${BLUE}DockerKit Build System${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --no-cache   Build without cache"
    echo "  --full       Include all optional components"
    echo "  --help       Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Build DockerKit with defaults"
    echo "  $0 --full            # Build DockerKit with all features"
    echo "  $0 --no-cache        # Build without cache"
}

# Parse arguments
if [[ "$#" -gt 0 && ( "$1" == "--help" || "$1" == "-h" ) ]]; then
    show_help
    exit 0
fi

# Build DockerKit
echo -e "${BLUE}Building DockerKit image...${NC}"
exec ./build-targets/build-dockerkit.sh "$@"