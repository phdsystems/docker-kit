#!/bin/bash

# ==============================================================================
# DockerKit - Docker Images Detailed Retrieval
# ==============================================================================
# Provides comprehensive information about Docker images including size,
# unique allocation, age, and associated containers
# ==============================================================================

set -euo pipefail

# Source Docker wrapper for sudo handling
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/docker-wrapper.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
SHOW_HEADER=${SHOW_HEADER:-true}
SORT_BY=${SORT_BY:-size}  # Options: size, age, name
OUTPUT_FORMAT=${OUTPUT_FORMAT:-table}  # Options: table, json, csv

# ==============================================================================
# Functions
# ==============================================================================

show_help() {
    cat <<EOF
${BOLD}${CYAN}DockerKit - Docker Images Inspector${NC}

${BOLD}USAGE:${NC}
    $0 [OPTIONS]

${BOLD}OPTIONS:${NC}
    -h, --help          Show this help message
    -s, --sort TYPE     Sort by: size, age, name, repo (default: size)
    -f, --format TYPE   Output format: table, json, csv (default: table)
    -n, --no-header     Suppress header in table output
    -d, --dangling      Show only dangling images
    -a, --all           Show all images including intermediate layers
    -q, --quiet         Only show image IDs

${BOLD}EXAMPLES:${NC}
    # Show all images sorted by size
    $0

    # Show images sorted by age
    $0 --sort age

    # Export as JSON
    $0 --format json > images.json

    # Show only dangling images
    $0 --dangling

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

get_images_table() {
    (
        if [[ "$SHOW_HEADER" == "true" ]]; then
            printf "%-5s %-25s %-15s %-20s %-12s %-12s %-25s %-7s %-40s\n" \
                "IDX" "REPOSITORY" "TAG" "IMAGE ID" "SIZE" "UNIQUE" "CREATED AT" "AGE(d)" "CONTAINERS"
        fi
        
        now_ts=$(date +%s)
        i=1
        
        # Get unique sizes from docker_run system df
        declare -A uniq_sizes
        while read -r repo tag imgid size shared unique containers; do
            uniq_sizes[$imgid]=$unique
        done < <(docker_run system df -v --format "{{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}\t{{.SharedSize}}\t{{.UniqueSize}}\t{{.Containers}}" 2>/dev/null || true)
        
        # Get images and process
        local sort_option=""
        case "$SORT_BY" in
            size)
                sort_option="-k4 -h -r"
                ;;
            age)
                sort_option="-k5 -r"
                ;;
            name|repo)
                sort_option="-k1"
                ;;
            *)
                sort_option="-k4 -h -r"
                ;;
        esac
        
        docker_run images --format "{{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}\t{{.CreatedAt}}" \
        | sort $sort_option \
        | while IFS=$'\t' read -r repo tag imgid size created; do
            created_ts=$(date -d "$created" +%s 2>/dev/null || echo 0)
            age_days=$(( (now_ts - created_ts) / 86400 ))
            
            unique="${uniq_sizes[$imgid]:-}"
            [[ -z "$unique" ]] && unique="?"
            
            containers=$(docker_run ps -a --filter "ancestor=$imgid" --format "{{.Names}}" | paste -sd, -)
            [[ -z "$containers" ]] && containers="(none)"
            
            printf "%-5s %-25s %-15s %-20s %-12s %-12s %-25s %-7s %-40s\n" \
                "$i" "$repo" "$tag" "$imgid" "$size" "$unique" "$created" "$age_days" "$containers"
            i=$((i+1))
        done
    )
}

get_images_json() {
    echo "["
    local first=true
    now_ts=$(date +%s)
    
    # Get unique sizes
    declare -A uniq_sizes
    while read -r repo tag imgid size shared unique containers; do
        uniq_sizes[$imgid]=$unique
    done < <(docker_run system df -v --format "{{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}\t{{.SharedSize}}\t{{.UniqueSize}}\t{{.Containers}}" 2>/dev/null || true)
    
    docker_run images --format "{{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}\t{{.CreatedAt}}" \
    | while IFS=$'\t' read -r repo tag imgid size created; do
        created_ts=$(date -d "$created" +%s 2>/dev/null || echo 0)
        age_days=$(( (now_ts - created_ts) / 86400 ))
        
        unique="${uniq_sizes[$imgid]:-?}"
        
        containers=$(docker_run ps -a --filter "ancestor=$imgid" --format "{{.Names}}" | paste -sd, -)
        [[ -z "$containers" ]] && containers=""
        
        [[ "$first" == "true" ]] && first=false || echo ","
        
        cat <<EOF
  {
    "repository": "$repo",
    "tag": "$tag",
    "image_id": "$imgid",
    "size": "$size",
    "unique_size": "$unique",
    "created": "$created",
    "age_days": $age_days,
    "containers": "$containers"
  }
EOF
    done
    echo "]"
}

get_images_csv() {
    echo "Repository,Tag,ImageID,Size,UniqueSize,Created,AgeDays,Containers"
    now_ts=$(date +%s)
    
    # Get unique sizes
    declare -A uniq_sizes
    while read -r repo tag imgid size shared unique containers; do
        uniq_sizes[$imgid]=$unique
    done < <(docker_run system df -v --format "{{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}\t{{.SharedSize}}\t{{.UniqueSize}}\t{{.Containers}}" 2>/dev/null || true)
    
    docker_run images --format "{{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}\t{{.CreatedAt}}" \
    | while IFS=$'\t' read -r repo tag imgid size created; do
        created_ts=$(date -d "$created" +%s 2>/dev/null || echo 0)
        age_days=$(( (now_ts - created_ts) / 86400 ))
        
        unique="${uniq_sizes[$imgid]:-?}"
        
        containers=$(docker_run ps -a --filter "ancestor=$imgid" --format "{{.Names}}" | paste -sd' ' -)
        [[ -z "$containers" ]] && containers="none"
        
        echo "$repo,$tag,$imgid,$size,$unique,$created,$age_days,$containers"
    done
}

get_dangling_images() {
    echo -e "${YELLOW}Dangling Images:${NC}"
    docker_run images -f "dangling=true" --format "table {{.ID}}\t{{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}"
}

# ==============================================================================
# Main
# ==============================================================================

main() {
    local show_dangling=false
    local show_all=false
    local quiet_mode=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -s|--sort)
                SORT_BY="$2"
                shift 2
                ;;
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -n|--no-header)
                SHOW_HEADER=false
                shift
                ;;
            -d|--dangling)
                show_dangling=true
                shift
                ;;
            -a|--all)
                show_all=true
                shift
                ;;
            -q|--quiet)
                quiet_mode=true
                shift
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Error: Docker is not installed or not in PATH${NC}"
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        echo -e "${RED}Error: Docker daemon is not running${NC}"
        exit 1
    fi
    
    # Handle special modes
    if [[ "$quiet_mode" == "true" ]]; then
        docker_run images -q
        exit 0
    fi
    
    if [[ "$show_dangling" == "true" ]]; then
        get_dangling_images
        exit 0
    fi
    
    # Output based on format
    case "$OUTPUT_FORMAT" in
        json)
            get_images_json
            ;;
        csv)
            get_images_csv
            ;;
        table|*)
            get_images_table
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi