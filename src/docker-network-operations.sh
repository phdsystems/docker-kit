#!/bin/bash

# DockerKit Network Operations
# Provides create, remove, connect, disconnect operations for networks

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'

# Source Docker wrapper for sudo handling
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/docker-wrapper.sh"
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Check Docker command with sudo support
if docker info &>/dev/null 2>&1; then
    DOCKER_CMD="docker"
elif sudo docker info &>/dev/null 2>&1; then
    DOCKER_CMD="sudo docker"
else
    echo -e "${RED}Error: Docker is not accessible${NC}"
    exit 1
fi

# Default values
ACTION=""
NETWORK=""
CONTAINER=""
DRIVER="bridge"
SUBNET=""
IP_RANGE=""
GATEWAY=""
IPV6=false
INTERNAL=false
ATTACHABLE=false
LABELS=()
OPTIONS=()
FORCE=false
ALIAS=""
IP=""

# Show help
show_help() {
    cat << EOF
DockerKit Network Operations

USAGE:
    $(basename "$0") <action> [network] [options]

ACTIONS:
    create      Create a new network
    remove|rm   Remove network(s)
    connect     Connect container to network
    disconnect  Disconnect container from network
    inspect     Inspect network details
    list|ls     List networks
    prune       Remove unused networks

CREATE OPTIONS:
    -d, --driver DRIVER     Network driver (bridge, overlay, macvlan, none)
    --subnet SUBNET         Subnet in CIDR format (e.g., 172.20.0.0/16)
    --ip-range RANGE        IP range for subnet
    --gateway GATEWAY       IPv4 or IPv6 gateway
    --ipv6                  Enable IPv6
    --internal              Create internal network
    --attachable            Enable manual attachment (swarm mode)
    -o, --opt KEY=VALUE     Driver options
    -l, --label KEY=VALUE   Set metadata labels

CONNECT OPTIONS:
    --ip IP                 Specify IP address for container
    --alias ALIAS           Add network-scoped alias
    --link CONTAINER        Add link to another container

REMOVE OPTIONS:
    -f, --force             Force removal

LIST OPTIONS:
    -f, --filter FILTER     Filter networks (e.g., driver=bridge)
    -q, --quiet             Only display network IDs
    --format FORMAT         Format output using Go template

EXAMPLES:
    # Create a basic bridge network
    $(basename "$0") create my-network

    # Create network with custom subnet
    $(basename "$0") create my-net --subnet 172.25.0.0/16 --gateway 172.25.0.1

    # Create overlay network for swarm
    $(basename "$0") create my-overlay --driver overlay --attachable

    # Create macvlan network
    $(basename "$0") create my-macvlan --driver macvlan -o parent=eth0

    # Connect container to network
    $(basename "$0") connect my-network my-container

    # Connect with specific IP
    $(basename "$0") connect my-network my-container --ip 172.25.0.10

    # Connect with alias
    $(basename "$0") connect my-network my-container --alias web-server

    # Disconnect container from network
    $(basename "$0") disconnect my-network my-container

    # Remove a network
    $(basename "$0") remove my-old-network

    # List all networks
    $(basename "$0") list

    # List bridge networks only
    $(basename "$0") list --filter driver=bridge

    # Inspect network
    $(basename "$0") inspect my-network

    # Prune unused networks
    $(basename "$0") prune

EOF
}

# Create network
create_network() {
    if [[ -z "$NETWORK" ]]; then
        echo -e "${RED}Error: No network name specified${NC}"
        exit 1
    fi
    
    local create_args=""
    
    if [[ -n "$DRIVER" ]]; then
        create_args="$create_args --driver $DRIVER"
    fi
    
    if [[ -n "$SUBNET" ]]; then
        create_args="$create_args --subnet $SUBNET"
    fi
    
    if [[ -n "$IP_RANGE" ]]; then
        create_args="$create_args --ip-range $IP_RANGE"
    fi
    
    if [[ -n "$GATEWAY" ]]; then
        create_args="$create_args --gateway $GATEWAY"
    fi
    
    if [[ "$IPV6" == "true" ]]; then
        create_args="$create_args --ipv6"
    fi
    
    if [[ "$INTERNAL" == "true" ]]; then
        create_args="$create_args --internal"
    fi
    
    if [[ "$ATTACHABLE" == "true" ]]; then
        create_args="$create_args --attachable"
    fi
    
    for label in "${LABELS[@]}"; do
        create_args="$create_args --label $label"
    done
    
    for option in "${OPTIONS[@]}"; do
        create_args="$create_args --opt $option"
    done
    
    echo -e "${CYAN}Creating network: $NETWORK${NC}"
    echo -e "${CYAN}Driver: $DRIVER${NC}"
    
    if [[ -n "$SUBNET" ]]; then
        echo -e "${CYAN}Subnet: $SUBNET${NC}"
    fi
    
    if $DOCKER_CMD network create $create_args "$NETWORK"; then
        echo -e "${GREEN}✓ Network created successfully${NC}"
        
        # Show network details
        echo -e "\n${CYAN}Network details:${NC}"
        $DOCKER_CMD network inspect "$NETWORK" | jq -r '.[0] | {
            Name: .Name,
            Driver: .Driver,
            Scope: .Scope,
            Internal: .Internal,
            IPv6: .EnableIPv6,
            IPAM: .IPAM.Config,
            Containers: (.Containers | length)
        }' 2>/dev/null || $DOCKER_CMD network inspect "$NETWORK"
    else
        echo -e "${RED}✗ Failed to create network${NC}"
        exit 1
    fi
}

# Remove network
remove_network() {
    if [[ -z "$NETWORK" ]]; then
        echo -e "${RED}Error: No network specified${NC}"
        exit 1
    fi
    
    # Check if network is in use
    local containers
    containers=$($DOCKER_CMD network inspect "$NETWORK" --format '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null || true)
    
    if [[ -n "$containers" ]] && [[ "$FORCE" != "true" ]]; then
        echo -e "${YELLOW}Warning: Network is connected to containers:${NC}"
        echo "$containers"
        read -p "Disconnect and remove? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${RED}Operation cancelled${NC}"
            exit 1
        fi
        
        # Disconnect all containers
        for container in $containers; do
            echo -e "${CYAN}Disconnecting $container...${NC}"
            $DOCKER_CMD network disconnect "$NETWORK" "$container" 2>/dev/null || true
        done
    fi
    
    echo -e "${CYAN}Removing network: $NETWORK${NC}"
    
    if $DOCKER_CMD network rm "$NETWORK"; then
        echo -e "${GREEN}✓ Network removed successfully${NC}"
    else
        echo -e "${RED}✗ Failed to remove network${NC}"
        exit 1
    fi
}

# Connect container to network
connect_network() {
    if [[ -z "$NETWORK" ]] || [[ -z "$CONTAINER" ]]; then
        echo -e "${RED}Error: Network and container required${NC}"
        echo "Usage: $(basename "$0") connect <network> <container>"
        exit 1
    fi
    
    # Check if network exists
    if ! $DOCKER_CMD network inspect "$NETWORK" &>/dev/null; then
        echo -e "${RED}Error: Network '$NETWORK' not found${NC}"
        exit 1
    fi
    
    # Check if container exists
    if ! $DOCKER_CMD inspect "$CONTAINER" &>/dev/null; then
        echo -e "${RED}Error: Container '$CONTAINER' not found${NC}"
        exit 1
    fi
    
    # Check if already connected
    if $DOCKER_CMD network inspect "$NETWORK" --format '{{range .Containers}}{{.Name}} {{end}}' | grep -q "$CONTAINER"; then
        echo -e "${YELLOW}Container is already connected to this network${NC}"
        exit 0
    fi
    
    local connect_args=""
    
    if [[ -n "$IP" ]]; then
        connect_args="$connect_args --ip $IP"
    fi
    
    if [[ -n "$ALIAS" ]]; then
        connect_args="$connect_args --alias $ALIAS"
    fi
    
    echo -e "${CYAN}Connecting container $CONTAINER to network $NETWORK${NC}"
    
    if [[ -n "$IP" ]]; then
        echo -e "${CYAN}IP: $IP${NC}"
    fi
    
    if [[ -n "$ALIAS" ]]; then
        echo -e "${CYAN}Alias: $ALIAS${NC}"
    fi
    
    if $DOCKER_CMD network connect $connect_args "$NETWORK" "$CONTAINER"; then
        echo -e "${GREEN}✓ Container connected successfully${NC}"
        
        # Show connection details
        echo -e "\n${CYAN}Connection details:${NC}"
        $DOCKER_CMD inspect "$CONTAINER" --format "{{range .NetworkSettings.Networks}}{{if eq .NetworkID \"$($DOCKER_CMD network inspect "$NETWORK" -f '{{.Id}}')\"}}IP: {{.IPAddress}}\nGateway: {{.Gateway}}\nMAC: {{.MacAddress}}{{end}}{{end}}"
    else
        echo -e "${RED}✗ Failed to connect container${NC}"
        exit 1
    fi
}

# Disconnect container from network
disconnect_network() {
    if [[ -z "$NETWORK" ]] || [[ -z "$CONTAINER" ]]; then
        echo -e "${RED}Error: Network and container required${NC}"
        echo "Usage: $(basename "$0") disconnect <network> <container>"
        exit 1
    fi
    
    # Check if connected
    if ! $DOCKER_CMD network inspect "$NETWORK" --format '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null | grep -q "$CONTAINER"; then
        echo -e "${YELLOW}Container is not connected to this network${NC}"
        exit 0
    fi
    
    echo -e "${CYAN}Disconnecting container $CONTAINER from network $NETWORK${NC}"
    
    local disconnect_args=""
    
    if [[ "$FORCE" == "true" ]]; then
        disconnect_args="$disconnect_args -f"
    fi
    
    if $DOCKER_CMD network disconnect $disconnect_args "$NETWORK" "$CONTAINER"; then
        echo -e "${GREEN}✓ Container disconnected successfully${NC}"
    else
        echo -e "${RED}✗ Failed to disconnect container${NC}"
        exit 1
    fi
}

# Inspect network
inspect_network() {
    if [[ -z "$NETWORK" ]]; then
        echo -e "${RED}Error: No network specified${NC}"
        exit 1
    fi
    
    echo -e "${CYAN}Inspecting network: $NETWORK${NC}"
    
    $DOCKER_CMD network inspect "$NETWORK" | jq '.' 2>/dev/null || $DOCKER_CMD network inspect "$NETWORK"
}

# List networks
list_networks() {
    local list_args=""
    
    if [[ -n "$FILTER" ]]; then
        list_args="$list_args -f $FILTER"
    fi
    
    if [[ "$QUIET" == "true" ]]; then
        list_args="$list_args -q"
    fi
    
    if [[ -n "$FORMAT" ]]; then
        list_args="$list_args --format \"$FORMAT\""
    fi
    
    echo -e "${CYAN}Listing networks...${NC}"
    
    if [[ "$QUIET" == "true" ]]; then
        $DOCKER_CMD network ls $list_args
    else
        # Show enhanced network list
        echo -e "${CYAN}NETWORK ID     NAME                DRIVER    SCOPE     CONTAINERS  SUBNET${NC}"
        echo -e "${CYAN}──────────────────────────────────────────────────────────────────────────────${NC}"
        
        while IFS= read -r network_id; do
            if [[ -n "$network_id" ]]; then
                local info
                info=$($DOCKER_CMD network inspect "$network_id" --format '{{.Name}}|{{.Driver}}|{{.Scope}}|{{len .Containers}}|{{if .IPAM.Config}}{{(index .IPAM.Config 0).Subnet}}{{else}}N/A{{end}}' 2>/dev/null || echo "||||")
                
                IFS='|' read -r name driver scope containers subnet <<< "$info"
                
                printf "%-14s %-20s %-9s %-9s %-11s %s\n" \
                    "${network_id:0:12}" "$name" "$driver" "$scope" "$containers" "$subnet"
            fi
        done < <($DOCKER_CMD network ls -q $list_args)
    fi
}

# Prune networks
prune_networks() {
    echo -e "${CYAN}Pruning unused networks...${NC}"
    
    local prune_args=""
    
    if [[ "$FORCE" == "true" ]]; then
        prune_args="$prune_args -f"
    fi
    
    if [[ "$FORCE" != "true" ]]; then
        # Show what will be removed
        echo -e "${YELLOW}The following networks will be removed:${NC}"
        $DOCKER_CMD network ls --filter "dangling=true" --format "table {{.ID}}\t{{.Name}}\t{{.Driver}}"
        
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${RED}Operation cancelled${NC}"
            exit 1
        fi
        
        prune_args="$prune_args -f"
    fi
    
    local result
    result=$($DOCKER_CMD network prune $prune_args)
    
    echo "$result"
    echo -e "${GREEN}✓ Network pruning complete${NC}"
}

# Parse arguments
QUIET=false
FORMAT=""
FILTER=""

while [[ $# -gt 0 ]]; do
    case $1 in
        create|remove|rm|connect|disconnect|inspect|list|ls|prune)
            ACTION="$1"
            if [[ "$ACTION" == "rm" ]]; then
                ACTION="remove"
            elif [[ "$ACTION" == "ls" ]]; then
                ACTION="list"
            fi
            shift
            if [[ $# -gt 0 ]] && [[ ! "$1" =~ ^- ]]; then
                if [[ "$ACTION" == "connect" ]] || [[ "$ACTION" == "disconnect" ]]; then
                    NETWORK="$1"
                    shift
                    if [[ $# -gt 0 ]] && [[ ! "$1" =~ ^- ]]; then
                        CONTAINER="$1"
                        shift
                    fi
                else
                    NETWORK="$1"
                    shift
                fi
            fi
            ;;
        -d|--driver)
            DRIVER="$2"
            shift 2
            ;;
        --subnet)
            SUBNET="$2"
            shift 2
            ;;
        --ip-range)
            IP_RANGE="$2"
            shift 2
            ;;
        --gateway)
            GATEWAY="$2"
            shift 2
            ;;
        --ipv6)
            IPV6=true
            shift
            ;;
        --internal)
            INTERNAL=true
            shift
            ;;
        --attachable)
            ATTACHABLE=true
            shift
            ;;
        -o|--opt)
            OPTIONS+=("$2")
            shift 2
            ;;
        -l|--label)
            LABELS+=("$2")
            shift 2
            ;;
        --ip)
            IP="$2"
            shift 2
            ;;
        --alias)
            ALIAS="$2"
            shift 2
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        --filter)
            FILTER="$2"
            shift 2
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        --format)
            FORMAT="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            if [[ -z "$NETWORK" ]]; then
                NETWORK="$1"
            elif [[ -z "$CONTAINER" ]]; then
                CONTAINER="$1"
            fi
            shift
            ;;
    esac
done

# Execute action
case "$ACTION" in
    create)
        create_network
        ;;
    remove)
        remove_network
        ;;
    connect)
        connect_network
        ;;
    disconnect)
        disconnect_network
        ;;
    inspect)
        inspect_network
        ;;
    list)
        list_networks
        ;;
    prune)
        prune_networks
        ;;
    *)
        echo -e "${RED}Error: No action specified${NC}"
        show_help
        exit 1
        ;;
esac