#!/bin/bash

set -e

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'


# Source Docker wrapper for sudo handling
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/docker-wrapper.sh"
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] [SEARCH_TERM]

Search and filter Docker volumes with advanced options.

Options:
    -n, --name PATTERN     Search by volume name
    -d, --driver DRIVER    Filter by driver (local, nfs, etc.)
    -l, --label LABEL      Filter by label
    --dangling             Show only dangling (unused) volumes
    --in-use               Show only volumes in use
    -c, --container NAME   Find volumes used by specific container
    --mount-point PATH     Search by mount point path
    -s, --size             Show volume sizes (requires inspection)
    --min-size SIZE        Filter volumes larger than SIZE
    --max-size SIZE        Filter volumes smaller than SIZE
    -f, --format FORMAT    Output format (json, table, names-only)
    --inspect NAME         Show detailed information about a volume
    -h, --help             Show this help message

Examples:
    $(basename "$0") data               # Search for volumes with 'data' in name
    $(basename "$0") -d local           # Show all local driver volumes
    $(basename "$0") --dangling         # Show unused volumes
    $(basename "$0") -c nginx           # Volumes used by nginx container
    $(basename "$0") --in-use           # Show all volumes in use
    $(basename "$0") --inspect myvolume # Detailed info about myvolume

EOF
}

get_volume_size() {
    local volume="$1"
    local mount_point=$(docker_run volume inspect "$volume" --format '{{.Mountpoint}}' 2>/dev/null)
    
    if [[ -n "$mount_point" ]] && [[ -d "$mount_point" ]]; then
        du -sh "$mount_point" 2>/dev/null | awk '{print $1}'
    else
        echo "N/A"
    fi
}

search_volumes() {
    local search_term="$1"
    local filters=""
    local format_opt="table {{.Name}}\t{{.Driver}}\t{{.Scope}}"
    
    if [[ -n "$FILTER_NAME" ]]; then
        filters="$filters --filter name=$FILTER_NAME"
    fi
    
    if [[ -n "$FILTER_DRIVER" ]]; then
        filters="$filters --filter driver=$FILTER_DRIVER"
    fi
    
    if [[ -n "$FILTER_LABEL" ]]; then
        filters="$filters --filter label=$FILTER_LABEL"
    fi
    
    if [[ "$SHOW_DANGLING" == "true" ]]; then
        filters="$filters --filter dangling=true"
    elif [[ "$SHOW_IN_USE" == "true" ]]; then
        filters="$filters --filter dangling=false"
    fi
    
    case "$OUTPUT_FORMAT" in
        json)
            format_opt="json"
            ;;
        names-only)
            format_opt="table {{.Name}}"
            ;;
    esac
    
    echo -e "${BLUE}🔍 Searching volumes...${NC}"
    
    if [[ -n "$search_term" ]] && [[ -z "$filters" ]]; then
        docker_run volume ls --format "$format_opt" | grep -i "$search_term" || {
            echo -e "${YELLOW}No volumes found matching '$search_term'${NC}"
            return 1
        }
    else
        docker_run volume ls $filters --format "$format_opt"
    fi
    
    if [[ "$SHOW_SIZE" == "true" ]]; then
        show_volume_sizes
    fi
}

show_volume_sizes() {
    echo -e "\n${BLUE}📊 Volume Sizes:${NC}"
    echo -e "VOLUME NAME\tSIZE"
    
    for volume in $(docker_run volume ls -q); do
        size=$(get_volume_size "$volume")
        echo -e "$volume\t$size"
    done | sort -k2 -hr
}

find_volumes_by_container() {
    local container="$1"
    echo -e "${BLUE}🔍 Volumes used by container '$container':${NC}"
    
    if ! docker_run ps -a --format "{{.Names}}" | grep -q "^$container$"; then
        echo -e "${RED}Container '$container' not found${NC}"
        return 1
    fi
    
    docker_run inspect "$container" --format '{{range .Mounts}}{{if .Name}}{{.Name}} ({{.Destination}}){{printf "\n"}}{{end}}{{end}}' || {
        echo -e "${YELLOW}No named volumes found for container '$container'${NC}"
        return 1
    }
}

find_volumes_by_mount_point() {
    local path="$1"
    echo -e "${BLUE}🔍 Volumes with mount point matching '$path':${NC}"
    
    for volume in $(docker_run volume ls -q); do
        mount_point=$(docker_run volume inspect "$volume" --format '{{.Mountpoint}}')
        if echo "$mount_point" | grep -q "$path"; then
            echo "  $volume: $mount_point"
        fi
    done
}

inspect_volume() {
    local volume="$1"
    echo -e "${BLUE}🔍 Inspecting volume '$volume':${NC}"
    
    if ! docker_run volume ls -q | grep -q "^$volume$"; then
        echo -e "${RED}Volume '$volume' not found${NC}"
        return 1
    fi
    
    docker_run volume inspect "$volume" | jq '.[0]' 2>/dev/null || docker_run volume inspect "$volume"
    
    echo -e "\n${BLUE}Containers using this volume:${NC}"
    for container in $(docker_run ps -aq); do
        if docker_run inspect "$container" --format '{{range .Mounts}}{{.Name}}{{end}}' | grep -q "^$volume$"; then
            name=$(docker_run inspect "$container" --format '{{.Name}}' | sed 's/\///')
            status=$(docker_run inspect "$container" --format '{{.State.Status}}')
            echo "  - $name ($status)"
        fi
    done
    
    if [[ "$SHOW_SIZE" == "true" ]]; then
        size=$(get_volume_size "$volume")
        echo -e "\n${BLUE}Volume size:${NC} $size"
    fi
}

analyze_volumes() {
    echo -e "${BLUE}📊 Volume Statistics:${NC}"
    
    local total=$(docker_run volume ls -q | wc -l)
    local dangling=$(docker_run volume ls -q --filter dangling=true | wc -l)
    local in_use=$((total - dangling))
    
    echo "  Total volumes: $total"
    echo "  In use: $in_use"
    echo "  Dangling: $dangling"
    echo ""
    
    echo -e "${BLUE}Volumes by driver:${NC}"
    docker_run volume ls --format "{{.Driver}}" | sort | uniq -c | sort -rn
    echo ""
    
    if [[ $dangling -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  You have $dangling dangling volume(s)${NC}"
        echo "Run 'docker_run volume prune' to clean them up"
    fi
}

cleanup_dangling_volumes() {
    echo -e "${BLUE}🧹 Cleaning up dangling volumes...${NC}"
    
    local dangling_count=$(docker_run volume ls -q --filter dangling=true | wc -l)
    
    if [[ $dangling_count -eq 0 ]]; then
        echo -e "${GREEN}No dangling volumes to clean${NC}"
        return 0
    fi
    
    echo "Found $dangling_count dangling volume(s)"
    read -p "Remove all dangling volumes? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker_run volume prune -f
        echo -e "${GREEN}✅ Dangling volumes removed${NC}"
    else
        echo "Cleanup cancelled"
    fi
}

FILTER_NAME=""
FILTER_DRIVER=""
FILTER_LABEL=""
SHOW_DANGLING=false
SHOW_IN_USE=false
FILTER_CONTAINER=""
MOUNT_POINT=""
SHOW_SIZE=false
MIN_SIZE=""
MAX_SIZE=""
OUTPUT_FORMAT="table"
INSPECT_VOLUME=""
CLEANUP_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            FILTER_NAME="$2"
            shift 2
            ;;
        -d|--driver)
            FILTER_DRIVER="$2"
            shift 2
            ;;
        -l|--label)
            FILTER_LABEL="$2"
            shift 2
            ;;
        --dangling)
            SHOW_DANGLING=true
            shift
            ;;
        --in-use)
            SHOW_IN_USE=true
            shift
            ;;
        -c|--container)
            FILTER_CONTAINER="$2"
            shift 2
            ;;
        --mount-point)
            MOUNT_POINT="$2"
            shift 2
            ;;
        -s|--size)
            SHOW_SIZE=true
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
        --inspect)
            INSPECT_VOLUME="$2"
            shift 2
            ;;
        --cleanup)
            CLEANUP_MODE=true
            shift
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

if [[ "$CLEANUP_MODE" == "true" ]]; then
    cleanup_dangling_volumes
elif [[ -n "$INSPECT_VOLUME" ]]; then
    inspect_volume "$INSPECT_VOLUME"
elif [[ -n "$FILTER_CONTAINER" ]]; then
    find_volumes_by_container "$FILTER_CONTAINER"
elif [[ -n "$MOUNT_POINT" ]]; then
    find_volumes_by_mount_point "$MOUNT_POINT"
elif [[ -n "$SEARCH_TERM" ]] || [[ -n "$FILTER_NAME" ]] || [[ -n "$FILTER_DRIVER" ]] || \
     [[ "$SHOW_DANGLING" == "true" ]] || [[ "$SHOW_IN_USE" == "true" ]]; then
    search_volumes "$SEARCH_TERM"
else
    analyze_volumes
fi