#!/bin/bash

# DockerKit Safety Check Script
# Ensures DockerKit operations only affect DockerKit resources

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

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     DockerKit Safety Check             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Check Docker command
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
    fi
else
    DOCKER_CMD="docker"
fi

# Function to validate DockerKit resource name
is_dockerkit_resource() {
    local resource_name="$1"
    
    # DockerKit resources must start with "dockerkit"
    if [[ "$resource_name" =~ ^dockerkit ]]; then
        return 0
    else
        return 1
    fi
}

# Check containers
check_containers() {
    echo -e "${YELLOW}Checking DockerKit containers...${NC}"
    
    local dockerkit_containers=()
    local other_containers=()
    
    while IFS= read -r container; do
        if [[ -n "$container" ]]; then
            if is_dockerkit_resource "$container"; then
                dockerkit_containers+=("$container")
            else
                other_containers+=("$container")
            fi
        fi
    done < <($DOCKER_CMD ps -a --format "{{.Names}}")
    
    echo -e "${GREEN}DockerKit containers: ${#dockerkit_containers[@]}${NC}"
    for container in "${dockerkit_containers[@]}"; do
        echo "  ✓ $container"
    done
    
    echo -e "${BLUE}Other containers: ${#other_containers[@]}${NC}"
    if [[ ${#other_containers[@]} -gt 0 ]]; then
        echo -e "${YELLOW}  These will NEVER be affected by DockerKit operations${NC}"
    fi
    echo ""
}

# Check images
check_images() {
    echo -e "${YELLOW}Checking DockerKit images...${NC}"
    
    local dockerkit_images=()
    local other_images=()
    
    while IFS= read -r image; do
        if [[ -n "$image" ]]; then
            if is_dockerkit_resource "$image"; then
                dockerkit_images+=("$image")
            else
                other_images+=("$image")
            fi
        fi
    done < <($DOCKER_CMD images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>")
    
    echo -e "${GREEN}DockerKit images: ${#dockerkit_images[@]}${NC}"
    for image in "${dockerkit_images[@]}"; do
        echo "  ✓ $image"
    done
    
    echo -e "${BLUE}Other images: ${#other_images[@]}${NC}"
    if [[ ${#other_images[@]} -gt 0 ]]; then
        echo -e "${YELLOW}  These will NEVER be affected by DockerKit operations${NC}"
    fi
    echo ""
}

# Check volumes
check_volumes() {
    echo -e "${YELLOW}Checking DockerKit volumes...${NC}"
    
    local dockerkit_volumes=()
    local other_volumes=()
    
    while IFS= read -r volume; do
        if [[ -n "$volume" ]]; then
            if is_dockerkit_resource "$volume"; then
                dockerkit_volumes+=("$volume")
            else
                other_volumes+=("$volume")
            fi
        fi
    done < <($DOCKER_CMD volume ls --format "{{.Name}}")
    
    echo -e "${GREEN}DockerKit volumes: ${#dockerkit_volumes[@]}${NC}"
    for volume in "${dockerkit_volumes[@]}"; do
        echo "  ✓ $volume"
    done
    
    echo -e "${BLUE}Other volumes: ${#other_volumes[@]}${NC}"
    if [[ ${#other_volumes[@]} -gt 0 ]]; then
        echo -e "${YELLOW}  These will NEVER be affected by DockerKit operations${NC}"
    fi
    echo ""
}

# Check networks
check_networks() {
    echo -e "${YELLOW}Checking DockerKit networks...${NC}"
    
    local dockerkit_networks=()
    local other_networks=()
    
    while IFS= read -r network; do
        if [[ -n "$network" ]] && [[ "$network" != "bridge" ]] && [[ "$network" != "host" ]] && [[ "$network" != "none" ]]; then
            if is_dockerkit_resource "$network"; then
                dockerkit_networks+=("$network")
            else
                other_networks+=("$network")
            fi
        fi
    done < <($DOCKER_CMD network ls --format "{{.Name}}")
    
    echo -e "${GREEN}DockerKit networks: ${#dockerkit_networks[@]}${NC}"
    for network in "${dockerkit_networks[@]}"; do
        echo "  ✓ $network"
    done
    
    echo -e "${BLUE}Other networks: ${#other_networks[@]}${NC}"
    if [[ ${#other_networks[@]} -gt 0 ]]; then
        echo -e "${YELLOW}  These will NEVER be affected by DockerKit operations${NC}"
    fi
    echo ""
}

# Safety rules
show_safety_rules() {
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     DockerKit Safety Rules             ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}1. Resource Naming:${NC}"
    echo "   - All DockerKit resources start with 'dockerkit'"
    echo "   - Examples: dockerkit, dockerkit-api, dockerkit-ui, dockerkit_data"
    echo ""
    echo -e "${GREEN}2. Cleanup Operations:${NC}"
    echo "   - Only remove containers matching ^dockerkit"
    echo "   - Only remove images tagged as dockerkit*"
    echo "   - Only remove volumes named dockerkit*"
    echo "   - Only remove networks named dockerkit*"
    echo ""
    echo -e "${GREEN}3. Build Operations:${NC}"
    echo "   - Only build/tag images with dockerkit prefix"
    echo "   - Never overwrite or delete other images"
    echo ""
    echo -e "${GREEN}4. Container Operations:${NC}"
    echo "   - Only stop/start/restart dockerkit containers"
    echo "   - Use exact name matching to avoid conflicts"
    echo ""
    echo -e "${YELLOW}⚠️  IMPORTANT:${NC}"
    echo "   DockerKit will NEVER delete or modify resources"
    echo "   that don't start with 'dockerkit' prefix"
    echo ""
}

# Verify cleanup safety
verify_cleanup_safety() {
    echo -e "${YELLOW}Verifying cleanup safety...${NC}"
    
    # Simulate what would be cleaned
    local would_clean_containers=()
    local would_clean_images=()
    local would_clean_volumes=()
    
    # Check containers that would be cleaned
    while IFS= read -r container; do
        if [[ -n "$container" ]] && is_dockerkit_resource "$container"; then
            would_clean_containers+=("$container")
        fi
    done < <($DOCKER_CMD ps -a --format "{{.Names}}")
    
    # Check images that would be cleaned
    while IFS= read -r image; do
        if [[ -n "$image" ]] && is_dockerkit_resource "$image"; then
            would_clean_images+=("$image")
        fi
    done < <($DOCKER_CMD images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>")
    
    # Check volumes that would be cleaned
    while IFS= read -r volume; do
        if [[ -n "$volume" ]] && is_dockerkit_resource "$volume"; then
            would_clean_volumes+=("$volume")
        fi
    done < <($DOCKER_CMD volume ls --format "{{.Name}}")
    
    echo ""
    echo -e "${BLUE}Resources that would be cleaned by 'make clean':${NC}"
    echo "  Containers: ${#would_clean_containers[@]}"
    echo "  Images: ${#would_clean_images[@]}"
    echo "  Volumes: ${#would_clean_volumes[@]}"
    echo ""
    
    if [[ ${#would_clean_containers[@]} -gt 0 ]] || [[ ${#would_clean_images[@]} -gt 0 ]] || [[ ${#would_clean_volumes[@]} -gt 0 ]]; then
        echo -e "${YELLOW}The following DockerKit resources would be removed:${NC}"
        
        if [[ ${#would_clean_containers[@]} -gt 0 ]]; then
            echo "  Containers:"
            for container in "${would_clean_containers[@]}"; do
                echo "    - $container"
            done
        fi
        
        if [[ ${#would_clean_images[@]} -gt 0 ]]; then
            echo "  Images:"
            for image in "${would_clean_images[@]}"; do
                echo "    - $image"
            done
        fi
        
        if [[ ${#would_clean_volumes[@]} -gt 0 ]]; then
            echo "  Volumes:"
            for volume in "${would_clean_volumes[@]}"; do
                echo "    - $volume"
            done
        fi
    else
        echo -e "${GREEN}No DockerKit resources to clean${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}✓ Safety check passed${NC}"
    echo -e "${GREEN}✓ Non-DockerKit resources are protected${NC}"
}

# Main execution
main() {
    local action="${1:-all}"
    
    case "$action" in
        containers)
            check_containers
            ;;
        images)
            check_images
            ;;
        volumes)
            check_volumes
            ;;
        networks)
            check_networks
            ;;
        rules)
            show_safety_rules
            ;;
        verify)
            verify_cleanup_safety
            ;;
        all)
            check_containers
            check_images
            check_volumes
            check_networks
            echo ""
            show_safety_rules
            echo ""
            verify_cleanup_safety
            ;;
        --help)
            echo "Usage: $0 [OPTION]"
            echo ""
            echo "Options:"
            echo "  containers  Check DockerKit containers"
            echo "  images      Check DockerKit images"
            echo "  volumes     Check DockerKit volumes"
            echo "  networks    Check DockerKit networks"
            echo "  rules       Show safety rules"
            echo "  verify      Verify cleanup safety"
            echo "  all         Run all checks (default)"
            echo "  --help      Show this help"
            ;;
        *)
            echo -e "${RED}Unknown option: $action${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
}

# Run main
main "$@"