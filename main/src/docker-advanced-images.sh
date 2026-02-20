#!/bin/bash

# ==============================================================================
# DockerKit - Advanced Docker Images Analysis
# ==============================================================================
# Enhanced image analysis with unique size tracking and container relationships
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
OUTPUT_FORMAT="${OUTPUT_FORMAT:-table}"
SORT_BY="${SORT_BY:-size}" # Options: size, age, name, unique
SHOW_DANGLING="${SHOW_DANGLING:-false}"
TOP_N="${TOP_N:-0}" # Show top N images by size (0 = all)

# ==============================================================================
# Helper Functions
# ==============================================================================

show_help() {
    cat <<EOF
${BOLD}${CYAN}DockerKit - Advanced Image Analysis${NC}

${BOLD}USAGE:${NC}
    $0 [OPTIONS]

${BOLD}OPTIONS:${NC}
    -h, --help          Show this help message
    -f, --format TYPE   Output format: table, json, csv (default: table)
    -s, --sort FIELD    Sort by: size, unique, age, name (default: size)
    -t, --top N         Show top N images by size
    -d, --dangling      Include dangling images
    --usage-report      Generate detailed usage report
    --find-duplicates   Find duplicate images
    --layer-analysis    Analyze image layers

${BOLD}EXAMPLES:${NC}
    # Show all images sorted by unique size
    $0 --sort unique

    # Top 10 largest images
    $0 --top 10

    # Generate usage report
    $0 --usage-report

    # Find duplicate images
    $0 --find-duplicates

${BOLD}OUTPUT COLUMNS:${NC}
    IDX         - Index number
    REPOSITORY  - Image repository name
    TAG         - Image tag
    IMAGE ID    - Short image ID
    SIZE        - Total image size
    UNIQUE      - Unique size (not shared with other images)
    CREATED AT  - Creation timestamp
    AGE(d)      - Age in days
    CONTAINERS  - Containers using this image
EOF
}

# ==============================================================================
# Advanced Image Analysis
# ==============================================================================

get_advanced_images_table() {
    (
        printf "%-5s %-25s %-15s %-20s %-12s %-12s %-25s %-7s %-40s\n" \
            "IDX" "REPOSITORY" "TAG" "IMAGE ID" "SIZE" "UNIQUE" "CREATED AT" "AGE(d)" "CONTAINERS"
        
        printf "%-5s %-25s %-15s %-20s %-12s %-12s %-25s %-7s %-40s\n" \
            "---" "-------------------------" "---------------" "--------------------" \
            "------------" "------------" "-------------------------" "-------" \
            "----------------------------------------"
        
        now_ts=$(date +%s)
        i=1
        
        # Collect unique sizes from docker_run system df
        declare -A uniq_sizes
        while IFS=' ' read -r repo tag imgid size shared unique containers; do
            # Handle parsing of docker_run system df output
            if [[ "$repo" != "REPOSITORY" ]]; then
                uniq_sizes[$imgid]=$unique
            fi
        done < <(docker_run system df -v --format "table {{.Repository}} {{.Tag}} {{.ID}} {{.Size}} {{.SharedSize}} {{.UniqueSize}} {{.Containers}}" 2>/dev/null || true)
        
        # Process images with sorting
        local sort_args=""
        case "$SORT_BY" in
            size)
                sort_args="-k5 -h -r"
                ;;
            unique)
                sort_args="-k6 -h -r"
                ;;
            age)
                sort_args="-k8 -n -r"
                ;;
            name)
                sort_args="-k1"
                ;;
            *)
                sort_args="-k5 -h -r"
                ;;
        esac
        
        docker_run images --format "{{.Repository}}|{{.Tag}}|{{.ID}}|{{.Size}}|{{.CreatedAt}}" \
        | while IFS='|' read -r repo tag imgid size created; do
            # Skip dangling images if not requested
            if [[ "$repo" == "<none>" ]] && [[ "$SHOW_DANGLING" != "true" ]]; then
                continue
            fi
            
            # Calculate age
            created_ts=$(date -d "$created" +%s 2>/dev/null || echo 0)
            age_days=$(( (now_ts - created_ts) / 86400 ))
            (( age_days < 0 )) && age_days=0
            
            # Get unique size
            unique="${uniq_sizes[$imgid]:-N/A}"
            
            # Find containers using this image
            containers=$(docker_run ps -a --filter "ancestor=$imgid" --format "{{.Names}}" 2>/dev/null | paste -sd, - || echo "")
            [[ -z "$containers" ]] && containers="(none)"
            
            # Truncate long strings
            [[ ${#repo} -gt 24 ]] && repo="${repo:0:22}.."
            [[ ${#tag} -gt 14 ]] && tag="${tag:0:12}.."
            [[ ${#containers} -gt 39 ]] && containers="${containers:0:37}.."
            
            echo "$repo|$tag|$imgid|$size|$unique|$created|$age_days|$containers"
        done | sort -t'|' $sort_args | while IFS='|' read -r repo tag imgid size unique created age_days containers; do
            # Apply top N filter if set
            if [[ $TOP_N -gt 0 ]] && [[ $i -gt $TOP_N ]]; then
                break
            fi
            
            printf "%-5s %-25s %-15s %-20s %-12s %-12s %-25s %-7s %-40s\n" \
                "$i" "$repo" "$tag" "$imgid" "$size" "$unique" "$created" "$age_days" "$containers"
            i=$((i+1))
        done
    )
}

# ==============================================================================
# Usage Report
# ==============================================================================

generate_usage_report() {
    echo -e "${BOLD}${CYAN}Docker Images Usage Report${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}\n"
    
    # Overall statistics
    local total_images=$(docker_run images -q | wc -l)
    local total_size=$(docker_run system df --format "{{.Size}}" | grep "Images" | awk '{print $1}')
    local reclaimable=$(docker_run system df --format "{{.Reclaimable}}" | grep "Images" | awk '{print $1}')
    
    echo -e "${BOLD}Overall Statistics:${NC}"
    echo -e "  Total Images:     ${BOLD}$total_images${NC}"
    echo -e "  Total Size:       ${BOLD}$total_size${NC}"
    echo -e "  Reclaimable:      ${YELLOW}$reclaimable${NC}"
    
    # Top consumers
    echo -e "\n${BOLD}Top 5 Space Consumers:${NC}"
    docker_run images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | head -6
    
    # Age analysis
    echo -e "\n${BOLD}Age Distribution:${NC}"
    local week_old=0
    local month_old=0
    local quarter_old=0
    local year_old=0
    
    now_ts=$(date +%s)
    while IFS=' ' read -r created; do
        created_ts=$(date -d "$created" +%s 2>/dev/null || echo 0)
        age_days=$(( (now_ts - created_ts) / 86400 ))
        
        if [[ $age_days -le 7 ]]; then
            ((week_old++))
        elif [[ $age_days -le 30 ]]; then
            ((month_old++))
        elif [[ $age_days -le 90 ]]; then
            ((quarter_old++))
        else
            ((year_old++))
        fi
    done < <(docker_run images --format "{{.CreatedAt}}")
    
    echo -e "  < 1 week:         ${GREEN}$week_old images${NC}"
    echo -e "  1 week - 1 month: ${CYAN}$month_old images${NC}"
    echo -e "  1-3 months:       ${YELLOW}$quarter_old images${NC}"
    echo -e "  > 3 months:       ${RED}$year_old images${NC}"
    
    # Dangling images
    local dangling_count=$(docker_run images -f "dangling=true" -q | wc -l)
    if [[ $dangling_count -gt 0 ]]; then
        echo -e "\n${YELLOW}⚠ Warning: $dangling_count dangling images found${NC}"
        echo -e "  Run 'docker_run image prune' to clean up"
    fi
    
    # Unused images
    echo -e "\n${BOLD}Image Usage:${NC}"
    local used_images=0
    local unused_images=0
    
    while read -r imgid; do
        local container_count=$(docker_run ps -a --filter "ancestor=$imgid" -q | wc -l)
        if [[ $container_count -gt 0 ]]; then
            ((used_images++))
        else
            ((unused_images++))
        fi
    done < <(docker_run images -q)
    
    echo -e "  In use:           ${GREEN}$used_images images${NC}"
    echo -e "  Not in use:       ${YELLOW}$unused_images images${NC}"
    
    # Recommendations
    echo -e "\n${BOLD}${CYAN}Recommendations:${NC}"
    
    if [[ $dangling_count -gt 0 ]]; then
        echo -e "  ${YELLOW}•${NC} Remove dangling images: docker_run image prune"
    fi
    
    if [[ $unused_images -gt 10 ]]; then
        echo -e "  ${YELLOW}•${NC} Consider removing unused images: docker_run image prune -a"
    fi
    
    if [[ $year_old -gt 5 ]]; then
        echo -e "  ${YELLOW}•${NC} Review and update old images (>3 months)"
    fi
    
    echo ""
}

# ==============================================================================
# Find Duplicate Images
# ==============================================================================

find_duplicate_images() {
    echo -e "${BOLD}${CYAN}Duplicate Images Analysis${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}\n"
    
    declare -A image_digests
    declare -A digest_images
    
    # Collect all images with their digests
    while IFS='|' read -r repo tag digest imgid; do
        if [[ "$repo" != "<none>" ]]; then
            image_key="${repo}:${tag}"
            if [[ -n "$digest" ]] && [[ "$digest" != "<none>" ]]; then
                image_digests[$image_key]=$digest
                
                if [[ -n "${digest_images[$digest]}" ]]; then
                    digest_images[$digest]="${digest_images[$digest]},$image_key"
                else
                    digest_images[$digest]=$image_key
                fi
            fi
        fi
    done < <(docker_run images --format "{{.Repository}}|{{.Tag}}|{{.Digest}}|{{.ID}}")
    
    # Find duplicates
    local duplicate_count=0
    local total_wasted=0
    
    echo -e "${BOLD}Duplicate Images (same digest, different tags):${NC}\n"
    
    for digest in "${!digest_images[@]}"; do
        IFS=',' read -ra images <<< "${digest_images[$digest]}"
        if [[ ${#images[@]} -gt 1 ]]; then
            ((duplicate_count++))
            echo -e "${YELLOW}Digest:${NC} ${digest:7:12}..."
            echo -e "${CYAN}Images:${NC}"
            for img in "${images[@]}"; do
                local size=$(docker_run images --format "{{.Repository}}:{{.Tag}}|{{.Size}}" | grep "^$img|" | cut -d'|' -f2)
                echo -e "  • $img (${size})"
            done
            echo ""
        fi
    done
    
    if [[ $duplicate_count -eq 0 ]]; then
        echo -e "${GREEN}✓ No duplicate images found${NC}"
    else
        echo -e "${YELLOW}Found $duplicate_count sets of duplicate images${NC}"
        echo -e "${CYAN}Tip:${NC} Consider using single tags or cleaning up old versions"
    fi
}

# ==============================================================================
# Layer Analysis
# ==============================================================================

analyze_layers() {
    local image="${1:-}"
    
    if [[ -z "$image" ]]; then
        echo -e "${RED}Error: Please specify an image for layer analysis${NC}"
        echo "Usage: $0 --layer-analysis IMAGE_NAME"
        exit 1
    fi
    
    echo -e "${BOLD}${CYAN}Layer Analysis for: $image${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}\n"
    
    # Get image history
    echo -e "${BOLD}Layer History:${NC}\n"
    docker history --no-trunc --format "table {{.ID}}\t{{.CreatedBy}}\t{{.Size}}" "$image"
    
    # Get total layers
    local total_layers=$(docker history -q "$image" | wc -l)
    echo -e "\n${BOLD}Statistics:${NC}"
    echo -e "  Total Layers:     $total_layers"
    
    # Calculate layer sizes
    local total_size=0
    local largest_layer=0
    local largest_cmd=""
    
    while IFS=$'\t' read -r id cmd size; do
        # Convert size to bytes for comparison
        size_bytes=$(echo "$size" | numfmt --from=iec 2>/dev/null || echo 0)
        total_size=$((total_size + size_bytes))
        
        if [[ $size_bytes -gt $largest_layer ]]; then
            largest_layer=$size_bytes
            largest_cmd="$cmd"
        fi
    done < <(docker history --no-trunc --format "{{.ID}}\t{{.CreatedBy}}\t{{.Size}}" "$image")
    
    echo -e "  Total Size:       $(numfmt --to=iec $total_size)"
    echo -e "  Largest Layer:    $(numfmt --to=iec $largest_layer)"
    echo -e "  Command:          ${DIM}${largest_cmd:0:50}...${NC}"
    
    # Check for optimization opportunities
    echo -e "\n${BOLD}${CYAN}Optimization Suggestions:${NC}"
    
    # Check for multiple RUN commands
    local run_count=$(docker history --no-trunc --format "{{.CreatedBy}}" "$image" | grep -c "^/bin/sh -c #(nop)  RUN" || true)
    if [[ $run_count -gt 5 ]]; then
        echo -e "  ${YELLOW}•${NC} Multiple RUN commands ($run_count) - consider combining to reduce layers"
    fi
    
    # Check for large layers
    if [[ $largest_layer -gt 104857600 ]]; then # 100MB
        echo -e "  ${YELLOW}•${NC} Large layer detected (>100MB) - consider multi-stage builds"
    fi
    
    # Check for apt/yum without cleanup
    if docker history --no-trunc "$image" | grep -q "apt-get install" && \
       ! docker history --no-trunc "$image" | grep -q "rm -rf /var/lib/apt/lists"; then
        echo -e "  ${YELLOW}•${NC} apt-get without cleanup - add 'rm -rf /var/lib/apt/lists/*'"
    fi
    
    echo ""
}

# ==============================================================================
# Main
# ==============================================================================

main() {
    local usage_report=false
    local find_dupes=false
    local layer_analysis=false
    local layer_image=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -s|--sort)
                SORT_BY="$2"
                shift 2
                ;;
            -t|--top)
                TOP_N="$2"
                shift 2
                ;;
            -d|--dangling)
                SHOW_DANGLING=true
                shift
                ;;
            --usage-report)
                usage_report=true
                shift
                ;;
            --find-duplicates)
                find_dupes=true
                shift
                ;;
            --layer-analysis)
                layer_analysis=true
                layer_image="${2:-}"
                shift
                [[ -n "$layer_image" ]] && shift
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Check Docker availability
    if ! command -v docker &>/dev/null; then
        echo -e "${RED}Error: Docker is not installed${NC}"
        exit 1
    fi
    
    if ! docker info &>/dev/null; then
        echo -e "${RED}Error: Docker daemon is not running${NC}"
        exit 1
    fi
    
    # Execute requested analysis
    if [[ "$usage_report" == "true" ]]; then
        generate_usage_report
    elif [[ "$find_dupes" == "true" ]]; then
        find_duplicate_images
    elif [[ "$layer_analysis" == "true" ]]; then
        analyze_layers "$layer_image"
    else
        # Default: show advanced images table
        echo -e "${BOLD}${CYAN}Advanced Docker Images Analysis${NC}"
        echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}\n"
        get_advanced_images_table
        
        # Summary
        echo -e "\n${BOLD}Summary:${NC}"
        local total_images=$(docker_run images -q | wc -l)
        local total_size=$(docker_run system df --format "{{.Size}}" | head -2 | tail -1)
        echo -e "  Total Images: ${BOLD}$total_images${NC}"
        echo -e "  Total Size:   ${BOLD}$total_size${NC}"
        
        if [[ $TOP_N -gt 0 ]]; then
            echo -e "  ${DIM}Showing top $TOP_N images by $SORT_BY${NC}"
        fi
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi