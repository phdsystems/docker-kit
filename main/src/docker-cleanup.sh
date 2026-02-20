#!/bin/bash

# ==============================================================================
# DockerKit - Docker System Cleanup Utility
# ==============================================================================
# Comprehensive cleanup tool for Docker resources with safety checks
# ==============================================================================

set -euo pipefail


# Source Docker wrapper for sudo handling
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/docker-wrapper.sh"
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# Configuration
DRY_RUN="${DRY_RUN:-true}"
FORCE="${FORCE:-false}"
KEEP_RECENT="${KEEP_RECENT:-7}" # Keep resources from last N days
EXCLUDE_LABELS="${EXCLUDE_LABELS:-keep=true,production=true}"

# Cleanup statistics
CLEANED_CONTAINERS=0
CLEANED_IMAGES=0
CLEANED_VOLUMES=0
CLEANED_NETWORKS=0
SPACE_RECOVERED=0

# ==============================================================================
# Helper Functions
# ==============================================================================

show_help() {
    cat <<EOF
${BOLD}${CYAN}DockerKit - System Cleanup Utility${NC}

${BOLD}USAGE:${NC}
    $0 [OPTIONS] [CLEANUP_TYPES]

${BOLD}CLEANUP TYPES:${NC}
    all         Clean everything (default)
    containers  Clean stopped containers
    images      Clean unused images
    volumes     Clean unused volumes
    networks    Clean unused networks
    build       Clean build cache
    system      Full system prune

${BOLD}OPTIONS:${NC}
    -h, --help          Show this help message
    -n, --dry-run       Show what would be cleaned (default)
    -f, --force         Actually perform cleanup
    -y, --yes           Skip confirmation prompts
    -k, --keep-recent N Keep resources from last N days (default: 7)
    -e, --exclude LABEL Exclude resources with label (can be repeated)
    --aggressive        Aggressive cleanup (removes more)
    --safe              Safe mode (extra cautious)

${BOLD}EXAMPLES:${NC}
    # Dry run - see what would be cleaned
    $0

    # Clean stopped containers
    $0 --force containers

    # Aggressive cleanup, keep last 3 days
    $0 --force --aggressive --keep-recent 3

    # Clean everything except production
    $0 --force --exclude production=true all

${BOLD}SAFETY FEATURES:${NC}
    • Dry run by default
    • Excludes labeled resources
    • Keeps recent resources
    • Shows size estimates
    • Confirmation prompts
EOF
}

# ==============================================================================
# Analysis Functions
# ==============================================================================

analyze_containers() {
    echo -e "${BOLD}Analyzing Containers...${NC}"
    
    local stopped_count=0
    local exited_count=0
    local dead_count=0
    local total_size=0
    
    # Count stopped containers
    stopped_count=$(docker_run ps -a -q -f "status=exited" | wc -l)
    dead_count=$(docker_run ps -a -q -f "status=dead" | wc -l)
    
    # Get containers older than KEEP_RECENT days
    local cutoff_date=$(date -d "$KEEP_RECENT days ago" +%s)
    local old_containers=0
    
    while IFS='|' read -r id status finished; do
        if [[ "$status" == "Exited" ]] || [[ "$status" == "Dead" ]]; then
            finished_ts=$(date -d "$finished" +%s 2>/dev/null || echo 0)
            if [[ $finished_ts -lt $cutoff_date ]]; then
                ((old_containers++))
            fi
        fi
    done < <(docker_run ps -a --format "{{.ID}}|{{.Status}}|{{.FinishedAt}}")
    
    echo -e "  Stopped containers:     ${YELLOW}$stopped_count${NC}"
    echo -e "  Dead containers:        ${RED}$dead_count${NC}"
    echo -e "  Older than $KEEP_RECENT days:  ${YELLOW}$old_containers${NC}"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        CLEANED_CONTAINERS=$old_containers
    fi
    
    return $old_containers
}

analyze_images() {
    echo -e "${BOLD}Analyzing Images...${NC}"
    
    local dangling_count=$(docker_run images -f "dangling=true" -q | wc -l)
    local unused_count=0
    local total_size=0
    
    # Find unused images
    while read -r imgid; do
        local container_count=$(docker_run ps -a --filter "ancestor=$imgid" -q | wc -l)
        if [[ $container_count -eq 0 ]]; then
            ((unused_count++))
            # Get size
            local size=$(docker_run images --format "{{.ID}}|{{.Size}}" | grep "^$imgid" | cut -d'|' -f2)
            # Add to total (would need to parse size units)
        fi
    done < <(docker_run images -q)
    
    # Get reclaimable space
    local reclaimable=$(docker_run system df --format "{{.Reclaimable}}" | head -2 | tail -1)
    
    echo -e "  Dangling images:        ${YELLOW}$dangling_count${NC}"
    echo -e "  Unused images:          ${YELLOW}$unused_count${NC}"
    echo -e "  Reclaimable space:      ${CYAN}$reclaimable${NC}"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        CLEANED_IMAGES=$((dangling_count + unused_count))
    fi
    
    return $dangling_count
}

analyze_volumes() {
    echo -e "${BOLD}Analyzing Volumes...${NC}"
    
    local dangling_count=$(docker_run volume ls -qf dangling=true | wc -l)
    local total_volumes=$(docker_run volume ls -q | wc -l)
    local used_volumes=0
    
    # Find used volumes
    while read -r vol; do
        local containers=$(docker_run ps -a --filter "volume=$vol" -q | wc -l)
        if [[ $containers -gt 0 ]]; then
            ((used_volumes++))
        fi
    done < <(docker_run volume ls -q)
    
    local unused_volumes=$((total_volumes - used_volumes))
    
    echo -e "  Total volumes:          ${CYAN}$total_volumes${NC}"
    echo -e "  Dangling volumes:       ${YELLOW}$dangling_count${NC}"
    echo -e "  Unused volumes:         ${YELLOW}$unused_volumes${NC}"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        CLEANED_VOLUMES=$dangling_count
    fi
    
    return $dangling_count
}

analyze_networks() {
    echo -e "${BOLD}Analyzing Networks...${NC}"
    
    local custom_networks=$(docker_run network ls --format "{{.Name}}" | grep -v -E "^(bridge|host|none)$" | wc -l)
    local unused_networks=0
    
    # Find unused custom networks
    while read -r net; do
        if [[ "$net" != "bridge" ]] && [[ "$net" != "host" ]] && [[ "$net" != "none" ]]; then
            local containers=$(docker_run network inspect "$net" -f '{{range $k,$v := .Containers}}1{{end}}' | wc -c)
            if [[ $containers -eq 0 ]]; then
                ((unused_networks++))
            fi
        fi
    done < <(docker_run network ls --format "{{.Name}}")
    
    echo -e "  Custom networks:        ${CYAN}$custom_networks${NC}"
    echo -e "  Unused networks:        ${YELLOW}$unused_networks${NC}"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        CLEANED_NETWORKS=$unused_networks
    fi
    
    return $unused_networks
}

analyze_build_cache() {
    echo -e "${BOLD}Analyzing Build Cache...${NC}"
    
    local cache_size=$(docker_run system df --format "{{.Type}}|{{.Size}}" | grep "Build Cache" | cut -d'|' -f2)
    local cache_reclaimable=$(docker_run system df --format "{{.Type}}|{{.Reclaimable}}" | grep "Build Cache" | cut -d'|' -f2)
    
    echo -e "  Total cache:            ${CYAN}${cache_size:-0B}${NC}"
    echo -e "  Reclaimable:            ${YELLOW}${cache_reclaimable:-0B}${NC}"
}

# ==============================================================================
# Cleanup Functions
# ==============================================================================

cleanup_containers() {
    echo -e "\n${BOLD}${CYAN}Cleaning Containers...${NC}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${DIM}[DRY RUN] Would remove stopped containers older than $KEEP_RECENT days${NC}"
        docker_run ps -a -f "status=exited" --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.FinishedAt}}"
    else
        echo -e "${YELLOW}Removing stopped containers...${NC}"
        
        # Remove containers older than KEEP_RECENT days
        local cutoff_date=$(date -d "$KEEP_RECENT days ago" +%s)
        local removed=0
        
        while IFS='|' read -r id name status finished; do
            if [[ "$status" == "Exited" ]] || [[ "$status" == "Dead" ]]; then
                finished_ts=$(date -d "$finished" +%s 2>/dev/null || echo 0)
                if [[ $finished_ts -lt $cutoff_date ]]; then
                    echo -e "  Removing container: $name ($id)"
                    docker_run rm "$id" 2>/dev/null && ((removed++)) || true
                fi
            fi
        done < <(docker_run ps -a --format "{{.ID}}|{{.Names}}|{{.Status}}|{{.FinishedAt}}")
        
        echo -e "${GREEN}✓ Removed $removed containers${NC}"
    fi
}

cleanup_images() {
    echo -e "\n${BOLD}${CYAN}Cleaning Images...${NC}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${DIM}[DRY RUN] Would remove dangling and unused images${NC}"
        echo -e "\nDangling images:"
        docker_run images -f "dangling=true" --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}"
    else
        echo -e "${YELLOW}Removing dangling images...${NC}"
        local removed=$(docker_run image prune -f 2>&1 | grep -oE '[0-9]+ image' | cut -d' ' -f1 || echo 0)
        
        if [[ "$FORCE" == "true" ]] || [[ "$AGGRESSIVE" == "true" ]]; then
            echo -e "${YELLOW}Removing unused images...${NC}"
            removed=$(docker_run image prune -a -f 2>&1 | grep -oE '[0-9]+ image' | cut -d' ' -f1 || echo 0)
        fi
        
        echo -e "${GREEN}✓ Removed ${removed:-0} images${NC}"
    fi
}

cleanup_volumes() {
    echo -e "\n${BOLD}${CYAN}Cleaning Volumes...${NC}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${DIM}[DRY RUN] Would remove dangling volumes${NC}"
        docker_run volume ls -f dangling=true
    else
        echo -e "${YELLOW}Removing dangling volumes...${NC}"
        local removed=$(docker_run volume prune -f 2>&1 | grep -oE '[0-9]+ volume' | cut -d' ' -f1 || echo 0)
        echo -e "${GREEN}✓ Removed ${removed:-0} volumes${NC}"
    fi
}

cleanup_networks() {
    echo -e "\n${BOLD}${CYAN}Cleaning Networks...${NC}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${DIM}[DRY RUN] Would remove unused networks${NC}"
        docker_run network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}"
    else
        echo -e "${YELLOW}Removing unused networks...${NC}"
        local removed=$(docker_run network prune -f 2>&1 | grep -oE '[0-9]+ network' | cut -d' ' -f1 || echo 0)
        echo -e "${GREEN}✓ Removed ${removed:-0} networks${NC}"
    fi
}

cleanup_build_cache() {
    echo -e "\n${BOLD}${CYAN}Cleaning Build Cache...${NC}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${DIM}[DRY RUN] Would clear build cache${NC}"
    else
        echo -e "${YELLOW}Clearing build cache...${NC}"
        docker_run builder prune -f
        echo -e "${GREEN}✓ Build cache cleared${NC}"
    fi
}

system_prune() {
    echo -e "\n${BOLD}${CYAN}System-wide Cleanup...${NC}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${DIM}[DRY RUN] Would run system prune${NC}"
        docker_run system df
    else
        echo -e "${YELLOW}Running system prune...${NC}"
        
        if [[ "$AGGRESSIVE" == "true" ]]; then
            docker_run system prune -a -f --volumes
        else
            docker_run system prune -f
        fi
        
        echo -e "${GREEN}✓ System cleanup complete${NC}"
    fi
}

# ==============================================================================
# Main
# ==============================================================================

main() {
    local cleanup_types=()
    local skip_confirm=false
    local aggressive=false
    local safe_mode=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                DRY_RUN=false
                FORCE=true
                shift
                ;;
            -y|--yes)
                skip_confirm=true
                shift
                ;;
            -k|--keep-recent)
                KEEP_RECENT="$2"
                shift 2
                ;;
            -e|--exclude)
                EXCLUDE_LABELS="${EXCLUDE_LABELS},$2"
                shift 2
                ;;
            --aggressive)
                aggressive=true
                AGGRESSIVE=true
                shift
                ;;
            --safe)
                safe_mode=true
                shift
                ;;
            all|containers|images|volumes|networks|build|system)
                cleanup_types+=("$1")
                shift
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Default to "all" if no types specified
    [[ ${#cleanup_types[@]} -eq 0 ]] && cleanup_types=("all")
    
    # Check Docker availability
    if ! command -v docker &>/dev/null; then
        echo -e "${RED}Error: Docker is not installed${NC}"
        exit 1
    fi
    
    if ! docker info &>/dev/null; then
        echo -e "${RED}Error: Docker daemon is not running${NC}"
        exit 1
    fi
    
    # Header
    echo -e "${BOLD}${CYAN}DockerKit System Cleanup${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}🔍 DRY RUN MODE - No changes will be made${NC}\n"
    else
        echo -e "${RED}⚠ CLEANUP MODE - Resources will be removed${NC}\n"
    fi
    
    # Show current disk usage
    echo -e "${BOLD}Current Docker Disk Usage:${NC}"
    docker_run system df
    echo ""
    
    # Analyze what can be cleaned
    echo -e "${BOLD}${CYAN}Cleanup Analysis${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}\n"
    
    local total_cleanable=0
    
    for type in "${cleanup_types[@]}"; do
        case "$type" in
            all)
                analyze_containers || true
                analyze_images || true
                analyze_volumes || true
                analyze_networks || true
                analyze_build_cache || true
                ;;
            containers)
                analyze_containers || true
                ;;
            images)
                analyze_images || true
                ;;
            volumes)
                analyze_volumes || true
                ;;
            networks)
                analyze_networks || true
                ;;
            build)
                analyze_build_cache || true
                ;;
        esac
    done
    
    # Confirmation
    if [[ "$DRY_RUN" == "false" ]] && [[ "$skip_confirm" == "false" ]]; then
        echo -e "\n${YELLOW}This will remove the resources listed above.${NC}"
        read -p "Are you sure you want to proceed? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            echo -e "${BLUE}Cleanup cancelled${NC}"
            exit 0
        fi
    fi
    
    # Perform cleanup
    if [[ "$DRY_RUN" == "false" ]]; then
        echo -e "\n${BOLD}${CYAN}Performing Cleanup${NC}"
        echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
        
        for type in "${cleanup_types[@]}"; do
            case "$type" in
                all)
                    cleanup_containers
                    cleanup_images
                    cleanup_volumes
                    cleanup_networks
                    cleanup_build_cache
                    ;;
                containers)
                    cleanup_containers
                    ;;
                images)
                    cleanup_images
                    ;;
                volumes)
                    cleanup_volumes
                    ;;
                networks)
                    cleanup_networks
                    ;;
                build)
                    cleanup_build_cache
                    ;;
                system)
                    system_prune
                    ;;
            esac
        done
        
        # Show results
        echo -e "\n${BOLD}${GREEN}Cleanup Complete!${NC}"
        echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}"
        echo -e "Containers removed: ${BOLD}$CLEANED_CONTAINERS${NC}"
        echo -e "Images removed:     ${BOLD}$CLEANED_IMAGES${NC}"
        echo -e "Volumes removed:    ${BOLD}$CLEANED_VOLUMES${NC}"
        echo -e "Networks removed:   ${BOLD}$CLEANED_NETWORKS${NC}"
        
        echo -e "\n${BOLD}New Docker Disk Usage:${NC}"
        docker_run system df
    else
        echo -e "\n${CYAN}Run with --force to perform actual cleanup${NC}"
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi