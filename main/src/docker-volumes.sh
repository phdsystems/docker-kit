#!/bin/bash

# ==============================================================================
# DockerKit - Docker Volumes Detailed Retrieval
# ==============================================================================
# Provides comprehensive information about Docker volumes including size,
# usage, dangling status, and associated containers
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
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
SHOW_HEADER=${SHOW_HEADER:-true}
OUTPUT_FORMAT=${OUTPUT_FORMAT:-table}  # Options: table, json, csv
SHOW_DANGLING=${SHOW_DANGLING:-all}  # Options: all, only, none

# ==============================================================================
# Functions
# ==============================================================================

show_help() {
    cat <<EOF
${BOLD}${CYAN}DockerKit - Docker Volumes Inspector${NC}

${BOLD}USAGE:${NC}
    $0 [OPTIONS]

${BOLD}OPTIONS:${NC}
    -h, --help          Show this help message
    -f, --format TYPE   Output format: table, json, csv (default: table)
    -d, --dangling      Show only dangling volumes
    -u, --used          Show only used volumes
    -n, --no-header     Suppress header in table output
    -c, --cleanup       Remove all dangling volumes (with confirmation)
    -i, --inspect NAME  Detailed inspection of specific volume

${BOLD}EXAMPLES:${NC}
    # Show all volumes with details
    $0

    # Show only dangling volumes
    $0 --dangling

    # Export as JSON
    $0 --format json > volumes.json

    # Inspect specific volume
    $0 --inspect my_volume

    # Clean up dangling volumes
    $0 --cleanup

${BOLD}OUTPUT COLUMNS:${NC}
    IDX         - Index number
    VOLUME NAME - Volume name
    DRIVER      - Volume driver
    SIZE        - Size on disk
    CREATED AT  - Creation timestamp
    DANGLING    - Whether volume is dangling
    AGE(d)      - Age in days
    CONTAINERS  - Containers using this volume
    IMAGES      - Images of containers using this volume
EOF
}

get_volumes_table() {
    (
        # Define column widths for safe truncation
        W_IDX=5; W_NAME=64; W_DRIVER=10; W_SIZE=8; W_CREATED=25; W_DANGLING=9; W_AGE=7; W_CONTAINERS=28; W_IMAGES=28
        
        # Truncation function
        trunc() { 
            local s="$1" w="$2"
            local el="…"
            [[ ${#s} -le $w ]] && printf "%s" "$s" || { printf "%.*s%s" $((w-1)) "$s" "$el"; }
        }
        
        if [[ "$SHOW_HEADER" == "true" ]]; then
            printf "%-${W_IDX}s %-${W_NAME}s %-${W_DRIVER}s %-${W_SIZE}s %-${W_CREATED}s %-${W_DANGLING}s %-${W_AGE}s %-${W_CONTAINERS}s %-${W_IMAGES}s\n" \
                "IDX" "VOLUME NAME" "DRIVER" "SIZE" "CREATED AT" "DANGLING" "AGE(d)" "CONTAINERS" "IMAGES"
        fi
        
        now_ts=$(date +%s)
        i=1
        
        docker_run volume ls --format "{{.Name}}\t{{.Driver}}" \
        | while IFS=$'\t' read -r name driver; do
            # Get volume details
            created_raw=$(docker_run volume inspect -f '{{.CreatedAt}}' "$name" 2>/dev/null)
            mp=$(docker_run volume inspect -f '{{.Mountpoint}}' "$name" 2>/dev/null)
            
            # Calculate size (may require sudo)
            size=$(du -sh "$mp" 2>/dev/null | awk '{print $1}')
            [[ -z "$size" ]] && size="N/A"
            
            # Calculate age
            created_ts=$(date -d "$created_raw" +%s 2>/dev/null || echo 0)
            age_days=$(( (now_ts - created_ts) / 86400 ))
            (( age_days < 0 )) && age_days=0
            
            # Find containers using this volume
            containers=$(docker_run ps -a --filter "volume=$name" --format "{{.Names}}" | paste -sd, -)
            [[ -z "$containers" ]] && containers="(none)"
            
            # Find images of containers using this volume
            images=$(docker_run ps -a --filter "volume=$name" --format "{{.Image}}" | sort -u | paste -sd, -)
            [[ -z "$images" ]] && images="(none)"
            
            # Determine if dangling
            [[ "$containers" == "(none)" ]] && dangling="yes" || dangling="no"
            
            # Apply filter if needed
            case "$SHOW_DANGLING" in
                only)
                    [[ "$dangling" != "yes" ]] && continue
                    ;;
                none)
                    [[ "$dangling" == "yes" ]] && continue
                    ;;
            esac
            
            printf "%-${W_IDX}s %-${W_NAME}s %-${W_DRIVER}s %-${W_SIZE}s %-${W_CREATED}s %-${W_DANGLING}s %-${W_AGE}s %-${W_CONTAINERS}s %-${W_IMAGES}s\n" \
                "$i" "$(trunc "$name" $W_NAME)" "$(trunc "$driver" $W_DRIVER)" "$(trunc "$size" $W_SIZE)" \
                "$(trunc "$created_raw" $W_CREATED)" "$(trunc "$dangling" $W_DANGLING)" "$age_days" \
                "$(trunc "$containers" $W_CONTAINERS)" "$(trunc "$images" $W_IMAGES)"
            i=$((i+1))
        done
    )
}

get_volumes_json() {
    echo "["
    local first=true
    now_ts=$(date +%s)
    
    docker_run volume ls --format "{{.Name}}" \
    | while read -r name; do
        [[ "$first" == "true" ]] && first=false || echo ","
        
        # Get volume details
        created=$(docker_run volume inspect -f '{{.CreatedAt}}' "$name" 2>/dev/null)
        driver=$(docker_run volume inspect -f '{{.Driver}}' "$name" 2>/dev/null)
        mountpoint=$(docker_run volume inspect -f '{{.Mountpoint}}' "$name" 2>/dev/null)
        scope=$(docker_run volume inspect -f '{{.Scope}}' "$name" 2>/dev/null)
        
        # Calculate size
        size_bytes=$(du -sb "$mountpoint" 2>/dev/null | awk '{print $1}' || echo 0)
        
        # Find containers
        containers=$(docker_run ps -a --filter "volume=$name" --format "{{.Names}}" | paste -sd, -)
        
        # Determine dangling
        dangling="false"
        [[ -z "$containers" ]] && dangling="true"
        
        cat <<EOF
  {
    "name": "$name",
    "driver": "$driver",
    "mountpoint": "$mountpoint",
    "scope": "$scope",
    "created": "$created",
    "size_bytes": $size_bytes,
    "dangling": $dangling,
    "containers": "$containers"
  }
EOF
    done
    echo "]"
}

get_volumes_csv() {
    echo "Name,Driver,Mountpoint,Size,Created,Dangling,Containers"
    
    docker_run volume ls --format "{{.Name}}" \
    | while read -r name; do
        driver=$(docker_run volume inspect -f '{{.Driver}}' "$name" 2>/dev/null)
        mountpoint=$(docker_run volume inspect -f '{{.Mountpoint}}' "$name" 2>/dev/null)
        created=$(docker_run volume inspect -f '{{.CreatedAt}}' "$name" 2>/dev/null)
        
        size=$(du -sh "$mountpoint" 2>/dev/null | awk '{print $1}' || echo "N/A")
        containers=$(docker_run ps -a --filter "volume=$name" --format "{{.Names}}" | paste -sd' ' -)
        
        dangling="no"
        [[ -z "$containers" ]] && dangling="yes" && containers="none"
        
        echo "$name,$driver,$mountpoint,$size,$created,$dangling,$containers"
    done
}

inspect_volume() {
    local volume="$1"
    
    if ! docker_run volume inspect "$volume" &>/dev/null; then
        echo -e "${RED}Error: Volume '$volume' not found${NC}"
        exit 1
    fi
    
    echo -e "${BOLD}${CYAN}Detailed Volume Inspection: $volume${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Basic info
    echo -e "\n${BOLD}Basic Information:${NC}"
    docker_run volume inspect "$volume" --format '
Name:        {{.Name}}
Driver:      {{.Driver}}
Mountpoint:  {{.Mountpoint}}
Created:     {{.CreatedAt}}
Scope:       {{.Scope}}'
    
    # Size information
    echo -e "\n${BOLD}Size Information:${NC}"
    mountpoint=$(docker_run volume inspect -f '{{.Mountpoint}}' "$volume")
    if [[ -d "$mountpoint" ]]; then
        size=$(du -sh "$mountpoint" 2>/dev/null | awk '{print $1}' || echo "N/A")
        files=$(find "$mountpoint" -type f 2>/dev/null | wc -l || echo "N/A")
        dirs=$(find "$mountpoint" -type d 2>/dev/null | wc -l || echo "N/A")
        echo "Total Size:  $size"
        echo "Files:       $files"
        echo "Directories: $dirs"
    else
        echo "Unable to access mountpoint"
    fi
    
    # Usage information
    echo -e "\n${BOLD}Usage Information:${NC}"
    containers=$(docker_run ps -a --filter "volume=$volume" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}")
    if [[ -n "$containers" ]]; then
        echo "$containers"
    else
        echo "No containers are using this volume (dangling)"
    fi
    
    # Labels
    echo -e "\n${BOLD}Labels:${NC}"
    labels=$(docker_run volume inspect -f '{{range $k, $v := .Labels}}{{$k}}={{$v}}
{{end}}' "$volume" 2>/dev/null)
    [[ -z "$labels" ]] && labels="(none)"
    echo "$labels"
    
    # Options
    echo -e "\n${BOLD}Options:${NC}"
    options=$(docker_run volume inspect -f '{{range $k, $v := .Options}}{{$k}}={{$v}}
{{end}}' "$volume" 2>/dev/null)
    [[ -z "$options" ]] && options="(none)"
    echo "$options"
}

cleanup_dangling_volumes() {
    echo -e "${YELLOW}Finding dangling volumes...${NC}"
    
    local dangling_volumes=$(docker_run volume ls -qf dangling=true)
    
    if [[ -z "$dangling_volumes" ]]; then
        echo -e "${GREEN}No dangling volumes found${NC}"
        return 0
    fi
    
    echo -e "${BOLD}Dangling volumes found:${NC}"
    docker_run volume ls -f dangling=true
    
    echo -e "\n${YELLOW}WARNING: This will permanently delete these volumes and their data!${NC}"
    read -p "Are you sure you want to remove all dangling volumes? (yes/no): " confirm
    
    if [[ "$confirm" == "yes" ]]; then
        echo -e "${CYAN}Removing dangling volumes...${NC}"
        docker_run volume prune -f
        echo -e "${GREEN}Dangling volumes removed${NC}"
    else
        echo -e "${BLUE}Cleanup cancelled${NC}"
    fi
}

# ==============================================================================
# Main
# ==============================================================================

main() {
    local inspect_name=""
    local cleanup_mode=false
    
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
            -d|--dangling)
                SHOW_DANGLING="only"
                shift
                ;;
            -u|--used)
                SHOW_DANGLING="none"
                shift
                ;;
            -n|--no-header)
                SHOW_HEADER=false
                shift
                ;;
            -c|--cleanup)
                cleanup_mode=true
                shift
                ;;
            -i|--inspect)
                inspect_name="$2"
                shift 2
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
    if ! docker_run info &> /dev/null; then
        echo -e "${RED}Error: Docker daemon is not running${NC}"
        exit 1
    fi
    
    # Handle special modes
    if [[ "$cleanup_mode" == "true" ]]; then
        cleanup_dangling_volumes
        exit 0
    fi
    
    if [[ -n "$inspect_name" ]]; then
        inspect_volume "$inspect_name"
        exit 0
    fi
    
    # Output based on format
    case "$OUTPUT_FORMAT" in
        json)
            get_volumes_json
            ;;
        csv)
            get_volumes_csv
            ;;
        table|*)
            get_volumes_table
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi