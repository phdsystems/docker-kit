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

Search and filter Docker networks with advanced options.

Options:
    -n, --name PATTERN     Search by network name
    -d, --driver DRIVER    Filter by driver (bridge, host, overlay, macvlan)
    -l, --label LABEL      Filter by label
    --scope SCOPE          Filter by scope (local, global, swarm)
    --internal             Show only internal networks
    --no-internal          Show only external networks
    -c, --container NAME   Find networks used by specific container
    --subnet SUBNET        Search by subnet (e.g., 172.17.0.0/16)
    --gateway GATEWAY      Search by gateway IP
    --unused               Show networks with no containers
    --in-use               Show networks with containers
    -f, --format FORMAT    Output format (json, table, names-only, detailed)
    --inspect NAME         Show detailed information about a network
    --trace                Show network connectivity paths
    -h, --help             Show this help message

Examples:
    $(basename "$0") bridge             # Search for bridge networks
    $(basename "$0") -d overlay         # Show all overlay networks
    $(basename "$0") --unused           # Show unused networks
    $(basename "$0") -c nginx           # Networks used by nginx container
    $(basename "$0") --subnet 172.17    # Networks with matching subnet
    $(basename "$0") --trace            # Show network connectivity

EOF
}

search_networks() {
    local search_term="$1"
    local filters=""
    local format_opt="table {{.Name}}\t{{.Driver}}\t{{.Scope}}\t{{.Internal}}"
    
    if [[ -n "$FILTER_NAME" ]]; then
        filters="$filters --filter name=$FILTER_NAME"
    fi
    
    if [[ -n "$FILTER_DRIVER" ]]; then
        filters="$filters --filter driver=$FILTER_DRIVER"
    fi
    
    if [[ -n "$FILTER_LABEL" ]]; then
        filters="$filters --filter label=$FILTER_LABEL"
    fi
    
    if [[ -n "$FILTER_SCOPE" ]]; then
        filters="$filters --filter scope=$FILTER_SCOPE"
    fi
    
    if [[ "$SHOW_INTERNAL" == "true" ]]; then
        filters="$filters --filter internal=true"
    elif [[ "$SHOW_EXTERNAL" == "true" ]]; then
        filters="$filters --filter internal=false"
    fi
    
    case "$OUTPUT_FORMAT" in
        json)
            format_opt="json"
            ;;
        names-only)
            format_opt="table {{.Name}}"
            ;;
        detailed)
            format_opt="table {{.Name}}\t{{.Driver}}\t{{.Scope}}\t{{.Internal}}\t{{.IPv6}}\t{{.CreatedAt}}"
            ;;
    esac
    
    echo -e "${BLUE}🔍 Searching networks...${NC}"
    
    if [[ -n "$search_term" ]] && [[ -z "$filters" ]]; then
        docker_run network ls --format "$format_opt" | grep -i "$search_term" || {
            echo -e "${YELLOW}No networks found matching '$search_term'${NC}"
            return 1
        }
    else
        docker_run network ls $filters --format "$format_opt"
    fi
}

find_networks_by_container() {
    local container="$1"
    echo -e "${BLUE}🔍 Networks used by container '$container':${NC}"
    
    if ! docker_run ps -a --format "{{.Names}}" | grep -q "^$container$"; then
        echo -e "${RED}Container '$container' not found${NC}"
        return 1
    fi
    
    docker_run inspect "$container" --format '{{range $key, $value := .NetworkSettings.Networks}}{{$key}}{{println}}{{end}}' || {
        echo -e "${YELLOW}No networks found for container '$container'${NC}"
        return 1
    }
    
    echo -e "\n${BLUE}Network details:${NC}"
    docker_run inspect "$container" --format '{{range $key, $value := .NetworkSettings.Networks}}Network: {{$key}}
  IP Address: {{$value.IPAddress}}
  Gateway: {{$value.Gateway}}
  MAC Address: {{$value.MacAddress}}
{{end}}'
}

find_networks_by_subnet() {
    local subnet="$1"
    echo -e "${BLUE}🔍 Networks with subnet matching '$subnet':${NC}"
    
    for network in $(docker_run network ls -q); do
        network_info=$(docker_run network inspect "$network" --format '{{.Name}}:{{range .IPAM.Config}}{{.Subnet}}{{end}}')
        if echo "$network_info" | grep -q "$subnet"; then
            echo "  $network_info"
        fi
    done
}

find_unused_networks() {
    echo -e "${BLUE}🔍 Unused networks (no containers):${NC}"
    
    for network in $(docker_run network ls -q); do
        network_name=$(docker_run network inspect "$network" --format '{{.Name}}')
        container_count=$(docker_run network inspect "$network" --format '{{len .Containers}}')
        
        if [[ "$container_count" -eq 0 ]] && [[ "$network_name" != "bridge" ]] && \
           [[ "$network_name" != "host" ]] && [[ "$network_name" != "none" ]]; then
            driver=$(docker_run network inspect "$network" --format '{{.Driver}}')
            echo "  $network_name (driver: $driver)"
        fi
    done
}

find_networks_in_use() {
    echo -e "${BLUE}🔍 Networks in use:${NC}"
    
    for network in $(docker_run network ls -q); do
        network_name=$(docker_run network inspect "$network" --format '{{.Name}}')
        containers=$(docker_run network inspect "$network" --format '{{range .Containers}}{{.Name}} {{end}}')
        
        if [[ -n "$containers" ]]; then
            container_count=$(docker_run network inspect "$network" --format '{{len .Containers}}')
            echo -e "${GREEN}$network_name${NC} ($container_count containers)"
            echo "  Containers: $containers"
        fi
    done
}

inspect_network() {
    local network="$1"
    echo -e "${BLUE}🔍 Inspecting network '$network':${NC}"
    
    if ! docker_run network ls -q | grep -q "^$network$"; then
        echo -e "${RED}Network '$network' not found${NC}"
        return 1
    fi
    
    docker_run network inspect "$network" | jq '.[0]' 2>/dev/null || docker_run network inspect "$network"
    
    echo -e "\n${BLUE}Containers on this network:${NC}"
    docker_run network inspect "$network" --format '{{range .Containers}}  - {{.Name}} ({{.IPv4Address}})
{{end}}'
}

trace_network_connectivity() {
    echo -e "${BLUE}🔗 Network Connectivity Map:${NC}"
    
    declare -A network_containers
    
    for network in $(docker_run network ls -q); do
        network_name=$(docker_run network inspect "$network" --format '{{.Name}}')
        containers=$(docker_run network inspect "$network" --format '{{range .Containers}}{{.Name}},{{end}}')
        
        if [[ -n "$containers" ]]; then
            network_containers["$network_name"]="$containers"
        fi
    done
    
    for network in "${!network_containers[@]}"; do
        echo -e "\n${GREEN}Network: $network${NC}"
        driver=$(docker_run network inspect "$network" --format '{{.Driver}}')
        internal=$(docker_run network inspect "$network" --format '{{.Internal}}')
        subnet=$(docker_run network inspect "$network" --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}')
        
        echo "  Driver: $driver"
        echo "  Internal: $internal"
        [[ -n "$subnet" ]] && echo "  Subnet: $subnet"
        
        echo "  Containers:"
        IFS=',' read -ra containers <<< "${network_containers[$network]}"
        for container in "${containers[@]}"; do
            if [[ -n "$container" ]]; then
                ip=$(docker_run inspect "$container" --format "{{.NetworkSettings.Networks.$network.IPAddress}}" 2>/dev/null)
                echo "    - $container ($ip)"
            fi
        done
    done
    
    echo -e "\n${BLUE}Container multi-network connections:${NC}"
    for container in $(docker_run ps -q); do
        name=$(docker_run inspect "$container" --format '{{.Name}}' | sed 's/\///')
        network_count=$(docker_run inspect "$container" --format '{{len .NetworkSettings.Networks}}')
        
        if [[ $network_count -gt 1 ]]; then
            echo "  $name connects $network_count networks:"
            docker_run inspect "$container" --format '{{range $key, $value := .NetworkSettings.Networks}}    - {{$key}} ({{$value.IPAddress}})
{{end}}'
        fi
    done
}

analyze_networks() {
    echo -e "${BLUE}📊 Network Statistics:${NC}"
    
    local total=$(docker_run network ls -q | wc -l)
    local custom=$(docker_run network ls -q --filter type=custom | wc -l 2>/dev/null || echo "N/A")
    
    echo "  Total networks: $total"
    echo "  Custom networks: $custom"
    echo ""
    
    echo -e "${BLUE}Networks by driver:${NC}"
    docker_run network ls --format "{{.Driver}}" | sort | uniq -c | sort -rn
    echo ""
    
    echo -e "${BLUE}Network IP allocation:${NC}"
    for network in $(docker_run network ls -q); do
        network_name=$(docker_run network inspect "$network" --format '{{.Name}}')
        subnet=$(docker_run network inspect "$network" --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}')
        container_count=$(docker_run network inspect "$network" --format '{{len .Containers}}')
        
        if [[ -n "$subnet" ]]; then
            echo "  $network_name: $subnet ($container_count containers)"
        fi
    done
}

cleanup_unused_networks() {
    echo -e "${BLUE}🧹 Cleaning up unused networks...${NC}"
    
    unused_count=0
    for network in $(docker_run network ls -q); do
        network_name=$(docker_run network inspect "$network" --format '{{.Name}}')
        container_count=$(docker_run network inspect "$network" --format '{{len .Containers}}')
        
        if [[ "$container_count" -eq 0 ]] && [[ "$network_name" != "bridge" ]] && \
           [[ "$network_name" != "host" ]] && [[ "$network_name" != "none" ]]; then
            ((unused_count++))
        fi
    done
    
    if [[ $unused_count -eq 0 ]]; then
        echo -e "${GREEN}No unused networks to clean${NC}"
        return 0
    fi
    
    echo "Found $unused_count unused network(s)"
    read -p "Remove all unused networks? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker_run network prune -f
        echo -e "${GREEN}✅ Unused networks removed${NC}"
    else
        echo "Cleanup cancelled"
    fi
}

FILTER_NAME=""
FILTER_DRIVER=""
FILTER_LABEL=""
FILTER_SCOPE=""
SHOW_INTERNAL=false
SHOW_EXTERNAL=false
FILTER_CONTAINER=""
SUBNET_FILTER=""
GATEWAY_FILTER=""
SHOW_UNUSED=false
SHOW_IN_USE=false
OUTPUT_FORMAT="table"
INSPECT_NETWORK=""
TRACE_MODE=false
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
        --scope)
            FILTER_SCOPE="$2"
            shift 2
            ;;
        --internal)
            SHOW_INTERNAL=true
            shift
            ;;
        --no-internal)
            SHOW_EXTERNAL=true
            shift
            ;;
        -c|--container)
            FILTER_CONTAINER="$2"
            shift 2
            ;;
        --subnet)
            SUBNET_FILTER="$2"
            shift 2
            ;;
        --gateway)
            GATEWAY_FILTER="$2"
            shift 2
            ;;
        --unused)
            SHOW_UNUSED=true
            shift
            ;;
        --in-use)
            SHOW_IN_USE=true
            shift
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        --inspect)
            INSPECT_NETWORK="$2"
            shift 2
            ;;
        --trace)
            TRACE_MODE=true
            shift
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
    cleanup_unused_networks
elif [[ "$TRACE_MODE" == "true" ]]; then
    trace_network_connectivity
elif [[ -n "$INSPECT_NETWORK" ]]; then
    inspect_network "$INSPECT_NETWORK"
elif [[ -n "$FILTER_CONTAINER" ]]; then
    find_networks_by_container "$FILTER_CONTAINER"
elif [[ -n "$SUBNET_FILTER" ]]; then
    find_networks_by_subnet "$SUBNET_FILTER"
elif [[ "$SHOW_UNUSED" == "true" ]]; then
    find_unused_networks
elif [[ "$SHOW_IN_USE" == "true" ]]; then
    find_networks_in_use
elif [[ -n "$SEARCH_TERM" ]] || [[ -n "$FILTER_NAME" ]] || [[ -n "$FILTER_DRIVER" ]] || \
     [[ -n "$FILTER_SCOPE" ]] || [[ "$SHOW_INTERNAL" == "true" ]] || [[ "$SHOW_EXTERNAL" == "true" ]]; then
    search_networks "$SEARCH_TERM"
else
    analyze_networks
fi