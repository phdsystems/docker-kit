#!/bin/bash

# DockerKit Image Operations
# Provides pull, push, build, remove, tag, save, load operations for images

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
IMAGE=""
TAG=""
REGISTRY=""
PLATFORM=""
NO_CACHE=false
FORCE=false
ALL_TAGS=false
QUIET=false
BUILD_ARGS=()
DOCKERFILE="Dockerfile"
CONTEXT="."
TARGET=""
OUTPUT=""

# Show help
show_help() {
    cat << EOF
DockerKit Image Operations

USAGE:
    $(basename "$0") <action> [image] [options]

ACTIONS:
    pull        Pull image from registry
    push        Push image to registry
    build       Build image from Dockerfile
    remove|rmi  Remove image(s)
    tag         Tag an image
    save        Save image to tar archive
    load        Load image from tar archive
    import      Import image from tarball
    history     Show image history
    inspect     Inspect image details
    prune       Remove unused images

PULL OPTIONS:
    -a, --all-tags      Pull all tags
    --platform PLATFORM Platform (linux/amd64, linux/arm64, etc.)
    -q, --quiet         Suppress verbose output

PUSH OPTIONS:
    -a, --all-tags      Push all tags
    --registry REGISTRY Registry URL

BUILD OPTIONS:
    -f, --file FILE     Dockerfile path (default: Dockerfile)
    -t, --tag TAG       Tag for built image
    --no-cache          Build without cache
    --build-arg ARG     Build argument (can be used multiple times)
    --target TARGET     Target build stage
    --platform PLATFORM Target platform
    --progress TYPE     Progress output type (auto, plain, tty)

REMOVE OPTIONS:
    -f, --force         Force removal
    -a, --all           Remove all unused images
    --filter FILTER     Filter images (dangling=true, etc.)

SAVE/LOAD OPTIONS:
    -o, --output FILE   Output file for save
    -i, --input FILE    Input file for load

EXAMPLES:
    # Pull latest nginx image
    $(basename "$0") pull nginx:latest

    # Pull all tags for an image
    $(basename "$0") pull nginx --all-tags

    # Build image from Dockerfile
    $(basename "$0") build -t myapp:v1.0 -f ./Dockerfile .

    # Build with arguments
    $(basename "$0") build -t myapp:latest --build-arg VERSION=1.0 --no-cache

    # Push image to registry
    $(basename "$0") push myregistry.com/myapp:latest

    # Tag an image
    $(basename "$0") tag myapp:latest myapp:v1.0

    # Save image to file
    $(basename "$0") save nginx:latest -o nginx.tar

    # Load image from file
    $(basename "$0") load -i nginx.tar

    # Remove image
    $(basename "$0") remove nginx:old

    # Remove all dangling images
    $(basename "$0") prune

    # Show image history
    $(basename "$0") history nginx:latest

EOF
}

# Pull image
pull_image() {
    if [[ -z "$IMAGE" ]]; then
        echo -e "${RED}Error: No image specified${NC}"
        exit 1
    fi
    
    local pull_args=""
    
    if [[ "$ALL_TAGS" == "true" ]]; then
        pull_args="$pull_args --all-tags"
    fi
    
    if [[ -n "$PLATFORM" ]]; then
        pull_args="$pull_args --platform $PLATFORM"
    fi
    
    if [[ "$QUIET" == "true" ]]; then
        pull_args="$pull_args --quiet"
    fi
    
    echo -e "${CYAN}Pulling image: $IMAGE${NC}"
    
    if $DOCKER_CMD pull $pull_args "$IMAGE"; then
        echo -e "${GREEN}✓ Image pulled successfully${NC}"
        
        # Show image details
        if [[ "$QUIET" != "true" ]]; then
            echo -e "\n${CYAN}Image details:${NC}"
            $DOCKER_CMD images --filter "reference=$IMAGE" --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}\t{{.CreatedAt}}"
        fi
    else
        echo -e "${RED}✗ Failed to pull image${NC}"
        exit 1
    fi
}

# Push image
push_image() {
    if [[ -z "$IMAGE" ]]; then
        echo -e "${RED}Error: No image specified${NC}"
        exit 1
    fi
    
    local push_args=""
    
    if [[ "$ALL_TAGS" == "true" ]]; then
        push_args="$push_args --all-tags"
    fi
    
    # Add registry prefix if specified
    local full_image="$IMAGE"
    if [[ -n "$REGISTRY" ]]; then
        full_image="$REGISTRY/$IMAGE"
        
        # Tag image with registry
        echo -e "${CYAN}Tagging image for registry: $full_image${NC}"
        $DOCKER_CMD tag "$IMAGE" "$full_image"
    fi
    
    echo -e "${CYAN}Pushing image: $full_image${NC}"
    
    if $DOCKER_CMD push $push_args "$full_image"; then
        echo -e "${GREEN}✓ Image pushed successfully${NC}"
    else
        echo -e "${RED}✗ Failed to push image${NC}"
        exit 1
    fi
}

# Build image
build_image() {
    local build_args=""
    
    if [[ -n "$TAG" ]]; then
        build_args="$build_args -t $TAG"
    fi
    
    if [[ "$NO_CACHE" == "true" ]]; then
        build_args="$build_args --no-cache"
    fi
    
    if [[ -n "$DOCKERFILE" ]]; then
        build_args="$build_args -f $DOCKERFILE"
    fi
    
    if [[ -n "$TARGET" ]]; then
        build_args="$build_args --target $TARGET"
    fi
    
    if [[ -n "$PLATFORM" ]]; then
        build_args="$build_args --platform $PLATFORM"
    fi
    
    for arg in "${BUILD_ARGS[@]}"; do
        build_args="$build_args --build-arg $arg"
    done
    
    echo -e "${CYAN}Building image...${NC}"
    if [[ -n "$TAG" ]]; then
        echo -e "${CYAN}Tag: $TAG${NC}"
    fi
    echo -e "${CYAN}Dockerfile: $DOCKERFILE${NC}"
    echo -e "${CYAN}Context: $CONTEXT${NC}"
    
    if $DOCKER_CMD build $build_args "$CONTEXT"; then
        echo -e "${GREEN}✓ Image built successfully${NC}"
        
        if [[ -n "$TAG" ]]; then
            echo -e "\n${CYAN}Built image:${NC}"
            $DOCKER_CMD images --filter "reference=$TAG" --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}\t{{.CreatedAt}}"
        fi
    else
        echo -e "${RED}✗ Failed to build image${NC}"
        exit 1
    fi
}

# Remove image
remove_image() {
    if [[ -z "$IMAGE" ]] && [[ "$FORCE" != "true" ]]; then
        echo -e "${RED}Error: No image specified${NC}"
        exit 1
    fi
    
    local rm_args=""
    
    if [[ "$FORCE" == "true" ]]; then
        rm_args="$rm_args -f"
    fi
    
    if [[ -n "$IMAGE" ]]; then
        echo -e "${CYAN}Removing image: $IMAGE${NC}"
        
        if $DOCKER_CMD rmi $rm_args "$IMAGE"; then
            echo -e "${GREEN}✓ Image removed successfully${NC}"
        else
            echo -e "${RED}✗ Failed to remove image${NC}"
            echo -e "${YELLOW}Tip: Use --force to remove image used by containers${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}No specific image specified${NC}"
    fi
}

# Tag image
tag_image() {
    if [[ -z "$IMAGE" ]] || [[ -z "$TAG" ]]; then
        echo -e "${RED}Error: Source image and target tag required${NC}"
        echo "Usage: $(basename "$0") tag <source> <target>"
        exit 1
    fi
    
    echo -e "${CYAN}Tagging image $IMAGE as $TAG${NC}"
    
    if $DOCKER_CMD tag "$IMAGE" "$TAG"; then
        echo -e "${GREEN}✓ Image tagged successfully${NC}"
        
        echo -e "\n${CYAN}Tagged image:${NC}"
        $DOCKER_CMD images --filter "reference=$TAG" --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}"
    else
        echo -e "${RED}✗ Failed to tag image${NC}"
        exit 1
    fi
}

# Save image
save_image() {
    if [[ -z "$IMAGE" ]]; then
        echo -e "${RED}Error: No image specified${NC}"
        exit 1
    fi
    
    if [[ -z "$OUTPUT" ]]; then
        OUTPUT="${IMAGE//\//_}.tar"
        OUTPUT="${OUTPUT//:/_}"
    fi
    
    echo -e "${CYAN}Saving image $IMAGE to $OUTPUT${NC}"
    
    if $DOCKER_CMD save -o "$OUTPUT" "$IMAGE"; then
        local size
        size=$(du -h "$OUTPUT" | cut -f1)
        echo -e "${GREEN}✓ Image saved successfully (${size})${NC}"
    else
        echo -e "${RED}✗ Failed to save image${NC}"
        exit 1
    fi
}

# Load image
load_image() {
    if [[ -z "$OUTPUT" ]]; then
        echo -e "${RED}Error: No input file specified${NC}"
        echo "Use -i or --input to specify the tar file"
        exit 1
    fi
    
    if [[ ! -f "$OUTPUT" ]]; then
        echo -e "${RED}Error: File not found: $OUTPUT${NC}"
        exit 1
    fi
    
    echo -e "${CYAN}Loading image from $OUTPUT${NC}"
    
    if $DOCKER_CMD load -i "$OUTPUT"; then
        echo -e "${GREEN}✓ Image loaded successfully${NC}"
        
        echo -e "\n${CYAN}Loaded images:${NC}"
        $DOCKER_CMD images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}\t{{.CreatedAt}}" | head -5
    else
        echo -e "${RED}✗ Failed to load image${NC}"
        exit 1
    fi
}

# Import image
import_image() {
    local tarball="$1"
    local tag="$2"
    
    if [[ -z "$tarball" ]]; then
        echo -e "${RED}Error: No tarball specified${NC}"
        exit 1
    fi
    
    if [[ ! -f "$tarball" ]]; then
        echo -e "${RED}Error: File not found: $tarball${NC}"
        exit 1
    fi
    
    echo -e "${CYAN}Importing image from $tarball${NC}"
    
    if [[ -n "$tag" ]]; then
        echo -e "${CYAN}Tag: $tag${NC}"
        cat "$tarball" | $DOCKER_CMD import - "$tag"
    else
        cat "$tarball" | $DOCKER_CMD import -
    fi
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Image imported successfully${NC}"
    else
        echo -e "${RED}✗ Failed to import image${NC}"
        exit 1
    fi
}

# Show image history
show_history() {
    if [[ -z "$IMAGE" ]]; then
        echo -e "${RED}Error: No image specified${NC}"
        exit 1
    fi
    
    echo -e "${CYAN}History for image: $IMAGE${NC}"
    $DOCKER_CMD history "$IMAGE"
}

# Inspect image
inspect_image() {
    if [[ -z "$IMAGE" ]]; then
        echo -e "${RED}Error: No image specified${NC}"
        exit 1
    fi
    
    echo -e "${CYAN}Inspecting image: $IMAGE${NC}"
    $DOCKER_CMD inspect "$IMAGE" | jq '.' 2>/dev/null || $DOCKER_CMD inspect "$IMAGE"
}

# Prune unused images
prune_images() {
    echo -e "${CYAN}Removing unused images...${NC}"
    
    local prune_args=""
    
    if [[ "$FORCE" == "true" ]]; then
        prune_args="$prune_args -f"
    fi
    
    if [[ "$ALL" == "true" ]]; then
        prune_args="$prune_args -a"
    fi
    
    # Show what will be removed
    if [[ "$FORCE" != "true" ]]; then
        echo -e "${YELLOW}The following images will be removed:${NC}"
        $DOCKER_CMD images -f "dangling=true" --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}"
        
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${RED}Operation cancelled${NC}"
            exit 1
        fi
    fi
    
    local result
    result=$($DOCKER_CMD image prune $prune_args)
    
    echo "$result"
    echo -e "${GREEN}✓ Image pruning complete${NC}"
}

# Parse arguments
ALL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        pull|push|build|remove|rmi|tag|save|load|import|history|inspect|prune)
            ACTION="$1"
            if [[ "$ACTION" == "rmi" ]]; then
                ACTION="remove"
            fi
            shift
            if [[ $# -gt 0 ]] && [[ ! "$1" =~ ^- ]]; then
                IMAGE="$1"
                shift
                if [[ "$ACTION" == "tag" ]] && [[ $# -gt 0 ]] && [[ ! "$1" =~ ^- ]]; then
                    TAG="$1"
                    shift
                elif [[ "$ACTION" == "import" ]] && [[ $# -gt 0 ]] && [[ ! "$1" =~ ^- ]]; then
                    TAG="$1"
                    shift
                fi
            fi
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -f|--file)
            DOCKERFILE="$2"
            shift 2
            ;;
        --force)
            FORCE=true
            shift
            ;;
        -a|--all-tags|--all)
            ALL_TAGS=true
            ALL=true
            shift
            ;;
        --no-cache)
            NO_CACHE=true
            shift
            ;;
        --build-arg)
            BUILD_ARGS+=("$2")
            shift 2
            ;;
        --target)
            TARGET="$2"
            shift 2
            ;;
        --platform)
            PLATFORM="$2"
            shift 2
            ;;
        --registry)
            REGISTRY="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT="$2"
            shift 2
            ;;
        -i|--input)
            OUTPUT="$2"
            shift 2
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            if [[ "$ACTION" == "build" ]] && [[ -z "$CONTEXT" ]]; then
                CONTEXT="$1"
            elif [[ -z "$IMAGE" ]]; then
                IMAGE="$1"
            fi
            shift
            ;;
    esac
done

# Execute action
case "$ACTION" in
    pull)
        pull_image
        ;;
    push)
        push_image
        ;;
    build)
        build_image
        ;;
    remove)
        remove_image
        ;;
    tag)
        tag_image
        ;;
    save)
        save_image
        ;;
    load)
        load_image
        ;;
    import)
        import_image "$IMAGE" "$TAG"
        ;;
    history)
        show_history
        ;;
    inspect)
        inspect_image
        ;;
    prune)
        prune_images
        ;;
    *)
        echo -e "${RED}Error: No action specified${NC}"
        show_help
        exit 1
        ;;
esac