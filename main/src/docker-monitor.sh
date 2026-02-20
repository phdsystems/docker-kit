#!/bin/bash

# ==============================================================================
# DockerKit - Docker Resource Monitor
# ==============================================================================
# Real-time monitoring of Docker container resources with alerts
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
CLEAR='\033[2J'
HOME='\033[H'
NC='\033[0m' # No Color

# Configuration
REFRESH_INTERVAL="${REFRESH_INTERVAL:-2}"
SHOW_ALL="${SHOW_ALL:-false}"
TOP_N="${TOP_N:-10}"
ALERT_CPU="${ALERT_CPU:-80}"      # Alert if CPU > 80%
ALERT_MEM="${ALERT_MEM:-80}"      # Alert if Memory > 80%
ALERT_DISK="${ALERT_DISK:-90}"    # Alert if Disk > 90%

# ==============================================================================
# Helper Functions
# ==============================================================================

show_help() {
    cat <<EOF
${BOLD}${CYAN}DockerKit - Resource Monitor${NC}

${BOLD}USAGE:${NC}
    $0 [OPTIONS]

${BOLD}OPTIONS:${NC}
    -h, --help          Show this help message
    -i, --interval SEC  Refresh interval in seconds (default: 2)
    -t, --top N         Show top N containers by CPU (default: 10)
    -a, --all           Show all containers (including stopped)
    --alert-cpu PCT     CPU alert threshold (default: 80%)
    --alert-mem PCT     Memory alert threshold (default: 80%)
    --once              Run once and exit (no loop)
    --export FILE       Export stats to file
    --json              Output in JSON format

${BOLD}DISPLAY MODES:${NC}
    live       Live dashboard (default)
    summary    One-time summary
    alerts     Show only containers exceeding thresholds
    top        Top consumers only

${BOLD}EXAMPLES:${NC}
    # Live monitoring dashboard
    $0

    # Show top 5 containers, refresh every 5 seconds
    $0 --top 5 --interval 5

    # One-time summary
    $0 --once summary

    # Monitor with custom alert thresholds
    $0 --alert-cpu 50 --alert-mem 75

${BOLD}KEYBOARD SHORTCUTS:${NC}
    q        Quit
    p        Pause/Resume
    s        Sort by different metric
    a        Toggle all/running containers
EOF
}

# ==============================================================================
# Monitoring Functions
# ==============================================================================

get_container_stats() {
    local format="table"
    [[ "${1:-}" == "json" ]] && format="json"
    
    if [[ "$format" == "json" ]]; then
        echo "["
        local first=true
    fi
    
    docker_run stats --no-stream --format "{{.Container}}|{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}|{{.MemPerc}}|{{.NetIO}}|{{.BlockIO}}|{{.PIDs}}" \
    | while IFS='|' read -r id name cpu mem_usage mem_perc net_io block_io pids; do
        # Parse percentages
        cpu_val=${cpu%\%}
        mem_val=${mem_perc%\%}
        
        # Check for alerts
        local alert=""
        if (( $(echo "$cpu_val > $ALERT_CPU" | bc -l) )); then
            alert="HIGH_CPU"
        fi
        if (( $(echo "$mem_val > $ALERT_MEM" | bc -l) )); then
            alert="${alert:+$alert,}HIGH_MEM"
        fi
        
        if [[ "$format" == "json" ]]; then
            [[ "$first" == "true" ]] && first=false || echo ","
            cat <<EOF
    {
        "id": "$id",
        "name": "$name",
        "cpu_percent": $cpu_val,
        "memory_usage": "$mem_usage",
        "memory_percent": $mem_val,
        "network_io": "$net_io",
        "block_io": "$block_io",
        "pids": "$pids",
        "alerts": "$alert"
    }
EOF
        else
            echo "$id|$name|$cpu|$mem_usage|$mem_perc|$net_io|$block_io|$pids|$alert"
        fi
    done
    
    [[ "$format" == "json" ]] && echo "]"
}

display_live_dashboard() {
    local paused=false
    local sort_by="cpu"
    
    while true; do
        if [[ "$paused" != "true" ]]; then
            # Clear screen and move cursor to home
            echo -e "${CLEAR}${HOME}"
            
            # Header
            echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${BOLD}${CYAN}║                         DockerKit Resource Monitor                          ║${NC}"
            echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
            
            # System overview
            echo -e "\n${BOLD}System Overview${NC} $(date '+%Y-%m-%d %H:%M:%S')"
            echo -e "${BLUE}────────────────────────────────────────────────────────────────────────────────${NC}"
            
            # Docker info
            local container_count=$(docker_run ps -q | wc -l)
            local image_count=$(docker_run images -q | wc -l)
            local volume_count=$(docker_run volume ls -q | wc -l)
            
            printf "  %-20s %-20s %-20s %-20s\n" \
                "Containers: ${GREEN}$container_count${NC}" \
                "Images: ${CYAN}$image_count${NC}" \
                "Volumes: ${MAGENTA}$volume_count${NC}" \
                "Networks: $(docker_run network ls -q | wc -l)"
            
            # Resource usage summary
            echo -e "\n${BOLD}Resource Usage${NC}"
            echo -e "${BLUE}────────────────────────────────────────────────────────────────────────────────${NC}"
            
            # Get total CPU and memory usage
            local total_cpu=0
            local total_mem=0
            local alert_count=0
            
            while IFS='|' read -r id name cpu mem_usage mem_perc net_io block_io pids alert; do
                cpu_val=${cpu%\%}
                mem_val=${mem_perc%\%}
                total_cpu=$(echo "$total_cpu + $cpu_val" | bc)
                total_mem=$(echo "$total_mem + $mem_val" | bc)
                [[ -n "$alert" ]] && ((alert_count++))
            done < <(get_container_stats)
            
            printf "  %-25s %-25s %-25s\n" \
                "Total CPU: ${YELLOW}${total_cpu}%${NC}" \
                "Total Memory: ${YELLOW}${total_mem}%${NC}" \
                "Alerts: $([ $alert_count -gt 0 ] && echo -e "${RED}$alert_count${NC}" || echo -e "${GREEN}0${NC}")"
            
            # Container details
            echo -e "\n${BOLD}Container Statistics${NC} (Sort: $sort_by)"
            echo -e "${BLUE}────────────────────────────────────────────────────────────────────────────────${NC}"
            
            # Table header
            printf "${BOLD}%-3s %-25s %-8s %-15s %-8s %-15s %-15s %-6s %-10s${NC}\n" \
                "#" "NAME" "CPU%" "MEMORY" "MEM%" "NET I/O" "DISK I/O" "PIDs" "STATUS"
            
            echo -e "${DIM}────────────────────────────────────────────────────────────────────────────────${NC}"
            
            # Container stats
            local i=1
            get_container_stats | head -n $TOP_N | while IFS='|' read -r id name cpu mem_usage mem_perc net_io block_io pids alert; do
                # Color based on resource usage
                local cpu_val=${cpu%\%}
                local mem_val=${mem_perc%\%}
                local cpu_color=""
                local mem_color=""
                local status="OK"
                local status_color="${GREEN}"
                
                if (( $(echo "$cpu_val > $ALERT_CPU" | bc -l) )); then
                    cpu_color="${RED}"
                    status="HIGH"
                    status_color="${RED}"
                elif (( $(echo "$cpu_val > 50" | bc -l) )); then
                    cpu_color="${YELLOW}"
                fi
                
                if (( $(echo "$mem_val > $ALERT_MEM" | bc -l) )); then
                    mem_color="${RED}"
                    status="HIGH"
                    status_color="${RED}"
                elif (( $(echo "$mem_val > 50" | bc -l) )); then
                    mem_color="${YELLOW}"
                fi
                
                # Truncate long names
                [[ ${#name} -gt 24 ]] && name="${name:0:22}.."
                
                printf "%-3s %-25s ${cpu_color}%-8s${NC} %-15s ${mem_color}%-8s${NC} %-15s %-15s %-6s ${status_color}%-10s${NC}\n" \
                    "$i" "$name" "$cpu" "$mem_usage" "$mem_perc" "$net_io" "$block_io" "$pids" "$status"
                
                ((i++))
            done
            
            # Footer
            echo -e "\n${DIM}Refresh: ${REFRESH_INTERVAL}s | Press 'q' to quit, 'p' to pause, 'h' for help${NC}"
            
            if [[ "$paused" == "true" ]]; then
                echo -e "${YELLOW}[PAUSED]${NC}"
            fi
        fi
        
        # Check for keyboard input (non-blocking)
        read -t $REFRESH_INTERVAL -n 1 key
        case "$key" in
            q|Q)
                echo -e "\n${CYAN}Exiting monitor...${NC}"
                break
                ;;
            p|P)
                if [[ "$paused" == "true" ]]; then
                    paused=false
                else
                    paused=true
                fi
                ;;
            s|S)
                # Cycle through sort options
                case "$sort_by" in
                    cpu) sort_by="mem" ;;
                    mem) sort_by="net" ;;
                    net) sort_by="disk" ;;
                    *) sort_by="cpu" ;;
                esac
                ;;
            h|H)
                echo -e "\n${CYAN}Commands: q=quit, p=pause, s=sort${NC}"
                sleep 2
                ;;
        esac
    done
}

display_summary() {
    echo -e "${BOLD}${CYAN}Docker Resource Summary${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════════════════${NC}\n"
    
    # System overview
    echo -e "${BOLD}System State:${NC}"
    docker_run system df
    
    echo -e "\n${BOLD}Container Resource Usage:${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────────────────${NC}"
    
    # Table format
    printf "${BOLD}%-25s %-10s %-20s %-10s %-15s %-15s${NC}\n" \
        "CONTAINER" "CPU%" "MEMORY" "MEM%" "NET I/O" "DISK I/O"
    
    docker_run stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"
    
    # High consumers
    echo -e "\n${BOLD}${YELLOW}Top CPU Consumers:${NC}"
    docker_run stats --no-stream --format "{{.Name}}: {{.CPUPerc}}" | sort -t: -k2 -rn | head -5
    
    echo -e "\n${BOLD}${YELLOW}Top Memory Consumers:${NC}"
    docker_run stats --no-stream --format "{{.Name}}: {{.MemPerc}}" | sort -t: -k2 -rn | head -5
}

display_alerts() {
    echo -e "${BOLD}${RED}Resource Alerts${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════════════════${NC}\n"
    
    local alert_found=false
    
    get_container_stats | while IFS='|' read -r id name cpu mem_usage mem_perc net_io block_io pids alert; do
        if [[ -n "$alert" ]]; then
            alert_found=true
            local cpu_val=${cpu%\%}
            local mem_val=${mem_perc%\%}
            
            echo -e "${RED}⚠ Alert for container: ${BOLD}$name${NC}"
            
            if (( $(echo "$cpu_val > $ALERT_CPU" | bc -l) )); then
                echo -e "  ${YELLOW}CPU Usage: ${RED}$cpu${NC} (threshold: $ALERT_CPU%)"
            fi
            
            if (( $(echo "$mem_val > $ALERT_MEM" | bc -l) )); then
                echo -e "  ${YELLOW}Memory Usage: ${RED}$mem_perc${NC} (threshold: $ALERT_MEM%)"
            fi
            
            echo ""
        fi
    done
    
    if [[ "$alert_found" != "true" ]]; then
        echo -e "${GREEN}✓ No resource alerts${NC}"
    fi
}

export_stats() {
    local output_file="$1"
    local format="${2:-csv}"
    
    echo -e "${CYAN}Exporting stats to $output_file...${NC}"
    
    if [[ "$format" == "json" ]]; then
        get_container_stats json > "$output_file"
    else
        # CSV format
        echo "Timestamp,Container,Name,CPU%,Memory Usage,Memory%,Network I/O,Block I/O,PIDs" > "$output_file"
        
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        docker_run stats --no-stream --format "{{.Container}},{{.Name}},{{.CPUPerc}},{{.MemUsage}},{{.MemPerc}},{{.NetIO}},{{.BlockIO}},{{.PIDs}}" \
        | while IFS=',' read -r container name cpu mem_usage mem_perc net_io block_io pids; do
            echo "$timestamp,$container,$name,$cpu,$mem_usage,$mem_perc,$net_io,$block_io,$pids" >> "$output_file"
        done
    fi
    
    echo -e "${GREEN}✓ Stats exported to $output_file${NC}"
}

# ==============================================================================
# Health Check Aggregator
# ==============================================================================

check_container_health() {
    echo -e "${BOLD}${CYAN}Container Health Status${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════════════════${NC}\n"
    
    local healthy=0
    local unhealthy=0
    local no_healthcheck=0
    
    docker_run ps --format "{{.ID}}|{{.Names}}|{{.Status}}" | while IFS='|' read -r id name status; do
        # Get health status
        local health=$(docker_run inspect --format='{{.State.Health.Status}}' "$id" 2>/dev/null || echo "none")
        
        case "$health" in
            healthy)
                echo -e "${GREEN}✓${NC} $name: ${GREEN}Healthy${NC}"
                ((healthy++))
                ;;
            unhealthy)
                echo -e "${RED}✗${NC} $name: ${RED}Unhealthy${NC}"
                # Show last health check log
                local last_log=$(docker_run inspect --format='{{range .State.Health.Log}}{{.Output}}{{end}}' "$id" 2>/dev/null | tail -1)
                [[ -n "$last_log" ]] && echo -e "  ${DIM}$last_log${NC}"
                ((unhealthy++))
                ;;
            starting)
                echo -e "${YELLOW}⟳${NC} $name: ${YELLOW}Starting${NC}"
                ;;
            none|"")
                echo -e "${CYAN}○${NC} $name: ${CYAN}No healthcheck${NC}"
                ((no_healthcheck++))
                ;;
        esac
    done
    
    # Summary
    echo -e "\n${BOLD}Summary:${NC}"
    echo -e "  Healthy:          ${GREEN}$healthy${NC}"
    echo -e "  Unhealthy:        ${RED}$unhealthy${NC}"
    echo -e "  No healthcheck:   ${CYAN}$no_healthcheck${NC}"
}

# ==============================================================================
# Main
# ==============================================================================

main() {
    local mode="live"
    local once=false
    local export_file=""
    local json_output=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -i|--interval)
                REFRESH_INTERVAL="$2"
                shift 2
                ;;
            -t|--top)
                TOP_N="$2"
                shift 2
                ;;
            -a|--all)
                SHOW_ALL=true
                shift
                ;;
            --alert-cpu)
                ALERT_CPU="$2"
                shift 2
                ;;
            --alert-mem)
                ALERT_MEM="$2"
                shift 2
                ;;
            --once)
                once=true
                shift
                ;;
            --export)
                export_file="$2"
                shift 2
                ;;
            --json)
                json_output=true
                shift
                ;;
            live|summary|alerts|top|health)
                mode="$1"
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
    
    # Export if requested
    if [[ -n "$export_file" ]]; then
        export_stats "$export_file" $([ "$json_output" == "true" ] && echo "json" || echo "csv")
        exit 0
    fi
    
    # Display based on mode
    case "$mode" in
        live)
            if [[ "$once" == "true" ]]; then
                display_summary
            else
                display_live_dashboard
            fi
            ;;
        summary)
            display_summary
            ;;
        alerts)
            display_alerts
            ;;
        health)
            check_container_health
            ;;
        top)
            display_summary
            ;;
    esac
}

# Handle cleanup on exit
trap 'echo -e "\n${CYAN}Monitor stopped${NC}"' EXIT

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi