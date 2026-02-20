#!/bin/bash

# ==============================================================================
# DockerKit - Advanced Docker Containers Analysis
# ==============================================================================
# Enhanced container analysis with size tracking, network, and mount details
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
SHOW_ALL="${SHOW_ALL:-true}"
SORT_BY="${SORT_BY:-name}" # Options: name, size, age, status
TOP_N="${TOP_N:-0}" # Show top N containers (0 = all)

# ==============================================================================
# Helper Functions
# ==============================================================================

show_help() {
    cat <<EOF
${BOLD}${CYAN}DockerKit - Advanced Container Analysis${NC}

${BOLD}USAGE:${NC}
    $0 [OPTIONS]

${BOLD}OPTIONS:${NC}
    -h, --help          Show this help message
    -f, --format TYPE   Output format: table, json, csv, wide (default: table)
    -s, --sort FIELD    Sort by: name, size, age, status (default: name)
    -t, --top N         Show top N containers by size
    -r, --running       Show only running containers
    -a, --all           Show all containers (default)
    --size-analysis     Detailed size breakdown
    --network-map       Network connectivity mapping
    --mount-analysis    Volume and bind mount analysis

${BOLD}EXAMPLES:${NC}
    # Show all containers with detailed info
    $0

    # Top 10 containers by size
    $0 --top 10 --sort size

    # Running containers only
    $0 --running

    # Size analysis report
    $0 --size-analysis

    # Network mapping
    $0 --network-map

${BOLD}OUTPUT COLUMNS:${NC}
    IDX         - Index number
    NAME        - Container name
    IMAGE       - Image used
    STATUS      - Container status
    RW SIZE     - Read/write layer size
    VIRT SIZE   - Virtual size (RootFS + RW)
    ALLOC SIZE  - Allocated size (RootFS)
    CREATED AT  - Creation timestamp
    AGE(d)      - Age in days
    RESTART     - Restart policy
    NETWORKS    - Connected networks
    PORTS       - Port mappings
    MOUNTS      - Volume/bind mounts
EOF
}

# ==============================================================================
# Advanced Container Analysis
# ==============================================================================

get_advanced_containers_table() {
    (
        # Print header
        printf "%-5s %-20s %-25s %-25s %-12s %-14s %-14s %-25s %-7s %-10s %-15s %-25s %-40s\n" \
            "IDX" "NAME" "IMAGE" "STATUS" "RW SIZE" "VIRT SIZE" "ALLOC SIZE" "CREATED AT" "AGE(d)" "RESTART" "NETWORKS" "PORTS" "MOUNTS"
        
        printf "%-5s %-20s %-25s %-25s %-12s %-14s %-14s %-25s %-7s %-10s %-15s %-25s %-40s\n" \
            "---" "--------------------" "-------------------------" "-------------------------" \
            "------------" "--------------" "--------------" "-------------------------" "-------" \
            "----------" "---------------" "-------------------------" "----------------------------------------"
        
        now_ts=$(date +%s)
        i=1
        
        # Process containers
        docker_run ps -a --format "{{.ID}}|{{.Names}}|{{.Image}}|{{.Status}}|{{.Ports}}" \
        | while IFS='|' read -r id name image status ports; do
            # Get detailed container info with size
            read -r created size_rw size_rootfs restart networks mounts <<<"$(
                docker_run inspect --size -f \
                '{{.Created}}|{{.SizeRw}}|{{.SizeRootFs}}|{{.HostConfig.RestartPolicy.Name}}|{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}|{{range .Mounts}}{{if .Name}}{{.Name}}{{else}}{{.Source}}{{end}}:{{.Destination}}{{if .RW}}:rw{{else}}:ro{{end}},{{end}}' \
                "$id" 2>/dev/null | awk -F'|' '{print $1,$2,$3,$4,$5,$6}'
            )"
            
            # Format creation date
            created_fmt=$(date -d "$created" +"%Y-%m-%d %H:%M:%S %z" 2>/dev/null || echo "$created")
            created_ts=$(date -d "$created" +%s 2>/dev/null || echo 0)
            age_days=$(( (now_ts - created_ts) / 86400 ))
            (( age_days < 0 )) && age_days=0
            
            # Format sizes
            hrw=$(numfmt --to=iec-i --suffix=B ${size_rw:-0} 2>/dev/null || echo "0B")
            hvirt=$(numfmt --to=iec-i --suffix=B $(( (${size_rootfs:-0} + ${size_rw:-0}) )) 2>/dev/null || echo "0B")
            halloc=$(numfmt --to=iec-i --suffix=B ${size_rootfs:-0} 2>/dev/null || echo "0B")
            
            # Clean up fields
            [[ -z "$restart" || "$restart" == " " ]] && restart="no"
            [[ -z "$ports" ]] && ports="(none)"
            [[ -z "$networks" ]] && networks="(none)"
            mounts=$(echo "$mounts" | sed 's/,$//'); [[ -z "$mounts" ]] && mounts="(none)"
            
            # Truncate long fields
            [[ ${#name} -gt 19 ]] && name="${name:0:17}.."
            [[ ${#image} -gt 24 ]] && image="${image:0:22}.."
            [[ ${#status} -gt 24 ]] && status="${status:0:22}.."
            [[ ${#ports} -gt 24 ]] && ports="${ports:0:22}.."
            [[ ${#mounts} -gt 39 ]] && mounts="${mounts:0:37}.."
            
            printf "%-5s %-20s %-25s %-25s %-12s %-14s %-14s %-25s %-7s %-10s %-15s %-25s %-40s\n" \
                "$i" "$name" "$image" "$status" "$hrw" "$hvirt" "$halloc" "$created_fmt" "$age_days" "$restart" "$networks" "$ports" "$mounts"
            
            i=$((i+1))
        done
    )
}

# ==============================================================================
# Size Analysis
# ==============================================================================

container_size_analysis() {
    echo -e "${BOLD}${CYAN}Container Size Analysis${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}\n"
    
    local total_rw=0
    local total_virtual=0
    local total_containers=0
    local running_containers=0
    
    echo -e "${BOLD}Container Size Breakdown:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    
    printf "${BOLD}%-25s %-15s %-15s %-15s %-10s${NC}\n" \
        "CONTAINER" "RW LAYER" "VIRTUAL" "ALLOCATED" "STATUS"
    
    docker_run ps -a --format "{{.ID}}|{{.Names}}|{{.Status}}" | while IFS='|' read -r id name status; do
        # Get size info
        read -r size_rw size_rootfs <<<"$(
            docker_run inspect --size -f '{{.SizeRw}} {{.SizeRootFs}}' "$id" 2>/dev/null || echo "0 0"
        )"
        
        # Calculate sizes
        size_rw=${size_rw:-0}
        size_rootfs=${size_rootfs:-0}
        virtual_size=$((size_rootfs + size_rw))
        
        # Format sizes
        hrw=$(numfmt --to=iec-i --suffix=B $size_rw 2>/dev/null || echo "0B")
        hvirt=$(numfmt --to=iec-i --suffix=B $virtual_size 2>/dev/null || echo "0B")
        halloc=$(numfmt --to=iec-i --suffix=B $size_rootfs 2>/dev/null || echo "0B")
        
        # Track totals
        total_rw=$((total_rw + size_rw))
        total_virtual=$((total_virtual + virtual_size))
        ((total_containers++))
        
        # Check if running
        if [[ "$status" =~ ^Up ]]; then
            ((running_containers++))
            status_display="${GREEN}Running${NC}"
        else
            status_display="${YELLOW}Stopped${NC}"
        fi
        
        # Truncate name if needed
        [[ ${#name} -gt 24 ]] && name="${name:0:22}.."
        
        printf "%-25s %-15s %-15s %-15s " "$name" "$hrw" "$hvirt" "$halloc"
        echo -e "$status_display"
    done
    
    # Summary
    echo -e "\n${BOLD}Summary:${NC}"
    echo -e "  Total Containers:    ${BOLD}$total_containers${NC} ($running_containers running)"
    echo -e "  Total RW Size:       ${BOLD}$(numfmt --to=iec-i --suffix=B $total_rw)${NC}"
    echo -e "  Total Virtual Size:  ${BOLD}$(numfmt --to=iec-i --suffix=B $total_virtual)${NC}"
    
    # Top consumers
    echo -e "\n${BOLD}${YELLOW}Top 5 Space Consumers (RW Layer):${NC}"
    docker_run ps -a -q | while read -r id; do
        name=$(docker_run inspect -f '{{.Name}}' "$id" | sed 's/^\///')
        size_rw=$(docker_run inspect --size -f '{{.SizeRw}}' "$id" 2>/dev/null || echo 0)
        echo "$size_rw|$name"
    done | sort -rn | head -5 | while IFS='|' read -r size name; do
        hsize=$(numfmt --to=iec-i --suffix=B $size 2>/dev/null || echo "0B")
        echo -e "  $name: ${YELLOW}$hsize${NC}"
    done
    
    # Recommendations
    echo -e "\n${BOLD}${CYAN}Recommendations:${NC}"
    
    local stopped_count=$((total_containers - running_containers))
    if [[ $stopped_count -gt 5 ]]; then
        echo -e "  ${YELLOW}•${NC} $stopped_count stopped containers found - consider cleanup"
    fi
    
    if [[ $total_rw -gt 1073741824 ]]; then # > 1GB
        echo -e "  ${YELLOW}•${NC} Large RW layer usage - check for unnecessary data in containers"
    fi
}

# ==============================================================================
# Network Mapping
# ==============================================================================

network_mapping() {
    echo -e "${BOLD}${CYAN}Container Network Mapping${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}\n"
    
    # Get all networks
    echo -e "${BOLD}Networks and Connected Containers:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    
    docker_run network ls --format "{{.Name}}" | while read -r network; do
        if [[ "$network" == "none" ]]; then
            continue
        fi
        
        echo -e "\n${BOLD}${CYAN}Network: $network${NC}"
        
        # Get network details
        local driver=$(docker_run network inspect -f '{{.Driver}}' "$network")
        local subnet=$(docker_run network inspect -f '{{range .IPAM.Config}}{{.Subnet}}{{end}}' "$network")
        local gateway=$(docker_run network inspect -f '{{range .IPAM.Config}}{{.Gateway}}{{end}}' "$network")
        
        echo -e "  Driver: $driver"
        [[ -n "$subnet" ]] && echo -e "  Subnet: $subnet"
        [[ -n "$gateway" ]] && echo -e "  Gateway: $gateway"
        
        echo -e "  ${BOLD}Connected Containers:${NC}"
        
        local container_count=0
        docker_run network inspect "$network" -f '{{range $k,$v := .Containers}}{{$k}}|{{$v.Name}}|{{$v.IPv4Address}}|{{$v.IPv6Address}}{{println}}{{end}}' \
        | while IFS='|' read -r id name ipv4 ipv6; do
            [[ -z "$id" ]] && continue
            ((container_count++))
            
            # Get container status
            local status=$(docker_run inspect -f '{{.State.Status}}' "$id" 2>/dev/null || echo "unknown")
            local status_color="${GREEN}"
            [[ "$status" != "running" ]] && status_color="${YELLOW}"
            
            echo -e "    • ${status_color}$name${NC}"
            [[ -n "$ipv4" ]] && echo -e "      IPv4: $ipv4"
            [[ -n "$ipv6" ]] && echo -e "      IPv6: $ipv6"
        done
        
        if [[ $container_count -eq 0 ]]; then
            echo -e "    ${DIM}(no containers connected)${NC}"
        fi
    done
    
    # Container connectivity matrix
    echo -e "\n${BOLD}Container Connectivity:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    
    docker_run ps --format "{{.Names}}" | while read -r container; do
        echo -e "\n${BOLD}$container:${NC}"
        
        # Get all networks for this container
        docker_run inspect "$container" -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{println}}{{end}}' \
        | while read -r network; do
            [[ -z "$network" ]] && continue
            
            echo -e "  ${CYAN}via $network:${NC}"
            
            # Find other containers on same network
            docker_run network inspect "$network" -f '{{range $k,$v := .Containers}}{{$v.Name}}{{println}}{{end}}' \
            | while read -r other; do
                [[ "$other" != "$container" ]] && [[ -n "$other" ]] && echo -e "    → $other"
            done
        done
    done
}

# ==============================================================================
# Mount Analysis
# ==============================================================================

mount_analysis() {
    echo -e "${BOLD}${CYAN}Container Mount Analysis${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}\n"
    
    # Volume usage
    echo -e "${BOLD}Volume Mounts:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    
    declare -A volume_usage
    
    docker_run ps -a -q | while read -r id; do
        name=$(docker_run inspect -f '{{.Name}}' "$id" | sed 's/^\///')
        
        docker_run inspect "$id" -f '{{range .Mounts}}{{.Type}}|{{.Name}}|{{.Source}}|{{.Destination}}|{{.RW}}{{println}}{{end}}' \
        | while IFS='|' read -r type vol_name source dest rw; do
            [[ -z "$type" ]] && continue
            
            if [[ "$type" == "volume" ]]; then
                # Track volume usage
                if [[ -n "$vol_name" ]]; then
                    if [[ -n "${volume_usage[$vol_name]}" ]]; then
                        volume_usage[$vol_name]="${volume_usage[$vol_name]},$name"
                    else
                        volume_usage[$vol_name]="$name"
                    fi
                    
                    local access="ro"
                    [[ "$rw" == "true" ]] && access="rw"
                    
                    echo -e "  ${CYAN}$vol_name${NC}"
                    echo -e "    Container: $name"
                    echo -e "    Mount: $dest ($access)"
                fi
            fi
        done
    done
    
    # Bind mounts
    echo -e "\n${BOLD}Bind Mounts:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    
    docker_run ps -a -q | while read -r id; do
        name=$(docker_run inspect -f '{{.Name}}' "$id" | sed 's/^\///')
        
        docker_run inspect "$id" -f '{{range .Mounts}}{{.Type}}|{{.Source}}|{{.Destination}}|{{.RW}}{{println}}{{end}}' \
        | while IFS='|' read -r type source dest rw; do
            if [[ "$type" == "bind" ]]; then
                local access="ro"
                [[ "$rw" == "true" ]] && access="rw"
                
                # Check for sensitive paths
                local warning=""
                if echo "$source" | grep -qE "^/(etc|root|home|var/run)"; then
                    warning="${RED} [SENSITIVE]${NC}"
                fi
                
                echo -e "  ${BOLD}$name:${NC}"
                echo -e "    Source: $source$warning"
                echo -e "    Dest:   $dest ($access)"
            fi
        done
    done
    
    # Shared volumes
    echo -e "\n${BOLD}Shared Volumes:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    
    local shared_found=false
    for vol in "${!volume_usage[@]}"; do
        IFS=',' read -ra containers <<< "${volume_usage[$vol]}"
        if [[ ${#containers[@]} -gt 1 ]]; then
            shared_found=true
            echo -e "  ${CYAN}$vol${NC} shared by:"
            for container in "${containers[@]}"; do
                echo -e "    • $container"
            done
        fi
    done
    
    if [[ "$shared_found" != "true" ]]; then
        echo -e "  ${DIM}No shared volumes found${NC}"
    fi
    
    # Recommendations
    echo -e "\n${BOLD}${CYAN}Recommendations:${NC}"
    
    # Check for root mounts
    if docker_run ps -a -q | xargs -I {} docker_run inspect {} -f '{{range .Mounts}}{{.Source}}{{println}}{{end}}' | grep -q "^/root"; then
        echo -e "  ${RED}⚠${NC} Root directory mounts detected - review security implications"
    fi
    
    # Check for Docker socket mounts
    if docker_run ps -a -q | xargs -I {} docker_run inspect {} -f '{{range .Mounts}}{{.Source}}{{println}}{{end}}' | grep -q "/var/run/docker.sock"; then
        echo -e "  ${RED}⚠${NC} Docker socket mounts detected - major security risk"
    fi
}

# ==============================================================================
# JSON Output
# ==============================================================================

get_containers_json() {
    echo "["
    local first=true
    now_ts=$(date +%s)
    
    docker_run ps -a --format "{{.ID}}" | while read -r id; do
        [[ "$first" == "true" ]] && first=false || echo ","
        
        # Get all container info
        docker_run inspect --size "$id" | jq -c '.[0] | {
            id: .Id,
            name: .Name,
            image: .Config.Image,
            status: .State.Status,
            created: .Created,
            state: .State,
            size_rw: .SizeRw,
            size_rootfs: .SizeRootFs,
            restart_policy: .HostConfig.RestartPolicy,
            networks: .NetworkSettings.Networks,
            ports: .NetworkSettings.Ports,
            mounts: .Mounts,
            env: .Config.Env,
            labels: .Config.Labels
        }'
    done
    
    echo "]"
}

# ==============================================================================
# CSV Output
# ==============================================================================

get_containers_csv() {
    echo "Name,Image,Status,RW Size,Virtual Size,Created,Age(days),Restart,Networks,Ports,Mounts"
    
    now_ts=$(date +%s)
    
    docker_run ps -a --format "{{.ID}}" | while read -r id; do
        # Get container details
        name=$(docker_run inspect -f '{{.Name}}' "$id" | sed 's/^\///')
        image=$(docker_run inspect -f '{{.Config.Image}}' "$id")
        status=$(docker_run inspect -f '{{.State.Status}}' "$id")
        created=$(docker_run inspect -f '{{.Created}}' "$id")
        size_rw=$(docker_run inspect --size -f '{{.SizeRw}}' "$id" 2>/dev/null || echo 0)
        size_rootfs=$(docker_run inspect --size -f '{{.SizeRootFs}}' "$id" 2>/dev/null || echo 0)
        restart=$(docker_run inspect -f '{{.HostConfig.RestartPolicy.Name}}' "$id")
        
        # Calculate age
        created_ts=$(date -d "$created" +%s 2>/dev/null || echo 0)
        age_days=$(( (now_ts - created_ts) / 86400 ))
        
        # Get networks
        networks=$(docker_run inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$id" | tr ' ' ';')
        
        # Get ports
        ports=$(docker_run inspect -f '{{range $p,$conf := .NetworkSettings.Ports}}{{$p}} {{end}}' "$id" | tr ' ' ';')
        
        # Get mounts
        mounts=$(docker_run inspect -f '{{range .Mounts}}{{.Source}}:{{.Destination}} {{end}}' "$id" | tr ' ' ';')
        
        # Calculate virtual size
        virtual_size=$((size_rootfs + size_rw))
        
        echo "$name,$image,$status,$size_rw,$virtual_size,$created,$age_days,$restart,\"$networks\",\"$ports\",\"$mounts\""
    done
}

# ==============================================================================
# Main
# ==============================================================================

main() {
    local running_only=false
    local size_analysis_mode=false
    local network_map_mode=false
    local mount_analysis_mode=false
    
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
            -r|--running)
                running_only=true
                SHOW_ALL=false
                shift
                ;;
            -a|--all)
                SHOW_ALL=true
                shift
                ;;
            --size-analysis)
                size_analysis_mode=true
                shift
                ;;
            --network-map)
                network_map_mode=true
                shift
                ;;
            --mount-analysis)
                mount_analysis_mode=true
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
    if [[ "$size_analysis_mode" == "true" ]]; then
        container_size_analysis
    elif [[ "$network_map_mode" == "true" ]]; then
        network_mapping
    elif [[ "$mount_analysis_mode" == "true" ]]; then
        mount_analysis
    else
        # Default: show container table
        case "$OUTPUT_FORMAT" in
            json)
                get_containers_json
                ;;
            csv)
                get_containers_csv
                ;;
            *)
                echo -e "${BOLD}${CYAN}Advanced Docker Container Analysis${NC}"
                echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}\n"
                get_advanced_containers_table
                
                # Summary
                echo -e "\n${BOLD}Summary:${NC}"
                local total=$(docker_run ps -a -q | wc -l)
                local running=$(docker_run ps -q | wc -l)
                echo -e "  Total Containers: ${BOLD}$total${NC}"
                echo -e "  Running:          ${GREEN}$running${NC}"
                echo -e "  Stopped:          ${YELLOW}$((total - running))${NC}"
                ;;
        esac
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi