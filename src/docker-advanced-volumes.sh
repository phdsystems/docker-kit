#!/bin/bash

# ==============================================================================
# DockerKit - Advanced Docker Volumes Analysis
# ==============================================================================
# Enhanced volume analysis with size tracking, usage patterns, and optimization
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
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# Configuration
OUTPUT_FORMAT="${OUTPUT_FORMAT:-table}"
SHOW_DANGLING="${SHOW_DANGLING:-all}" # Options: all, only, none
SORT_BY="${SORT_BY:-name}" # Options: name, size, age, usage
TOP_N="${TOP_N:-0}" # Show top N volumes (0 = all)

# ==============================================================================
# Helper Functions
# ==============================================================================

show_help() {
    cat <<EOF
${BOLD}${CYAN}DockerKit - Advanced Volume Analysis${NC}

${BOLD}USAGE:${NC}
    $0 [OPTIONS]

${BOLD}OPTIONS:${NC}
    -h, --help          Show this help message
    -f, --format TYPE   Output format: table, json, csv, wide (default: table)
    -s, --sort FIELD    Sort by: name, size, age, usage (default: name)
    -t, --top N         Show top N volumes by size
    -d, --dangling      Show only dangling volumes
    -u, --used          Show only used volumes
    --size-report       Detailed size analysis report
    --usage-map         Volume usage mapping
    --backup-list       List volumes for backup consideration
    --cleanup-suggest   Suggest volumes for cleanup

${BOLD}EXAMPLES:${NC}
    # Show all volumes with details
    $0

    # Top 10 volumes by size
    $0 --top 10 --sort size

    # Dangling volumes only
    $0 --dangling

    # Size analysis report
    $0 --size-report

    # Usage mapping
    $0 --usage-map

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

# Truncation function for safe column display
trunc() { 
    local s="$1" w="$2"
    local el="…"
    [[ ${#s} -le $w ]] && printf "%s" "$s" || { printf "%.*s%s" $((w-1)) "$s" "$el"; }
}

# ==============================================================================
# Advanced Volume Analysis
# ==============================================================================

get_advanced_volumes_table() {
    (
        # Define column widths for safe truncation
        W_IDX=5; W_NAME=64; W_DRIVER=10; W_SIZE=8; W_CREATED=25; W_DANGLING=9; W_AGE=7; W_CONTAINERS=28; W_IMAGES=28
        
        # Print header
        printf "%-${W_IDX}s %-${W_NAME}s %-${W_DRIVER}s %-${W_SIZE}s %-${W_CREATED}s %-${W_DANGLING}s %-${W_AGE}s %-${W_CONTAINERS}s %-${W_IMAGES}s\n" \
            "IDX" "VOLUME NAME" "DRIVER" "SIZE" "CREATED AT" "DANGLING" "AGE(d)" "CONTAINERS" "IMAGES"
        
        printf "%-${W_IDX}s %-${W_NAME}s %-${W_DRIVER}s %-${W_SIZE}s %-${W_CREATED}s %-${W_DANGLING}s %-${W_AGE}s %-${W_CONTAINERS}s %-${W_IMAGES}s\n" \
            "-----" "$(printf '%.0s-' {1..64})" "----------" "--------" \
            "-------------------------" "---------" "-------" \
            "----------------------------" "----------------------------"
        
        now_ts=$(date +%s)
        i=1
        
        # Collect volume data for sorting
        local temp_file=$(mktemp)
        
        docker_run volume ls --format "{{.Name}}|{{.Driver}}" \
        | while IFS='|' read -r name driver; do
            # Get volume details
            created_raw=$(docker_run volume inspect -f '{{.CreatedAt}}' "$name" 2>/dev/null)
            mp=$(docker_run volume inspect -f '{{.Mountpoint}}' "$name" 2>/dev/null)
            
            # Calculate size (may require sudo)
            size_bytes=0
            size="0B"
            if [[ -d "$mp" ]]; then
                size=$(du -sh "$mp" 2>/dev/null | awk '{print $1}')
                size_bytes=$(du -sb "$mp" 2>/dev/null | awk '{print $1}' || echo 0)
            fi
            [[ -z "$size" ]] && size="0B"
            
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
            
            # Save to temp file for sorting
            echo "$size_bytes|$age_days|$name|$driver|$size|$created_raw|$dangling|$containers|$images" >> "$temp_file"
        done
        
        # Sort based on criteria
        case "$SORT_BY" in
            size)
                sort_cmd="sort -t'|' -k1 -rn"
                ;;
            age)
                sort_cmd="sort -t'|' -k2 -rn"
                ;;
            name)
                sort_cmd="sort -t'|' -k3"
                ;;
            *)
                sort_cmd="cat"
                ;;
        esac
        
        # Process and display sorted data
        eval "$sort_cmd $temp_file" | while IFS='|' read -r size_bytes age_days name driver size created_raw dangling containers images; do
            # Apply top N filter if set
            if [[ $TOP_N -gt 0 ]] && [[ $i -gt $TOP_N ]]; then
                break
            fi
            
            printf "%-${W_IDX}s %-${W_NAME}s %-${W_DRIVER}s %-${W_SIZE}s %-${W_CREATED}s %-${W_DANGLING}s %-${W_AGE}s %-${W_CONTAINERS}s %-${W_IMAGES}s\n" \
                "$i" "$(trunc "$name" $W_NAME)" "$(trunc "$driver" $W_DRIVER)" "$(trunc "$size" $W_SIZE)" \
                "$(trunc "$created_raw" $W_CREATED)" "$(trunc "$dangling" $W_DANGLING)" "$age_days" \
                "$(trunc "$containers" $W_CONTAINERS)" "$(trunc "$images" $W_IMAGES)"
            
            i=$((i+1))
        done
        
        rm -f "$temp_file"
    )
}

# ==============================================================================
# Size Report
# ==============================================================================

volume_size_report() {
    echo -e "${BOLD}${CYAN}Volume Size Analysis Report${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}\n"
    
    local total_size=0
    local total_volumes=0
    local dangling_size=0
    local dangling_count=0
    local used_size=0
    local used_count=0
    
    echo -e "${BOLD}Volume Size Breakdown:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    
    printf "${BOLD}%-40s %-15s %-10s %-15s${NC}\n" \
        "VOLUME" "SIZE" "STATUS" "CONTAINERS"
    
    # Collect size data
    docker_run volume ls --format "{{.Name}}" | while read -r name; do
        mp=$(docker_run volume inspect -f '{{.Mountpoint}}' "$name" 2>/dev/null)
        
        # Get size
        size_bytes=0
        size="0B"
        if [[ -d "$mp" ]]; then
            size=$(du -sh "$mp" 2>/dev/null | awk '{print $1}')
            size_bytes=$(du -sb "$mp" 2>/dev/null | awk '{print $1}' || echo 0)
        fi
        
        # Check usage
        containers=$(docker_run ps -a --filter "volume=$name" --format "{{.Names}}" | paste -sd, -)
        
        if [[ -z "$containers" ]]; then
            status="${YELLOW}Dangling${NC}"
            containers="(none)"
            dangling_size=$((dangling_size + size_bytes))
            ((dangling_count++))
        else
            status="${GREEN}In Use${NC}"
            used_size=$((used_size + size_bytes))
            ((used_count++))
        fi
        
        total_size=$((total_size + size_bytes))
        ((total_volumes++))
        
        # Truncate long names
        [[ ${#name} -gt 39 ]] && name="${name:0:37}.."
        [[ ${#containers} -gt 14 ]] && containers="${containers:0:12}.."
        
        printf "%-40s %-15s " "$name" "$size"
        echo -e "$status %-15s" "$containers"
    done
    
    # Summary statistics
    echo -e "\n${BOLD}Summary Statistics:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    
    echo -e "  Total Volumes:       ${BOLD}$total_volumes${NC}"
    echo -e "  Total Size:          ${BOLD}$(numfmt --to=iec-i --suffix=B $total_size 2>/dev/null || echo "$total_size B")${NC}"
    echo ""
    echo -e "  Used Volumes:        ${GREEN}$used_count${NC} ($(numfmt --to=iec-i --suffix=B $used_size 2>/dev/null || echo "$used_size B"))"
    echo -e "  Dangling Volumes:    ${YELLOW}$dangling_count${NC} ($(numfmt --to=iec-i --suffix=B $dangling_size 2>/dev/null || echo "$dangling_size B"))"
    
    # Space reclamation potential
    if [[ $dangling_count -gt 0 ]]; then
        echo -e "\n${BOLD}${YELLOW}Space Reclamation Potential:${NC}"
        echo -e "  Removing dangling volumes would free: ${YELLOW}$(numfmt --to=iec-i --suffix=B $dangling_size 2>/dev/null)${NC}"
    fi
    
    # Top space consumers
    echo -e "\n${BOLD}Top 5 Space Consumers:${NC}"
    docker_run volume ls --format "{{.Name}}" | while read -r name; do
        mp=$(docker_run volume inspect -f '{{.Mountpoint}}' "$name" 2>/dev/null)
        size_bytes=$(du -sb "$mp" 2>/dev/null | awk '{print $1}' || echo 0)
        echo "$size_bytes|$name"
    done | sort -rn | head -5 | while IFS='|' read -r size name; do
        hsize=$(numfmt --to=iec-i --suffix=B $size 2>/dev/null || echo "$size B")
        echo -e "  • $name: ${CYAN}$hsize${NC}"
    done
}

# ==============================================================================
# Usage Mapping
# ==============================================================================

volume_usage_map() {
    echo -e "${BOLD}${CYAN}Volume Usage Mapping${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}\n"
    
    # Volumes by container
    echo -e "${BOLD}Volumes by Container:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    
    docker_run ps -a --format "{{.Names}}" | while read -r container; do
        echo -e "\n${BOLD}${GREEN}$container:${NC}"
        
        # Get container status
        status=$(docker_run inspect -f '{{.State.Status}}' "$container" 2>/dev/null)
        echo -e "  Status: $status"
        
        # Get volumes
        docker_run inspect "$container" -f '{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}}|{{.Destination}}|{{.RW}}{{println}}{{end}}{{end}}' \
        | while IFS='|' read -r vol dest rw; do
            [[ -z "$vol" ]] && continue
            
            # Get volume size
            mp=$(docker_run volume inspect -f '{{.Mountpoint}}' "$vol" 2>/dev/null)
            size=$(du -sh "$mp" 2>/dev/null | awk '{print $1}' || echo "0B")
            
            access="ro"
            [[ "$rw" == "true" ]] && access="rw"
            
            echo -e "  ${CYAN}$vol${NC}"
            echo -e "    Mount: $dest ($access)"
            echo -e "    Size:  $size"
        done
    done
    
    # Shared volumes
    echo -e "\n${BOLD}Shared Volumes:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    
    declare -A volume_containers
    
    # Build volume usage map
    docker_run ps -a -q | while read -r cid; do
        cname=$(docker_run inspect -f '{{.Name}}' "$cid" | sed 's/^\///')
        docker_run inspect "$cid" -f '{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}}{{println}}{{end}}{{end}}' \
        | while read -r vol; do
            [[ -z "$vol" ]] && continue
            
            if [[ -n "${volume_containers[$vol]}" ]]; then
                volume_containers[$vol]="${volume_containers[$vol]},$cname"
            else
                volume_containers[$vol]="$cname"
            fi
        done
    done
    
    local shared_found=false
    for vol in "${!volume_containers[@]}"; do
        IFS=',' read -ra containers <<< "${volume_containers[$vol]}"
        if [[ ${#containers[@]} -gt 1 ]]; then
            shared_found=true
            
            # Get volume size
            mp=$(docker_run volume inspect -f '{{.Mountpoint}}' "$vol" 2>/dev/null)
            size=$(du -sh "$mp" 2>/dev/null | awk '{print $1}' || echo "0B")
            
            echo -e "\n  ${CYAN}$vol${NC} (Size: $size)"
            echo -e "  Shared by ${#containers[@]} containers:"
            for container in "${containers[@]}"; do
                echo -e "    • $container"
            done
        fi
    done
    
    if [[ "$shared_found" != "true" ]]; then
        echo -e "  ${DIM}No shared volumes found${NC}"
    fi
    
    # Orphaned volumes
    echo -e "\n${BOLD}Orphaned Volumes:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    
    local orphan_count=0
    docker_run volume ls --format "{{.Name}}" | while read -r vol; do
        containers=$(docker_run ps -a --filter "volume=$vol" -q | wc -l)
        if [[ $containers -eq 0 ]]; then
            ((orphan_count++))
            
            # Get volume info
            created=$(docker_run volume inspect -f '{{.CreatedAt}}' "$vol" 2>/dev/null)
            mp=$(docker_run volume inspect -f '{{.Mountpoint}}' "$vol" 2>/dev/null)
            size=$(du -sh "$mp" 2>/dev/null | awk '{print $1}' || echo "0B")
            
            echo -e "  ${YELLOW}$vol${NC}"
            echo -e "    Size:    $size"
            echo -e "    Created: $created"
        fi
    done
    
    if [[ $orphan_count -eq 0 ]]; then
        echo -e "  ${GREEN}✓ No orphaned volumes${NC}"
    else
        echo -e "\n  ${YELLOW}⚠ $orphan_count orphaned volumes found${NC}"
    fi
}

# ==============================================================================
# Backup List
# ==============================================================================

generate_backup_list() {
    echo -e "${BOLD}${CYAN}Volume Backup Recommendations${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}\n"
    
    echo -e "${BOLD}Volumes Recommended for Backup:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}\n"
    
    # Find volumes with important-looking names
    local important_patterns="data|db|database|mysql|postgres|mongo|elastic|redis|config|backup|persistent|storage"
    
    docker_run volume ls --format "{{.Name}}" | while read -r vol; do
        # Check if volume name matches important patterns
        if echo "$vol" | grep -qiE "$important_patterns"; then
            # Get volume details
            mp=$(docker_run volume inspect -f '{{.Mountpoint}}' "$vol" 2>/dev/null)
            size=$(du -sh "$mp" 2>/dev/null | awk '{print $1}' || echo "0B")
            created=$(docker_run volume inspect -f '{{.CreatedAt}}' "$vol" 2>/dev/null)
            
            # Check if in use
            containers=$(docker_run ps -a --filter "volume=$vol" --format "{{.Names}}" | paste -sd, -)
            
            echo -e "${BOLD}${GREEN}$vol${NC}"
            echo -e "  Size:       $size"
            echo -e "  Created:    $created"
            echo -e "  Containers: ${containers:-none}"
            echo -e "  ${CYAN}Backup command:${NC}"
            echo -e "    docker_run run --rm -v $vol:/data -v \$(pwd):/backup alpine tar czf /backup/${vol}_\$(date +%Y%m%d).tar.gz -C /data ."
            echo ""
        fi
    done
    
    # Volumes used by running containers
    echo -e "${BOLD}Volumes Used by Running Containers:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}\n"
    
    docker_run ps --format "{{.Names}}" | while read -r container; do
        docker_run inspect "$container" -f '{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}}{{println}}{{end}}{{end}}' \
        | while read -r vol; do
            [[ -z "$vol" ]] && continue
            
            mp=$(docker_run volume inspect -f '{{.Mountpoint}}' "$vol" 2>/dev/null)
            size=$(du -sh "$mp" 2>/dev/null | awk '{print $1}' || echo "0B")
            
            echo -e "  • ${CYAN}$vol${NC} (used by $container, size: $size)"
        done
    done
}

# ==============================================================================
# Cleanup Suggestions
# ==============================================================================

suggest_cleanup() {
    echo -e "${BOLD}${CYAN}Volume Cleanup Suggestions${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}\n"
    
    local total_reclaimable=0
    local dangling_volumes=()
    local old_volumes=()
    local empty_volumes=()
    
    # Find dangling volumes
    echo -e "${BOLD}Dangling Volumes:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    
    docker_run volume ls --format "{{.Name}}" | while read -r vol; do
        containers=$(docker_run ps -a --filter "volume=$vol" -q | wc -l)
        if [[ $containers -eq 0 ]]; then
            mp=$(docker_run volume inspect -f '{{.Mountpoint}}' "$vol" 2>/dev/null)
            size_bytes=$(du -sb "$mp" 2>/dev/null | awk '{print $1}' || echo 0)
            size=$(du -sh "$mp" 2>/dev/null | awk '{print $1}' || echo "0B")
            
            dangling_volumes+=("$vol")
            total_reclaimable=$((total_reclaimable + size_bytes))
            
            echo -e "  ${YELLOW}$vol${NC} - $size"
        fi
    done
    
    if [[ ${#dangling_volumes[@]} -eq 0 ]]; then
        echo -e "  ${GREEN}✓ No dangling volumes${NC}"
    fi
    
    # Find old unused volumes
    echo -e "\n${BOLD}Old Unused Volumes (>30 days):${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    
    local thirty_days_ago=$(date -d '30 days ago' +%s)
    docker_run volume ls --format "{{.Name}}" | while read -r vol; do
        created=$(docker_run volume inspect -f '{{.CreatedAt}}' "$vol" 2>/dev/null)
        created_ts=$(date -d "$created" +%s 2>/dev/null || echo 0)
        
        if [[ $created_ts -lt $thirty_days_ago ]]; then
            containers=$(docker_run ps -a --filter "volume=$vol" -q | wc -l)
            if [[ $containers -eq 0 ]]; then
                mp=$(docker_run volume inspect -f '{{.Mountpoint}}' "$vol" 2>/dev/null)
                size=$(du -sh "$mp" 2>/dev/null | awk '{print $1}' || echo "0B")
                
                old_volumes+=("$vol")
                
                age_days=$(( ($(date +%s) - created_ts) / 86400 ))
                echo -e "  ${YELLOW}$vol${NC} - $size (${age_days} days old)"
            fi
        fi
    done
    
    if [[ ${#old_volumes[@]} -eq 0 ]]; then
        echo -e "  ${GREEN}✓ No old unused volumes${NC}"
    fi
    
    # Find empty volumes
    echo -e "\n${BOLD}Empty Volumes:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    
    docker_run volume ls --format "{{.Name}}" | while read -r vol; do
        mp=$(docker_run volume inspect -f '{{.Mountpoint}}' "$vol" 2>/dev/null)
        if [[ -d "$mp" ]]; then
            file_count=$(find "$mp" -type f 2>/dev/null | wc -l)
            if [[ $file_count -eq 0 ]]; then
                empty_volumes+=("$vol")
                echo -e "  ${CYAN}$vol${NC} - empty"
            fi
        fi
    done
    
    if [[ ${#empty_volumes[@]} -eq 0 ]]; then
        echo -e "  ${GREEN}✓ No empty volumes${NC}"
    fi
    
    # Summary and recommendations
    echo -e "\n${BOLD}Cleanup Summary:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    
    echo -e "  Dangling volumes:     ${#dangling_volumes[@]}"
    echo -e "  Old unused volumes:   ${#old_volumes[@]}"
    echo -e "  Empty volumes:        ${#empty_volumes[@]}"
    echo -e "  Reclaimable space:    ${YELLOW}$(numfmt --to=iec-i --suffix=B $total_reclaimable 2>/dev/null)${NC}"
    
    echo -e "\n${BOLD}Cleanup Commands:${NC}"
    
    if [[ ${#dangling_volumes[@]} -gt 0 ]]; then
        echo -e "\n  ${CYAN}Remove dangling volumes:${NC}"
        echo -e "    docker_run volume prune -f"
    fi
    
    if [[ ${#old_volumes[@]} -gt 0 ]]; then
        echo -e "\n  ${CYAN}Remove specific old volumes:${NC}"
        for vol in "${old_volumes[@]:0:3}"; do
            echo -e "    docker_run volume rm $vol"
        done
        [[ ${#old_volumes[@]} -gt 3 ]] && echo -e "    ... and $((${#old_volumes[@]} - 3)) more"
    fi
    
    echo -e "\n  ${CYAN}Complete cleanup (use with caution):${NC}"
    echo -e "    docker_run volume prune -a -f"
}

# ==============================================================================
# JSON Output
# ==============================================================================

get_volumes_json() {
    echo "["
    local first=true
    now_ts=$(date +%s)
    
    docker_run volume ls --format "{{.Name}}" | while read -r name; do
        [[ "$first" == "true" ]] && first=false || echo ","
        
        # Get volume details
        driver=$(docker_run volume inspect -f '{{.Driver}}' "$name" 2>/dev/null)
        created=$(docker_run volume inspect -f '{{.CreatedAt}}' "$name" 2>/dev/null)
        mountpoint=$(docker_run volume inspect -f '{{.Mountpoint}}' "$name" 2>/dev/null)
        scope=$(docker_run volume inspect -f '{{.Scope}}' "$name" 2>/dev/null)
        
        # Get size
        size_bytes=$(du -sb "$mountpoint" 2>/dev/null | awk '{print $1}' || echo 0)
        
        # Get containers
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

# ==============================================================================
# CSV Output
# ==============================================================================

get_volumes_csv() {
    echo "Name,Driver,Size,Created,Dangling,Containers,Mountpoint"
    
    docker_run volume ls --format "{{.Name}}" | while read -r name; do
        driver=$(docker_run volume inspect -f '{{.Driver}}' "$name" 2>/dev/null)
        created=$(docker_run volume inspect -f '{{.CreatedAt}}' "$name" 2>/dev/null)
        mountpoint=$(docker_run volume inspect -f '{{.Mountpoint}}' "$name" 2>/dev/null)
        
        # Get size
        size=$(du -sh "$mountpoint" 2>/dev/null | awk '{print $1}' || echo "0B")
        
        # Get containers
        containers=$(docker_run ps -a --filter "volume=$name" --format "{{.Names}}" | paste -sd' ' -)
        
        # Determine dangling
        dangling="no"
        [[ -z "$containers" ]] && dangling="yes" && containers="none"
        
        echo "$name,$driver,$size,$created,$dangling,\"$containers\",$mountpoint"
    done
}

# ==============================================================================
# Main
# ==============================================================================

main() {
    local size_report_mode=false
    local usage_map_mode=false
    local backup_list_mode=false
    local cleanup_suggest_mode=false
    
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
                SHOW_DANGLING="only"
                shift
                ;;
            -u|--used)
                SHOW_DANGLING="none"
                shift
                ;;
            --size-report)
                size_report_mode=true
                shift
                ;;
            --usage-map)
                usage_map_mode=true
                shift
                ;;
            --backup-list)
                backup_list_mode=true
                shift
                ;;
            --cleanup-suggest)
                cleanup_suggest_mode=true
                shift
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
    if [[ "$size_report_mode" == "true" ]]; then
        volume_size_report
    elif [[ "$usage_map_mode" == "true" ]]; then
        volume_usage_map
    elif [[ "$backup_list_mode" == "true" ]]; then
        generate_backup_list
    elif [[ "$cleanup_suggest_mode" == "true" ]]; then
        suggest_cleanup
    else
        # Default: show volume table
        case "$OUTPUT_FORMAT" in
            json)
                get_volumes_json
                ;;
            csv)
                get_volumes_csv
                ;;
            *)
                echo -e "${BOLD}${CYAN}Advanced Docker Volume Analysis${NC}"
                echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}\n"
                get_advanced_volumes_table
                
                # Summary
                echo -e "\n${BOLD}Summary:${NC}"
                local total=$(docker_run volume ls -q | wc -l)
                local dangling=$(docker_run volume ls -qf dangling=true | wc -l)
                echo -e "  Total Volumes: ${BOLD}$total${NC}"
                echo -e "  In Use:        ${GREEN}$((total - dangling))${NC}"
                echo -e "  Dangling:      ${YELLOW}$dangling${NC}"
                
                if [[ $dangling -gt 0 ]]; then
                    echo -e "\n  ${CYAN}Tip:${NC} Run 'dockerkit cleanup --volumes' to remove dangling volumes"
                fi
                ;;
        esac
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}}" ]]; then
    main "$@"
fi