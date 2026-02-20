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

Search and filter Docker containers with advanced options.

Options:
    -n, --name PATTERN     Search by container name
    -i, --image IMAGE      Filter by image name
    -s, --status STATUS    Filter by status (running, exited, paused, created)
    -l, --label LABEL      Filter by label
    -p, --port PORT        Find containers exposing specific port
    --network NETWORK      Filter by network
    --volume VOLUME        Filter by mounted volume
    --since ID/NAME        Show containers created since specified container
    --before ID/NAME       Show containers created before specified container
    -a, --all              Show all containers (default shows only running)
    --health STATUS        Filter by health status (healthy, unhealthy, none)
    -f, --format FORMAT    Output format (json, table, id-only, names)
    --stats                Show resource usage statistics
    -h, --help             Show this help message

Examples:
    $(basename "$0") nginx              # Search for nginx containers
    $(basename "$0") -s running         # Show all running containers
    $(basename "$0") -p 80              # Containers exposing port 80
    $(basename "$0") --network bridge   # Containers on bridge network
    $(basename "$0") --stats            # Show container resource usage
    $(basename "$0") -i redis -s exited # Exited Redis containers

EOF
}

search_containers() {
    local search_term="$1"
    local filters=""
    local format_opt="table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
    local show_all=""
    
    if [[ "$SHOW_ALL" == "true" ]]; then
        show_all="-a"
    fi
    
    if [[ -n "$FILTER_NAME" ]]; then
        filters="$filters --filter name=$FILTER_NAME"
    fi
    
    if [[ -n "$FILTER_IMAGE" ]]; then
        filters="$filters --filter ancestor=$FILTER_IMAGE"
    fi
    
    if [[ -n "$FILTER_STATUS" ]]; then
        filters="$filters --filter status=$FILTER_STATUS"
    fi
    
    if [[ -n "$FILTER_LABEL" ]]; then
        filters="$filters --filter label=$FILTER_LABEL"
    fi
    
    if [[ -n "$FILTER_PORT" ]]; then
        filters="$filters --filter expose=$FILTER_PORT"
    fi
    
    if [[ -n "$FILTER_NETWORK" ]]; then
        filters="$filters --filter network=$FILTER_NETWORK"
    fi
    
    if [[ -n "$FILTER_VOLUME" ]]; then
        filters="$filters --filter volume=$FILTER_VOLUME"
    fi
    
    if [[ -n "$FILTER_HEALTH" ]]; then
        filters="$filters --filter health=$FILTER_HEALTH"
    fi
    
    if [[ -n "$SINCE_CONTAINER" ]]; then
        filters="$filters --filter since=$SINCE_CONTAINER"
    fi
    
    if [[ -n "$BEFORE_CONTAINER" ]]; then
        filters="$filters --filter before=$BEFORE_CONTAINER"
    fi
    
    case "$OUTPUT_FORMAT" in
        json)
            format_opt="json"
            ;;
        id-only)
            format_opt="table {{.ID}}"
            ;;
        names)
            format_opt="table {{.Names}}"
            ;;
    esac
    
    echo -e "${BLUE}🔍 Searching containers...${NC}"
    
    if [[ -n "$search_term" ]] && [[ -z "$filters" ]]; then
        docker_run ps $show_all --format "$format_opt" | grep -i "$search_term" || {
            echo -e "${YELLOW}No containers found matching '$search_term'${NC}"
            return 1
        }
    else
        docker_run ps $show_all $filters --format "$format_opt"
    fi
}

show_container_stats() {
    echo -e "${BLUE}📊 Container Resource Usage:${NC}"
    docker_run stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
}

analyze_containers() {
    echo -e "${BLUE}📊 Container Statistics:${NC}"
    
    local total=$(docker_run ps -aq | wc -l)
    local running=$(docker_run ps -q | wc -l)
    local exited=$(docker_run ps -aq --filter status=exited | wc -l)
    local paused=$(docker_run ps -aq --filter status=paused | wc -l)
    
    echo "  Total containers: $total"
    echo "  Running: $running"
    echo "  Exited: $exited"
    echo "  Paused: $paused"
    echo ""
    
    if [[ $running -gt 0 ]]; then
        echo -e "${BLUE}Running containers by image:${NC}"
        docker_run ps --format "{{.Image}}" | sort | uniq -c | sort -rn | head -10
        echo ""
    fi
    
    echo -e "${BLUE}Container networks:${NC}"
    for container in $(docker_run ps -q); do
        name=$(docker_run inspect -f '{{.Name}}' $container | sed 's/\///')
        networks=$(docker_run inspect -f '{{range $key, $value := .NetworkSettings.Networks}}{{$key}} {{end}}' $container)
        echo "  $name: $networks"
    done
}

find_containers_by_port() {
    local port="$1"
    echo -e "${BLUE}🔍 Containers exposing port $port:${NC}"
    
    docker_run ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}" | grep -E "(:$port->|:$port/)" || {
        echo -e "${YELLOW}No containers found exposing port $port${NC}"
        return 1
    }
}

find_containers_by_volume() {
    local volume="$1"
    echo -e "${BLUE}🔍 Containers using volume '$volume':${NC}"
    
    for container in $(docker_run ps -aq); do
        if docker_run inspect $container | grep -q "\"$volume\""; then
            docker_run ps -a --filter id=$container --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
        fi
    done
}

inspect_container_connections() {
    echo -e "${BLUE}🔗 Container Network Connections:${NC}"
    
    for network in $(docker_run network ls -q); do
        network_name=$(docker_run network inspect -f '{{.Name}}' $network)
        containers=$(docker_run network inspect -f '{{range .Containers}}{{.Name}} {{end}}' $network)
        
        if [[ -n "$containers" ]]; then
            echo -e "${GREEN}Network: $network_name${NC}"
            echo "  Containers: $containers"
        fi
    done
}

FILTER_NAME=""
FILTER_IMAGE=""
FILTER_STATUS=""
FILTER_LABEL=""
FILTER_PORT=""
FILTER_NETWORK=""
FILTER_VOLUME=""
FILTER_HEALTH=""
SINCE_CONTAINER=""
BEFORE_CONTAINER=""
SHOW_ALL=false
OUTPUT_FORMAT="table"
SHOW_STATS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            FILTER_NAME="$2"
            shift 2
            ;;
        -i|--image)
            FILTER_IMAGE="$2"
            shift 2
            ;;
        -s|--status)
            FILTER_STATUS="$2"
            shift 2
            ;;
        -l|--label)
            FILTER_LABEL="$2"
            shift 2
            ;;
        -p|--port)
            FILTER_PORT="$2"
            shift 2
            ;;
        --network)
            FILTER_NETWORK="$2"
            shift 2
            ;;
        --volume)
            FILTER_VOLUME="$2"
            shift 2
            ;;
        --health)
            FILTER_HEALTH="$2"
            shift 2
            ;;
        --since)
            SINCE_CONTAINER="$2"
            shift 2
            ;;
        --before)
            BEFORE_CONTAINER="$2"
            shift 2
            ;;
        -a|--all)
            SHOW_ALL=true
            shift
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        --stats)
            SHOW_STATS=true
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

if [[ "$SHOW_STATS" == "true" ]]; then
    show_container_stats
elif [[ -n "$FILTER_PORT" ]] && [[ -z "$FILTER_NAME$FILTER_IMAGE$FILTER_STATUS" ]]; then
    find_containers_by_port "$FILTER_PORT"
elif [[ -n "$FILTER_VOLUME" ]] && [[ -z "$FILTER_NAME$FILTER_IMAGE$FILTER_STATUS" ]]; then
    find_containers_by_volume "$FILTER_VOLUME"
elif [[ -n "$SEARCH_TERM" ]] || [[ -n "$FILTER_NAME" ]] || [[ -n "$FILTER_IMAGE" ]] || \
     [[ -n "$FILTER_STATUS" ]] || [[ -n "$FILTER_NETWORK" ]]; then
    search_containers "$SEARCH_TERM"
else
    analyze_containers
    echo ""
    inspect_container_connections
fi