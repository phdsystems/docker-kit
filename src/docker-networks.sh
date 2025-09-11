#!/bin/bash

# ==============================================================================
# DockerKit - Docker Networks Detailed Retrieval
# ==============================================================================
# Provides comprehensive information about Docker networks including
# configuration, connected containers, and network isolation
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
OUTPUT_FORMAT=${OUTPUT_FORMAT:-table}  # Options: table, json, csv, detailed

# ==============================================================================
# Functions
# ==============================================================================

show_help() {
    cat <<EOF
${BOLD}${CYAN}DockerKit - Docker Networks Inspector${NC}

${BOLD}USAGE:${NC}
    $0 [OPTIONS]

${BOLD}OPTIONS:${NC}
    -h, --help          Show this help message
    -f, --format TYPE   Output format: table, json, csv, detailed (default: table)
    -n, --no-header     Suppress header in table output
    -i, --inspect NAME  Detailed inspection of specific network
    -c, --containers    Show container details for each network
    -u, --unused        Show only unused networks

${BOLD}EXAMPLES:${NC}
    # Show all networks with details
    $0

    # Show with container details
    $0 --containers

    # Export as JSON
    $0 --format json > networks.json

    # Inspect specific network
    $0 --inspect bridge

    # Show unused networks
    $0 --unused

${BOLD}OUTPUT COLUMNS:${NC}
    IDX         - Index number
    NAME        - Network name
    ID          - Network ID
    DRIVER      - Network driver (bridge, overlay, host, etc.)
    SCOPE       - Network scope (local, global, swarm)
    INTERNAL    - Whether network is internal
    CREATED     - Creation timestamp
    SUBNETS     - IP subnets
    CONTAINERS  - Connected containers
EOF
}

get_networks_table() {
    (
        if [[ "$SHOW_HEADER" == "true" ]]; then
            printf "%-5s %-20s %-12s %-12s %-20s %-12s %-25s %-40s %-20s\n" \
                "IDX" "NAME" "ID" "DRIVER" "SCOPE" "INTERNAL" "CREATED" "SUBNETS" "CONTAINERS"
        fi
        
        i=1
        docker_run network ls --format "{{.ID}}\t{{.Name}}\t{{.Driver}}\t{{.Scope}}" \
        | while IFS=$'\t' read -r id name driver scope; do
            # Get detailed network info
            read -r created internal subnets containers <<<"$(
                docker_run network inspect -f \
'{{.Created}}|{{.Internal}}|{{range .IPAM.Config}}{{.Subnet}} {{end}}|{{range $cid,$c := .Containers}}{{$c.Name}},{{end}}' "$id" 2>/dev/null \
                | awk -F'|' '{print $1,$2,$3,$4}'
            )"
            
            # Format timestamp
            created_fmt=$(date -d "$created" +"%Y-%m-%d %H:%M:%S %z" 2>/dev/null || echo "$created")
            
            # Clean up values
            [[ -z "$subnets" ]] && subnets="(none)"
            [[ -z "$containers" ]] && containers="(none)" || containers=$(echo "$containers" | sed 's/,$//')
            
            printf "%-5s %-20s %-12s %-12s %-20s %-12s %-25s %-40s %-20s\n" \
                "$i" "$name" "$id" "$driver" "$scope" "$internal" "$created_fmt" "$subnets" "$containers"
            i=$((i+1))
        done
    )
}

get_networks_with_containers() {
    (
        if [[ "$SHOW_HEADER" == "true" ]]; then
            printf "%-5s %-24s %-12s %-10s %-10s %-40s %-50s\n" \
                "IDX" "NAME" "ID" "DRIVER" "SCOPE" "CONTAINERS" "IMAGES"
        fi
        
        i=1
        docker_run network ls --format "{{.ID}}\t{{.Name}}\t{{.Driver}}\t{{.Scope}}" \
        | while IFS=$'\t' read -r net_id net_name driver scope; do
            # Get container mapping
            map=$(docker_run network inspect "$net_id" -f '{{range $cid,$c := .Containers}}{{$c.Name}}:{{$cid}},{{end}}')
            
            # Extract container names
            containers=$(echo "$map" | tr ',' '\n' | awk -F: 'NF==2{print $1}' | paste -sd, -)
            [[ -z "$containers" ]] && containers="(none)"
            
            # Extract images for those containers
            images=$(echo "$map" | tr ',' '\n' | awk -F: 'NF==2{print $2}' \
                     | xargs -r -I {} docker_run inspect -f '{{.Config.Image}}' {} 2>/dev/null \
                     | sort -u | paste -sd, -)
            [[ -z "$images" ]] && images="(none)"
            
            printf "%-5s %-24s %-12s %-10s %-10s %-40s %-50s\n" \
                "$i" "$net_name" "$net_id" "$driver" "$scope" "$containers" "$images"
            i=$((i+1))
        done
    )
}

get_networks_json() {
    echo "["
    local first=true
    
    docker_run network ls --format "{{.ID}}" \
    | while read -r id; do
        [[ "$first" == "true" ]] && first=false || echo ","
        docker_run network inspect "$id" 2>/dev/null | jq -c '.[0]'
    done
    echo "]"
}

get_networks_csv() {
    echo "Name,ID,Driver,Scope,Internal,Created,Subnets,Containers"
    
    docker_run network ls --format "{{.Name}}\t{{.ID}}\t{{.Driver}}\t{{.Scope}}" \
    | while IFS=$'\t' read -r name id driver scope; do
        # Get network details
        internal=$(docker_run network inspect -f '{{.Internal}}' "$id" 2>/dev/null)
        created=$(docker_run network inspect -f '{{.Created}}' "$id" 2>/dev/null)
        subnets=$(docker_run network inspect -f '{{range .IPAM.Config}}{{.Subnet}},{{end}}' "$id" 2>/dev/null | sed 's/,$//')
        containers=$(docker_run network inspect -f '{{range $cid,$c := .Containers}}{{$c.Name}},{{end}}' "$id" 2>/dev/null | sed 's/,$//')
        
        [[ -z "$subnets" ]] && subnets="none"
        [[ -z "$containers" ]] && containers="none"
        
        echo "$name,$id,$driver,$scope,$internal,$created,\"$subnets\",\"$containers\""
    done
}

inspect_network() {
    local network="$1"
    
    if ! docker_run network inspect "$network" &>/dev/null; then
        echo -e "${RED}Error: Network '$network' not found${NC}"
        exit 1
    fi
    
    echo -e "${BOLD}${CYAN}Detailed Network Inspection: $network${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Basic info
    echo -e "\n${BOLD}Basic Information:${NC}"
    docker_run network inspect "$network" --format '
Name:        {{.Name}}
ID:          {{.Id}}
Driver:      {{.Driver}}
Scope:       {{.Scope}}
Internal:    {{.Internal}}
Attachable:  {{.Attachable}}
Ingress:     {{.Ingress}}
Created:     {{.Created}}'
    
    # IPAM Configuration
    echo -e "\n${BOLD}IPAM Configuration:${NC}"
    docker_run network inspect "$network" --format '
Driver:      {{.IPAM.Driver}}{{range .IPAM.Config}}
Subnet:      {{.Subnet}}
Gateway:     {{.Gateway}}
IP Range:    {{.IPRange}}{{end}}'
    
    # Options
    echo -e "\n${BOLD}Driver Options:${NC}"
    options=$(docker_run network inspect -f '{{range $k, $v := .Options}}{{$k}}={{$v}}
{{end}}' "$network" 2>/dev/null)
    [[ -z "$options" ]] && options="(none)"
    echo "$options"
    
    # Labels
    echo -e "\n${BOLD}Labels:${NC}"
    labels=$(docker_run network inspect -f '{{range $k, $v := .Labels}}{{$k}}={{$v}}
{{end}}' "$network" 2>/dev/null)
    [[ -z "$labels" ]] && labels="(none)"
    echo "$labels"
    
    # Connected Containers
    echo -e "\n${BOLD}Connected Containers:${NC}"
    docker_run network inspect "$network" --format '{{range $cid, $conf := .Containers}}
Container:   {{$conf.Name}}
  ID:        {{$cid}}
  IPv4:      {{$conf.IPv4Address}}
  IPv6:      {{$conf.IPv6Address}}
  MAC:       {{$conf.MacAddress}}{{end}}' | grep -v '^$' || echo "(none)"
    
    # Peers (for overlay networks)
    if [[ $(docker_run network inspect -f '{{.Driver}}' "$network") == "overlay" ]]; then
        echo -e "\n${BOLD}Peers:${NC}"
        docker_run network inspect "$network" --format '{{range $pid, $peer := .Peers}}
Peer {{$pid}}:
  Name: {{$peer.Name}}
  IP:   {{$peer.IP}}{{end}}' 2>/dev/null || echo "(none)"
    fi
}

get_networks_detailed() {
    docker_run network ls --format "{{.Name}}" | while read -r name; do
        echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
        inspect_network "$name"
    done
}

get_unused_networks() {
    echo -e "${CYAN}Unused Networks (no containers attached):${NC}"
    
    local has_unused=false
    docker_run network ls --format "{{.ID}}\t{{.Name}}" | while IFS=$'\t' read -r id name; do
        containers=$(docker_run network inspect -f '{{range $cid,$c := .Containers}}{{$c.Name}}{{end}}' "$id" 2>/dev/null)
        if [[ -z "$containers" ]] && [[ "$name" != "bridge" ]] && [[ "$name" != "host" ]] && [[ "$name" != "none" ]]; then
            has_unused=true
            echo "  - $name (ID: $id)"
        fi
    done
    
    if [[ "$has_unused" == "false" ]]; then
        echo "  (none - all networks are in use or are system networks)"
    fi
}

# ==============================================================================
# Main
# ==============================================================================

main() {
    local inspect_name=""
    local show_containers=false
    local show_unused=false
    
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
            -n|--no-header)
                SHOW_HEADER=false
                shift
                ;;
            -i|--inspect)
                inspect_name="$2"
                shift 2
                ;;
            -c|--containers)
                show_containers=true
                shift
                ;;
            -u|--unused)
                show_unused=true
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
    if [[ -n "$inspect_name" ]]; then
        inspect_network "$inspect_name"
        exit 0
    fi
    
    if [[ "$show_unused" == "true" ]]; then
        get_unused_networks
        exit 0
    fi
    
    if [[ "$show_containers" == "true" ]]; then
        get_networks_with_containers
        exit 0
    fi
    
    # Output based on format
    case "$OUTPUT_FORMAT" in
        json)
            get_networks_json
            ;;
        csv)
            get_networks_csv
            ;;
        detailed)
            get_networks_detailed
            ;;
        table|*)
            get_networks_table
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi