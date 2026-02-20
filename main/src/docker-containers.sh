#!/bin/bash

# ==============================================================================
# DockerKit - Docker Containers Detailed Retrieval
# ==============================================================================
# Provides comprehensive information about Docker containers including size,
# networks, mounts, ports, and resource usage
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
OUTPUT_FORMAT=${OUTPUT_FORMAT:-table}  # Options: table, json, csv, detailed
SHOW_ALL=${SHOW_ALL:-true}  # Show all containers or just running

# ==============================================================================
# Functions
# ==============================================================================

show_help() {
    cat <<EOF
${BOLD}${CYAN}DockerKit - Docker Containers Inspector${NC}

${BOLD}USAGE:${NC}
    $0 [OPTIONS]

${BOLD}OPTIONS:${NC}
    -h, --help          Show this help message
    -f, --format TYPE   Output format: table, json, csv, detailed (default: table)
    -r, --running       Show only running containers
    -a, --all           Show all containers (default)
    -n, --no-header     Suppress header in table output
    -s, --stats         Include live resource statistics
    -i, --inspect ID    Detailed inspection of specific container

${BOLD}EXAMPLES:${NC}
    # Show all containers with detailed info
    $0

    # Show only running containers
    $0 --running

    # Export as JSON
    $0 --format json > containers.json

    # Show with live stats
    $0 --stats

    # Inspect specific container
    $0 --inspect container_name

${BOLD}OUTPUT COLUMNS:${NC}
    IDX         - Index number
    NAME        - Container name
    IMAGE       - Image used
    STATUS      - Current status
    RW SIZE     - Read/write layer size
    VIRT SIZE   - Virtual size (RW + image)
    ALLOC SIZE  - Allocated size
    CREATED AT  - Creation timestamp
    AGE(d)      - Age in days
    RESTART     - Restart policy
    NETWORKS    - Connected networks
    PORTS       - Port mappings
    MOUNTS      - Volume mounts
EOF
}

get_containers_table() {
    (
        if [[ "$SHOW_HEADER" == "true" ]]; then
            printf "%-5s %-20s %-25s %-25s %-12s %-14s %-14s %-25s %-7s %-10s %-15s %-25s %-40s\n" \
                "IDX" "NAME" "IMAGE" "STATUS" "RW SIZE" "VIRT SIZE" "ALLOC SIZE" "CREATED AT" "AGE(d)" "RESTART" "NETWORKS" "PORTS" "MOUNTS"
        fi
        
        now_ts=$(date +%s)
        i=1
        
        local ps_args="-a"
        [[ "$SHOW_ALL" == "false" ]] && ps_args=""
        
        docker_run ps $ps_args --format "{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" \
        | while IFS=$'\t' read -r id name image status ports; do
            # Get detailed info with size
            read -r created size_rw size_rootfs restart networks mounts <<<"$(
                docker_run inspect --size -f \
'{{.Created}}|{{.SizeRw}}|{{.SizeRootFs}}|{{.HostConfig.RestartPolicy.Name}}|{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}|{{range .Mounts}}{{if .Name}}{{.Name}}{{else}}{{.Source}}{{end}}:{{.Destination}}{{if .RW}}:rw{{else}}:ro{{end}},{{end}}' \
"$id" 2>/dev/null | awk -F'|' '{print $1,$2,$3,$4,$5,$6}'
            )"
            
            # Format timestamps and calculate age
            created_fmt=$(date -d "$created" +"%Y-%m-%d %H:%M:%S %z" 2>/dev/null || echo "$created")
            created_ts=$(date -d "$created" +%s 2>/dev/null || echo 0)
            age_days=$(( (now_ts - created_ts) / 86400 ))
            
            # Format sizes
            hrw=$(numfmt --to=iec-i --suffix=B ${size_rw:-0} 2>/dev/null || echo "0B")
            hvirt=$(numfmt --to=iec-i --suffix=B $(( (${size_rootfs:-0} + ${size_rw:-0}) )) 2>/dev/null || echo "0B")
            halloc=$(numfmt --to=iec-i --suffix=B ${size_rootfs:-0} 2>/dev/null || echo "0B")
            
            # Clean up empty values
            [[ -z "$restart" || "$restart" == " " ]] && restart="no"
            [[ -z "$ports" ]] && ports="(none)"
            [[ -z "$networks" ]] && networks="(none)"
            mounts=$(echo "$mounts" | sed 's/,$//'); [[ -z "$mounts" ]] && mounts="(none)"
            
            printf "%-5s %-20s %-25s %-25s %-12s %-14s %-14s %-25s %-7s %-10s %-15s %-25s %-40s\n" \
                "$i" "$name" "$image" "$status" "$hrw" "$hvirt" "$halloc" "$created_fmt" "$age_days" "$restart" "$networks" "$ports" "$mounts"
            i=$((i+1))
        done
    )
}

get_containers_json() {
    echo "["
    local first=true
    now_ts=$(date +%s)
    
    local ps_args="-a"
    [[ "$SHOW_ALL" == "false" ]] && ps_args=""
    
    docker_run ps $ps_args --format "{{.ID}}" \
    | while read -r id; do
        [[ "$first" == "true" ]] && first=false || echo ","
        
        docker_run inspect --size "$id" 2>/dev/null | jq -c '.[0] | {
            id: .Id,
            name: .Name[1:],
            image: .Config.Image,
            state: .State,
            created: .Created,
            size_rw: .SizeRw,
            size_rootfs: .SizeRootFs,
            restart_policy: .HostConfig.RestartPolicy,
            networks: .NetworkSettings.Networks,
            mounts: .Mounts,
            ports: .NetworkSettings.Ports,
            environment: .Config.Env,
            labels: .Config.Labels
        }'
    done
    echo "]"
}

get_containers_csv() {
    echo "Name,Image,Status,State,Created,SizeRW,Networks,Ports,Mounts"
    
    local ps_args="-a"
    [[ "$SHOW_ALL" == "false" ]] && ps_args=""
    
    docker_run ps $ps_args --format "{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.State}}\t{{.CreatedAt}}\t{{.Size}}" \
    | while IFS=$'\t' read -r name image status state created size; do
        # Get networks and mounts
        networks=$(docker_run inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}},{{end}}' "$name" 2>/dev/null | sed 's/,$//')
        ports=$(docker_run inspect -f '{{range $p,$conf := .NetworkSettings.Ports}}{{if $conf}}{{$p}},{{end}}{{end}}' "$name" 2>/dev/null | sed 's/,$//')
        mounts=$(docker_run inspect -f '{{range .Mounts}}{{.Destination}},{{end}}' "$name" 2>/dev/null | sed 's/,$//')
        
        echo "$name,$image,$status,$state,$created,$size,\"$networks\",\"$ports\",\"$mounts\""
    done
}

get_container_stats() {
    echo -e "${CYAN}Container Resource Statistics:${NC}"
    docker_run stats --no-stream --format "table {{.Container}}\t{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}\t{{.PIDs}}"
}

inspect_container() {
    local container="$1"
    
    if ! docker_run inspect "$container" &>/dev/null; then
        echo -e "${RED}Error: Container '$container' not found${NC}"
        exit 1
    fi
    
    echo -e "${BOLD}${CYAN}Detailed Container Inspection: $container${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Basic info
    echo -e "\n${BOLD}Basic Information:${NC}"
    docker_run inspect "$container" --format '
ID:          {{.Id}}
Name:        {{.Name}}
Image:       {{.Config.Image}}
Created:     {{.Created}}
State:       {{.State.Status}}
Started:     {{.State.StartedAt}}
Finished:    {{.State.FinishedAt}}
Exit Code:   {{.State.ExitCode}}
PID:         {{.State.Pid}}
Platform:    {{.Platform}}'
    
    # Network info
    echo -e "\n${BOLD}Network Configuration:${NC}"
    docker_run inspect "$container" --format '{{range $net, $conf := .NetworkSettings.Networks}}
Network:     {{$net}}
  IP:        {{$conf.IPAddress}}
  Gateway:   {{$conf.Gateway}}
  MAC:       {{$conf.MacAddress}}{{end}}'
    
    # Port mappings
    echo -e "\n${BOLD}Port Mappings:${NC}"
    docker_run inspect "$container" --format '{{range $port, $conf := .NetworkSettings.Ports}}{{if $conf}}
{{$port}} -> {{(index $conf 0).HostPort}}{{end}}{{end}}'
    
    # Mounts
    echo -e "\n${BOLD}Mounts:${NC}"
    docker_run inspect "$container" --format '{{range .Mounts}}
Type:        {{.Type}}
Source:      {{.Source}}
Destination: {{.Destination}}
Mode:        {{.Mode}}
RW:          {{.RW}}
{{end}}'
    
    # Resource limits
    echo -e "\n${BOLD}Resource Limits:${NC}"
    docker_run inspect "$container" --format '
Memory:      {{.HostConfig.Memory}}
CPUs:        {{.HostConfig.CpuQuota}}/{{.HostConfig.CpuPeriod}}
CPU Shares:  {{.HostConfig.CpuShares}}'
    
    # Environment variables (first 5)
    echo -e "\n${BOLD}Environment Variables (first 5):${NC}"
    docker_run inspect "$container" --format '{{range $index, $env := .Config.Env}}{{if lt $index 5}}{{$env}}
{{end}}{{end}}'
}

get_containers_detailed() {
    local ps_args="-a"
    [[ "$SHOW_ALL" == "false" ]] && ps_args=""
    
    docker_run ps $ps_args --format "{{.Names}}" | while read -r name; do
        echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
        inspect_container "$name"
    done
}

# ==============================================================================
# Main
# ==============================================================================

main() {
    local show_stats=false
    local inspect_id=""
    
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
            -r|--running)
                SHOW_ALL=false
                shift
                ;;
            -a|--all)
                SHOW_ALL=true
                shift
                ;;
            -n|--no-header)
                SHOW_HEADER=false
                shift
                ;;
            -s|--stats)
                show_stats=true
                shift
                ;;
            -i|--inspect)
                inspect_id="$2"
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
    if ! docker info &> /dev/null; then
        echo -e "${RED}Error: Docker daemon is not running${NC}"
        exit 1
    fi
    
    # Handle inspect mode
    if [[ -n "$inspect_id" ]]; then
        inspect_container "$inspect_id"
        exit 0
    fi
    
    # Handle stats mode
    if [[ "$show_stats" == "true" ]]; then
        get_container_stats
        exit 0
    fi
    
    # Output based on format
    case "$OUTPUT_FORMAT" in
        json)
            get_containers_json
            ;;
        csv)
            get_containers_csv
            ;;
        detailed)
            get_containers_detailed
            ;;
        table|*)
            get_containers_table
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi