#!/bin/bash

set -e

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'


# Source Docker wrapper for sudo handling
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/docker-wrapper.sh"
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] [SEARCH_TERM]

Search and filter Docker images with advanced options.

Options:
    -n, --name PATTERN      Search by image name/repository
    -t, --tag TAG          Filter by specific tag
    -l, --label LABEL      Filter by label
    -d, --dangling         Show only dangling images
    --before IMAGE         Show images created before specified image
    --since IMAGE          Show images created after specified image
    -s, --size             Sort by size
    --min-size SIZE        Show images larger than SIZE (e.g., 100MB, 1GB)
    --max-size SIZE        Show images smaller than SIZE
    -f, --format FORMAT    Output format (json, table, id-only)
    -r, --registry REG     Search in Docker Hub registry
    -h, --help             Show this help message

Examples:
    $(basename "$0") nginx              # Search for nginx images
    $(basename "$0") -n "ubuntu:*"      # Search Ubuntu images with any tag
    $(basename "$0") -t latest          # Find all images with 'latest' tag
    $(basename "$0") --min-size 500MB   # Images larger than 500MB
    $(basename "$0") -d                 # Show dangling images
    $(basename "$0") -r nginx           # Search Docker Hub for nginx

EOF
}

convert_size_to_bytes() {
    local size=$1
    local number=${size//[^0-9.]/}
    local unit=${size//[0-9.]/}
    
    case ${unit^^} in
        KB) echo $(bc <<< "$number * 1024") ;;
        MB) echo $(bc <<< "$number * 1024 * 1024") ;;
        GB) echo $(bc <<< "$number * 1024 * 1024 * 1024") ;;
        *) echo "$number" ;;
    esac
}

search_local_images() {
    local search_term="$1"
    local filters=""
    local format_opt="table {{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.CreatedSince}}\t{{.Size}}"
    
    if [[ -n "$FILTER_NAME" ]]; then
        filters="$filters --filter reference=$FILTER_NAME"
    fi
    
    if [[ -n "$FILTER_TAG" ]]; then
        filters="$filters --filter reference=*:$FILTER_TAG"
    fi
    
    if [[ -n "$FILTER_LABEL" ]]; then
        filters="$filters --filter label=$FILTER_LABEL"
    fi
    
    if [[ "$SHOW_DANGLING" == "true" ]]; then
        filters="$filters --filter dangling=true"
    fi
    
    if [[ -n "$BEFORE_IMAGE" ]]; then
        filters="$filters --filter before=$BEFORE_IMAGE"
    fi
    
    if [[ -n "$SINCE_IMAGE" ]]; then
        filters="$filters --filter since=$SINCE_IMAGE"
    fi
    
    case "$OUTPUT_FORMAT" in
        json)
            format_opt="json"
            ;;
        id-only)
            format_opt="table {{.ID}}"
            ;;
    esac
    
    echo -e "${BLUE}🔍 Searching local images...${NC}"
    
    if [[ -n "$search_term" ]] && [[ -z "$filters" ]]; then
        docker_run images --format "$format_opt" | grep -i "$search_term" || {
            echo -e "${YELLOW}No images found matching '$search_term'${NC}"
            return 1
        }
    else
        docker_run images $filters --format "$format_opt"
    fi
    
    if [[ -n "$MIN_SIZE" ]] || [[ -n "$MAX_SIZE" ]]; then
        filter_by_size
    fi
    
    if [[ "$SORT_BY_SIZE" == "true" ]]; then
        sort_images_by_size
    fi
}

filter_by_size() {
    echo -e "${BLUE}Filtering by size...${NC}"
    
    local min_bytes=0
    local max_bytes=999999999999
    
    if [[ -n "$MIN_SIZE" ]]; then
        min_bytes=$(convert_size_to_bytes "$MIN_SIZE")
    fi
    
    if [[ -n "$MAX_SIZE" ]]; then
        max_bytes=$(convert_size_to_bytes "$MAX_SIZE")
    fi
    
    docker_run images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | \
    while read -r line; do
        if [[ "$line" == *"REPOSITORY"* ]]; then
            echo "$line"
            continue
        fi
        
        size_str=$(echo "$line" | awk '{print $NF}')
        size_bytes=$(convert_size_to_bytes "$size_str")
        
        if (( size_bytes >= min_bytes && size_bytes <= max_bytes )); then
            echo "$line"
        fi
    done
}

sort_images_by_size() {
    echo -e "${BLUE}Sorting by size...${NC}"
    docker_run images --format "table {{.Size}}\t{{.Repository}}:{{.Tag}}\t{{.ID}}" | \
        (read -r header; echo "$header"; sort -h)
}

search_registry() {
    local search_term="$1"
    
    if [[ -z "$search_term" ]]; then
        echo -e "${RED}Error: Search term required for registry search${NC}"
        return 1
    fi
    
    echo -e "${BLUE}🔍 Searching Docker Hub for '$search_term'...${NC}"
    
    docker_run search "$search_term" --limit 10 --format "table {{.Name}}\t{{.Description}}\t{{.Stars}}\t{{.Official}}" || {
        echo -e "${RED}Failed to search Docker Hub${NC}"
        return 1
    }
}

analyze_images() {
    echo -e "${BLUE}📊 Image Statistics:${NC}"
    
    local total_images=$(docker_run images -q | wc -l)
    local total_size=$(docker_run images --format "{{.Size}}" | \
        sed 's/MB/*1024*1024/g; s/GB/*1024*1024*1024/g; s/KB/*1024/g' | \
        paste -sd+ | bc 2>/dev/null || echo "0")
    
    local dangling=$(docker_run images -f dangling=true -q | wc -l)
    
    echo "  Total images: $total_images"
    echo "  Dangling images: $dangling"
    
    if [[ "$total_size" -gt 0 ]]; then
        local size_mb=$((total_size / 1024 / 1024))
        echo "  Approximate total size: ${size_mb}MB"
    fi
    
    echo ""
    echo -e "${BLUE}Top 5 largest images:${NC}"
    docker_run images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | \
        (read -r header; echo "$header"; sort -k2 -hr) | head -6
}

FILTER_NAME=""
FILTER_TAG=""
FILTER_LABEL=""
SHOW_DANGLING=false
BEFORE_IMAGE=""
SINCE_IMAGE=""
SORT_BY_SIZE=false
MIN_SIZE=""
MAX_SIZE=""
OUTPUT_FORMAT="table"
SEARCH_REGISTRY=false
REGISTRY_TERM=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            FILTER_NAME="$2"
            shift 2
            ;;
        -t|--tag)
            FILTER_TAG="$2"
            shift 2
            ;;
        -l|--label)
            FILTER_LABEL="$2"
            shift 2
            ;;
        -d|--dangling)
            SHOW_DANGLING=true
            shift
            ;;
        --before)
            BEFORE_IMAGE="$2"
            shift 2
            ;;
        --since)
            SINCE_IMAGE="$2"
            shift 2
            ;;
        -s|--size)
            SORT_BY_SIZE=true
            shift
            ;;
        --min-size)
            MIN_SIZE="$2"
            shift 2
            ;;
        --max-size)
            MAX_SIZE="$2"
            shift 2
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -r|--registry)
            SEARCH_REGISTRY=true
            REGISTRY_TERM="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            SEARCH_TERM="$1"
            shift
            ;;
    esac
done

if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

if [[ "$SEARCH_REGISTRY" == "true" ]]; then
    search_registry "${REGISTRY_TERM:-$SEARCH_TERM}"
elif [[ -n "$SEARCH_TERM" ]] || [[ -n "$FILTER_NAME" ]] || [[ -n "$FILTER_TAG" ]] || \
     [[ "$SHOW_DANGLING" == "true" ]] || [[ -n "$MIN_SIZE" ]] || [[ -n "$MAX_SIZE" ]]; then
    search_local_images "$SEARCH_TERM"
else
    analyze_images
fi