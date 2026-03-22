#!/bin/bash

# ==============================================================================
# DockerKit - Advanced Docker Networks Analysis
# ==============================================================================
# Enhanced network analysis with connectivity mapping and subnet management
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
SHOW_INTERNAL="${SHOW_INTERNAL:-all}" # Options: all, only, none
SORT_BY="${SORT_BY:-name}" # Options: name, created, containers
TOP_N="${TOP_N:-0}" # Show top N networks (0 = all)

# ==============================================================================
# Helper Functions
# ==============================================================================

show_help() {
    cat <<EOF
${BOLD}${CYAN}DockerKit - Advanced Network Analysis${NC}

${BOLD}USAGE:${NC}
    $0 [OPTIONS]

${BOLD}OPTIONS:${NC}
    -h, --help          Show this help message
    -f, --format TYPE   Output format: table, json, csv, wide (default: table)
    -s, --sort FIELD    Sort by: name, created, containers (default: name)
    -t, --top N         Show top N networks by containers
    -i, --internal      Show only internal networks
    -e, --external      Show only external networks
    --connectivity      Container connectivity analysis
    --subnet-map        Subnet allocation mapping
    --port-map          Port mapping analysis
    --isolation         Network isolation assessment

${BOLD}EXAMPLES:${NC}
    # Show all networks with details
    $0

    # Container connectivity analysis
    $0 --connectivity

    # Subnet allocation map
    $0 --subnet-map

    # Port mapping analysis
    $0 --port-map

    # Network isolation check
    $0 --isolation

${BOLD}OUTPUT COLUMNS:${NC}
    IDX         - Index number
    NAME        - Network name
    ID          - Network ID (short)
    DRIVER      - Network driver
    SCOPE       - Network scope
    CONTAINERS  - Connected container names
    IMAGES      - Unique images of connected containers
EOF
}

# Truncation function for safe column display
trunc() { 
    local s="$1" w="$2"
    local el="…"
    [[ ${#s} -le $w ]] && printf "%s" "$s" || { printf "%.*s%s" $((w-1)) "$s" "$el"; }
}

# ==============================================================================
# Advanced Network Analysis
# ==============================================================================

get_advanced_networks_table() {
    (
        # Define column widths
        W_IDX=5; W_NAME=24; W_ID=12; W_DRIVER=10; W_SCOPE=10; W_CONTAINERS=40; W_IMAGES=50
        
        # Print header
        printf "%-${W_IDX}s %-${W_NAME}s %-${W_ID}s %-${W_DRIVER}s %-${W_SCOPE}s %-${W_CONTAINERS}s %-${W_IMAGES}s\n" \
            "IDX" "NAME" "ID" "DRIVER" "SCOPE" "CONTAINERS" "IMAGES"
        
        printf "%-${W_IDX}s %-${W_NAME}s %-${W_ID}s %-${W_DRIVER}s %-${W_SCOPE}s %-${W_CONTAINERS}s %-${W_IMAGES}s\n" \
            "-----" "------------------------" "------------" "----------" \
            "----------" "----------------------------------------" \
            "--------------------------------------------------"
        
        i=1
        
        # Process networks with improved container/image mapping
        docker_run network ls --format "{{.ID}} {{.Name}} {{.Driver}} {{.Scope}}" \
        | while IFS=$' ' read -r net_id net_name driver scope; do
            # Get container mapping
            map=$(docker_run network inspect "$net_id" -f '{{range $cid,$c := .Containers}}{{$c.Name}}:{{$cid}},{{end}}')
            
            # Extract container names
            containers=$(echo "$map" | tr ',' '\n' | awk -F: 'NF==2{print $1}' | paste -sd, -)
            [[ -z "$containers" ]] && containers="(none)"
            
            # Extract unique images from containers
            images=$(echo "$map" | tr ',' '\n' | awk -F: 'NF==2{print $2}' \
                | xargs -r -I {} docker_run inspect -f '{{.Config.Image}}' {} 2>/dev/null \
                | sort -u | paste -sd, -)
            [[ -z "$images" ]] && images="(none)"
            
            # Apply internal filter if needed
            if [[ "$SHOW_INTERNAL" == "only" ]]; then
                internal=$(docker_run network inspect "$net_id" -f '{{.Internal}}')
                [[ "$internal" != "true" ]] && continue
            elif [[ "$SHOW_INTERNAL" == "none" ]]; then
                internal=$(docker_run network inspect "$net_id" -f '{{.Internal}}')
                [[ "$internal" == "true" ]] && continue
            fi
            
            # Truncate for display
            net_name_display=$(trunc "$net_name" $W_NAME)
            net_id_display="${net_id:0:12}"
            driver_display=$(trunc "$driver" $W_DRIVER)
            scope_display=$(trunc "$scope" $W_SCOPE)
            containers_display=$(trunc "$containers" $W_CONTAINERS)
            images_display=$(trunc "$images" $W_IMAGES)
            
            printf "%-${W_IDX}s %-${W_NAME}s %-${W_ID}s %-${W_DRIVER}s %-${W_SCOPE}s %-${W_CONTAINERS}s %-${W_IMAGES}s\n" \
                "$i" "$net_name_display" "$net_id_display" "$driver_display" "$scope_display" "$containers_display" "$images_display"
            
            i=$((i+1))
        done
    )
}

# ==============================================================================
# Container Connectivity Analysis
# ==============================================================================

analyze_connectivity() {
    echo -e "${BOLD}${CYAN}Container Network Connectivity Analysis${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}\n"
    
    # Build connectivity map
    declare -A container_networks
    declare -A network_containers
    
    # Get all containers and their networks
    docker_run ps --format "{{.Names}}" | while read -r container; do
        echo -e "${BOLD}${GREEN}$container:${NC}"
        
        # Get container's IP addresses
        docker_run inspect "$container" -f '{{range $net,$conf := .NetworkSettings.Networks}}{{$net}}|{{$conf.IPAddress}}|{{$conf.IPv6Address}}{{println}}{{end}}' \
        | while IFS='|' read -r network ipv4 ipv6; do
            [[ -z "$network" ]] && continue
            
            echo -e "  ${CYAN}Network: $network${NC}"
            [[ -n "$ipv4" ]] && echo -e "    IPv4: $ipv4"
            [[ -n "$ipv6" ]] && echo -e "    IPv6: $ipv6"
            
            # Find other containers on same network
            echo -e "    ${BOLD}Can reach:${NC}"
            docker_run network inspect "$network" -f '{{range $cid,$c := .Containers}}{{$c.Name}}|{{$c.IPv4Address}}{{println}}{{end}}' \
            | while IFS='|' read -r other_container other_ip; do
                if [[ "$other_container" != "$container" ]] && [[ -n "$other_container" ]]; then
                    echo -e "      → $other_container ($other_ip)"
                fi
            done
        done
        echo ""
    done
    
    # Network isolation summary
    echo -e "${BOLD}Network Isolation Summary:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    
    # Count isolated containers
    local isolated_count=0
    docker_run ps --format "{{.Names}}" | while read -r container; do
        network_count=$(docker_run inspect "$container" -f '{{range $net,$conf := .NetworkSettings.Networks}}{{$net}}{{println}}{{end}}' | wc -l)
        if [[ $network_count -eq 1 ]]; then
            network=$(docker_run inspect "$container" -f '{{range $net,$conf := .NetworkSettings.Networks}}{{$net}}{{println}}{{end}}' | head -1)
            container_count=$(docker_run network inspect "$network" -f '{{len .Containers}}')
            if [[ $container_count -eq 1 ]]; then
                ((isolated_count++))
                echo -e "  ${YELLOW}⚠${NC} $container is isolated (only container on $network)"
            fi
        fi
    done
    
    if [[ $isolated_count -eq 0 ]]; then
        echo -e "  ${GREEN}✓${NC} No isolated containers found"
    fi
}

# ==============================================================================
# Subnet Mapping
# ==============================================================================

analyze_subnets() {
    echo -e "${BOLD}${CYAN}Docker Network Subnet Allocation${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}\n"
    
    echo -e "${BOLD}Configured Subnets:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    
    printf "${BOLD}%-25s %-20s %-20s %-15s %-10s${NC}\n" \
        "NETWORK" "SUBNET" "GATEWAY" "IP RANGE" "USED IPs"
    
    docker_run network ls --format "{{.Name}}" | while read -r network; do
        # Skip none network
        [[ "$network" == "none" ]] && continue
        
        # Get subnet configuration
        docker_run network inspect "$network" -f '{{range .IPAM.Config}}{{.Subnet}}|{{.Gateway}}|{{.IPRange}}{{println}}{{end}}' \
        | while IFS='|' read -r subnet gateway iprange; do
            [[ -z "$subnet" ]] && continue
            
            # Count used IPs
            used_ips=$(docker_run network inspect "$network" -f '{{len .Containers}}')
            
            # Calculate available IPs (simplified)
            if [[ -n "$subnet" ]]; then
                # Extract CIDR notation
                cidr="${subnet##*/}"
                total_ips=$((2 ** (32 - cidr) - 2))  # -2 for network and broadcast
                available=$((total_ips - used_ips))
            else
                total_ips="N/A"
                available="N/A"
            fi
            
            [[ -z "$gateway" ]] && gateway="auto"
            [[ -z "$iprange" ]] && iprange="full subnet"
            
            printf "%-25s %-20s %-20s %-15s %-10s\n" \
                "$network" "$subnet" "$gateway" "$iprange" "$used_ips/$total_ips"
        done
    done
    
    # IP allocation by container
    echo -e "\n${BOLD}IP Address Allocations:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    
    docker_run network ls --format "{{.Name}}" | while read -r network; do
        [[ "$network" == "none" ]] && continue
        
        container_count=$(docker_run network inspect "$network" -f '{{len .Containers}}')
        if [[ $container_count -gt 0 ]]; then
            echo -e "\n${BOLD}${CYAN}$network:${NC}"
            
            docker_run network inspect "$network" -f '{{range $cid,$c := .Containers}}{{$c.Name}}|{{$c.IPv4Address}}|{{$c.IPv6Address}}|{{$c.MacAddress}}{{println}}{{end}}' \
            | while IFS='|' read -r container ipv4 ipv6 mac; do
                echo -e "  ${GREEN}$container${NC}"
                [[ -n "$ipv4" ]] && echo -e "    IPv4: $ipv4"
                [[ -n "$ipv6" ]] && echo -e "    IPv6: $ipv6"
                [[ -n "$mac" ]] && echo -e "    MAC:  $mac"
            done
        fi
    done
    
    # Subnet conflicts check
    echo -e "\n${BOLD}Subnet Conflict Check:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    
    declare -A subnets_map
    local conflicts_found=false
    
    docker_run network ls --format "{{.Name}}" | while read -r network; do
        docker_run network inspect "$network" -f '{{range .IPAM.Config}}{{.Subnet}}{{println}}{{end}}' \
        | while read -r subnet; do
            [[ -z "$subnet" ]] && continue
            
            if [[ -n "${subnets_map[$subnet]}" ]]; then
                conflicts_found=true
                echo -e "  ${RED}✗${NC} Subnet conflict: $subnet used by both ${subnets_map[$subnet]} and $network"
            else
                subnets_map[$subnet]="$network"
            fi
        done
    done
    
    if [[ "$conflicts_found" != "true" ]]; then
        echo -e "  ${GREEN}✓${NC} No subnet conflicts detected"
    fi
}

# ==============================================================================
# Port Mapping Analysis
# ==============================================================================

analyze_ports() {
    echo -e "${BOLD}${CYAN}Docker Port Mapping Analysis${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}\n"
    
    echo -e "${BOLD}Published Ports:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    
    printf "${BOLD}%-25s %-15s %-20s %-20s %-10s${NC}\n" \
        "CONTAINER" "NETWORK" "HOST PORT" "CONTAINER PORT" "PROTOCOL"
    
    # Get all containers with published ports
    docker_run ps --format "{{.Names}}" | while read -r container; do
        # Get port mappings
        docker_run inspect "$container" -f '{{range $p,$conf := .NetworkSettings.Ports}}{{$p}}|{{range $conf}}{{.HostIp}}:{{.HostPort}}{{end}}{{println}}{{end}}' \
        | while IFS='|' read -r container_port host_binding; do
            [[ -z "$container_port" ]] && continue
            
            # Get container's primary network
            primary_network=$(docker_run inspect "$container" -f '{{range $net,$conf := .NetworkSettings.Networks}}{{$net}}{{println}}{{end}}' | head -1)
            
            if [[ -n "$host_binding" ]]; then
                # Parse host binding
                host_ip="${host_binding%%:*}"
                host_port="${host_binding##*:}"
                [[ "$host_ip" == "0.0.0.0" ]] && host_ip="all interfaces"
                
                printf "%-25s %-15s %-20s %-20s %-10s\n" \
                    "$container" "$primary_network" "$host_ip:$host_port" "$container_port" "tcp"
            fi
        done
    done
    
    # Port conflicts check
    echo -e "\n${BOLD}Port Conflict Check:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    
    declare -A port_usage
    local conflicts_found=false
    
    docker_run ps --format "{{.Names}}" | while read -r container; do
        docker_run inspect "$container" -f '{{range $p,$conf := .NetworkSettings.Ports}}{{range $conf}}{{.HostPort}}{{end}}{{println}}{{end}}' \
        | while read -r port; do
            [[ -z "$port" ]] && continue
            
            if [[ -n "${port_usage[$port]}" ]]; then
                conflicts_found=true
                echo -e "  ${RED}✗${NC} Port conflict: $port used by both ${port_usage[$port]} and $container"
            else
                port_usage[$port]="$container"
            fi
        done
    done
    
    if [[ "$conflicts_found" != "true" ]]; then
        echo -e "  ${GREEN}✓${NC} No port conflicts detected"
    fi
    
    # Exposed but not published ports
    echo -e "\n${BOLD}Exposed but Not Published:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    
    docker_run ps --format "{{.Names}}" | while read -r container; do
        exposed=$(docker_run inspect "$container" -f '{{range $p,$conf := .Config.ExposedPorts}}{{$p}} {{end}}')
        published=$(docker_run inspect "$container" -f '{{range $p,$conf := .NetworkSettings.Ports}}{{if $conf}}{{$p}} {{end}}{{end}}')
        
        unpublished=""
        for port in $exposed; do
            if ! echo "$published" | grep -q "$port"; then
                unpublished="$unpublished $port"
            fi
        done
        
        if [[ -n "$unpublished" ]]; then
            echo -e "  ${CYAN}$container:${NC}$unpublished"
        fi
    done
}

# ==============================================================================
# Network Isolation Assessment
# ==============================================================================

assess_isolation() {
    echo -e "${BOLD}${CYAN}Network Isolation Assessment${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}\n"
    
    # Check for containers on default bridge
    echo -e "${BOLD}Default Bridge Network Usage:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    
    local bridge_containers=$(docker_run network inspect bridge -f '{{range $cid,$c := .Containers}}{{$c.Name}}{{println}}{{end}}' | wc -l)
    
    if [[ $bridge_containers -gt 0 ]]; then
        echo -e "  ${YELLOW}⚠${NC} $bridge_containers containers using default bridge network:"
        docker_run network inspect bridge -f '{{range $cid,$c := .Containers}}{{$c.Name}}{{println}}{{end}}' \
        | while read -r container; do
            echo -e "    • $container"
        done
        echo -e "\n  ${CYAN}Recommendation:${NC} Use custom networks for better isolation"
    else
        echo -e "  ${GREEN}✓${NC} No containers on default bridge network"
    fi
    
    # Check for host network usage
    echo -e "\n${BOLD}Host Network Mode:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    
    local host_containers=0
    docker_run ps --format "{{.Names}}" | while read -r container; do
        network_mode=$(docker_run inspect "$container" -f '{{.HostConfig.NetworkMode}}')
        if [[ "$network_mode" == "host" ]]; then
            ((host_containers++))
            echo -e "  ${RED}✗${NC} $container using host network mode (no isolation)"
        fi
    done
    
    if [[ $host_containers -eq 0 ]]; then
        echo -e "  ${GREEN}✓${NC} No containers using host network mode"
    fi
    
    # Check for internal networks
    echo -e "\n${BOLD}Internal Networks:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    
    local internal_count=0
    docker_run network ls --format "{{.Name}}" | while read -r network; do
        internal=$(docker_run network inspect "$network" -f '{{.Internal}}')
        if [[ "$internal" == "true" ]]; then
            ((internal_count++))
            container_count=$(docker_run network inspect "$network" -f '{{len .Containers}}')
            echo -e "  ${GREEN}✓${NC} $network (internal, $container_count containers)"
        fi
    done
    
    if [[ $internal_count -eq 0 ]]; then
        echo -e "  ${CYAN}ℹ${NC} No internal networks configured"
        echo -e "    Consider using internal networks for backend services"
    fi
    
    # Check for ICC (Inter-Container Communication)
    echo -e "\n${BOLD}Inter-Container Communication (ICC):${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    
    icc_setting=$(docker_run network inspect bridge -f '{{index .Options "com.docker.network.bridge.enable_icc"}}' 2>/dev/null)
    
    if [[ "$icc_setting" == "false" ]]; then
        echo -e "  ${GREEN}✓${NC} ICC disabled on default bridge (good security practice)"
    else
        echo -e "  ${YELLOW}⚠${NC} ICC enabled on default bridge (default setting)"
        echo -e "    Containers can communicate freely on bridge network"
    fi
    
    # Network segmentation summary
    echo -e "\n${BOLD}Network Segmentation Summary:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    
    local custom_networks=$(docker_run network ls --format "{{.Driver}}" | grep -c "bridge" | awk '{print $1-1}')  # -1 for default bridge
    local total_containers=$(docker_run ps -q | wc -l)
    
    echo -e "  Custom Networks:     ${BOLD}$custom_networks${NC}"
    echo -e "  Total Containers:    ${BOLD}$total_containers${NC}"
    
    if [[ $custom_networks -gt 0 ]] && [[ $total_containers -gt 0 ]]; then
        local avg_containers_per_network=$((total_containers / (custom_networks + 1)))  # +1 for default bridge
        echo -e "  Avg Containers/Net:  ${BOLD}$avg_containers_per_network${NC}"
        
        if [[ $avg_containers_per_network -gt 10 ]]; then
            echo -e "\n  ${YELLOW}⚠${NC} Consider more network segmentation for large deployments"
        else
            echo -e "\n  ${GREEN}✓${NC} Good network segmentation"
        fi
    fi
}

# ==============================================================================
# JSON Output
# ==============================================================================

get_networks_json() {
    echo "["
    local first=true
    
    docker_run network ls --format "{{.ID}}" | while read -r id; do
        [[ "$first" == "true" ]] && first=false || echo ","
        
        # Get full network details
        docker_run network inspect "$id" | jq -c '.[0] | {
            id: .Id,
            name: .Name,
            driver: .Driver,
            scope: .Scope,
            internal: .Internal,
            created: .Created,
            ipam: .IPAM,
            containers: .Containers,
            options: .Options,
            labels: .Labels
        }'
    done
    
    echo "]"
}

# ==============================================================================
# CSV Output
# ==============================================================================

get_networks_csv() {
    echo "Name,ID,Driver,Scope,Internal,Created,Subnet,Gateway,Containers"
    
    docker_run network ls --format "{{.ID}}" | while read -r id; do
        # Get network details
        name=$(docker_run network inspect -f '{{.Name}}' "$id")
        driver=$(docker_run network inspect -f '{{.Driver}}' "$id")
        scope=$(docker_run network inspect -f '{{.Scope}}' "$id")
        internal=$(docker_run network inspect -f '{{.Internal}}' "$id")
        created=$(docker_run network inspect -f '{{.Created}}' "$id")
        subnet=$(docker_run network inspect -f '{{range .IPAM.Config}}{{.Subnet}}{{end}}' "$id")
        gateway=$(docker_run network inspect -f '{{range .IPAM.Config}}{{.Gateway}}{{end}}' "$id")
        container_count=$(docker_run network inspect -f '{{len .Containers}}' "$id")
        
        echo "$name,$id,$driver,$scope,$internal,$created,\"$subnet\",\"$gateway\",$container_count"
    done
}

# ==============================================================================
# Main
# ==============================================================================

main() {
    local connectivity_mode=false
    local subnet_map_mode=false
    local port_map_mode=false
    local isolation_mode=false
    
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
            -i|--internal)
                SHOW_INTERNAL="only"
                shift
                ;;
            -e|--external)
                SHOW_INTERNAL="none"
                shift
                ;;
            --connectivity)
                connectivity_mode=true
                shift
                ;;
            --subnet-map)
                subnet_map_mode=true
                shift
                ;;
            --port-map)
                port_map_mode=true
                shift
                ;;
            --isolation)
                isolation_mode=true
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
    
    if ! docker_run info &>/dev/null; then
        echo -e "${RED}Error: Docker daemon is not running${NC}"
        exit 1
    fi
    
    # Execute requested analysis
    if [[ "$connectivity_mode" == "true" ]]; then
        analyze_connectivity
    elif [[ "$subnet_map_mode" == "true" ]]; then
        analyze_subnets
    elif [[ "$port_map_mode" == "true" ]]; then
        analyze_ports
    elif [[ "$isolation_mode" == "true" ]]; then
        assess_isolation
    else
        # Default: show network table
        case "$OUTPUT_FORMAT" in
            json)
                get_networks_json
                ;;
            csv)
                get_networks_csv
                ;;
            *)
                echo -e "${BOLD}${CYAN}Advanced Docker Network Analysis${NC}"
                echo -e "${BLUE}════════════════════════════════════════════════════════════════════${NC}\n"
                get_advanced_networks_table
                
                # Summary
                echo -e "\n${BOLD}Summary:${NC}"
                local total=$(docker_run network ls -q | wc -l)
                local custom=$(docker_run network ls --filter driver=bridge --format "{{.Name}}" | grep -v "^bridge$" | wc -l)
                local internal=$(docker_run network ls --format "{{.Name}}|{{.Internal}}" | grep "true" | wc -l)
                
                echo -e "  Total Networks:      ${BOLD}$total${NC}"
                echo -e "  Custom Networks:     ${GREEN}$custom${NC}"
                echo -e "  Internal Networks:   ${CYAN}$internal${NC}"
                echo -e "  Default Networks:    $((total - custom))"
                
                echo -e "\n  ${CYAN}Tip:${NC} Run with --connectivity, --subnet-map, or --isolation for detailed analysis"
                ;;
        esac
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi