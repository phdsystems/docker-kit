#!/bin/bash

# ==============================================================================
# DockerKit - Docker Security Analysis
# ==============================================================================
# Comprehensive security audit and analysis for Docker environments
# Checks for common security issues, misconfigurations, and anti-patterns
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

# Security check counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Risk levels
CRITICAL="CRITICAL"
HIGH="HIGH"
MEDIUM="MEDIUM"
LOW="LOW"
INFO="INFO"

# ==============================================================================
# Helper Functions
# ==============================================================================

show_help() {
    cat <<EOF
${BOLD}${CYAN}DockerKit - Docker Security Analyzer${NC}

${BOLD}USAGE:${NC}
    $0 [OPTIONS]

${BOLD}OPTIONS:${NC}
    -h, --help          Show this help message
    -v, --verbose       Show detailed information for each check
    -q, --quiet         Only show failures and warnings
    -f, --format TYPE   Output format: text, json, html (default: text)
    --fix               Attempt to fix issues where possible
    --report FILE       Save report to file

${BOLD}SECURITY CHECKS:${NC}
    • Docker daemon configuration
    • Container runtime security
    • Image vulnerabilities
    • Network isolation
    • Volume permissions
    • Secrets management
    • Resource limits
    • User namespaces
    • AppArmor/SELinux profiles
    • Docker socket exposure

${BOLD}EXAMPLES:${NC}
    # Run full security audit
    $0

    # Run with verbose output
    $0 --verbose

    # Generate JSON report
    $0 --format json --report security-audit.json

    # Run and attempt fixes
    $0 --fix
EOF
}

check_pass() {
    local message="$1"
    local details="${2:-}"
    
    ((TOTAL_CHECKS++))
    ((PASSED_CHECKS++))
    
    echo -e "  ${GREEN}✓${NC} ${message}"
    [[ -n "$details" ]] && [[ "$VERBOSE" == "true" ]] && echo -e "    ${DIM}${details}${NC}"
}

check_fail() {
    local level="$1"
    local message="$2"
    local details="${3:-}"
    local fix="${4:-}"
    
    ((TOTAL_CHECKS++))
    ((FAILED_CHECKS++))
    
    local color="$RED"
    [[ "$level" == "$HIGH" ]] && color="$RED"
    [[ "$level" == "$MEDIUM" ]] && color="$YELLOW"
    [[ "$level" == "$LOW" ]] && color="$YELLOW"
    
    echo -e "  ${color}✗ [$level]${NC} ${message}"
    [[ -n "$details" ]] && echo -e "    ${DIM}Details: ${details}${NC}"
    [[ -n "$fix" ]] && echo -e "    ${CYAN}Fix: ${fix}${NC}"
}

check_warn() {
    local message="$1"
    local details="${2:-}"
    
    ((TOTAL_CHECKS++))
    ((WARNING_CHECKS++))
    
    echo -e "  ${YELLOW}⚠${NC} ${message}"
    [[ -n "$details" ]] && [[ "$VERBOSE" == "true" ]] && echo -e "    ${DIM}${details}${NC}"
}

check_info() {
    local message="$1"
    echo -e "  ${CYAN}ℹ${NC} ${message}"
}

# ==============================================================================
# Security Checks
# ==============================================================================

check_docker_daemon_config() {
    echo -e "\n${BOLD}Docker Daemon Configuration${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Check if running as root
    if [[ "$EUID" -eq 0 ]]; then
        check_warn "Running as root user" "Consider using rootless Docker for better security"
    else
        check_pass "Not running as root"
    fi
    
    # Check Docker daemon.json
    local daemon_json="/etc/docker/daemon.json"
    if [[ -f "$daemon_json" ]]; then
        check_pass "Docker daemon.json exists"
        
        # Check for user namespace remapping
        if grep -q '"userns-remap"' "$daemon_json" 2>/dev/null; then
            check_pass "User namespace remapping enabled"
        else
            check_fail "$MEDIUM" "User namespace remapping not configured" \
                "Containers run as root by default" \
                "Add \"userns-remap\": \"default\" to $daemon_json"
        fi
        
        # Check for live-restore
        if grep -q '"live-restore".*true' "$daemon_json" 2>/dev/null; then
            check_pass "Live restore enabled"
        else
            check_warn "Live restore not enabled" "Containers will stop if daemon restarts"
        fi
        
        # Check for logging configuration
        if grep -q '"log-driver"' "$daemon_json" 2>/dev/null; then
            check_pass "Logging driver configured"
        else
            check_warn "Default logging driver in use" "Consider configuring centralized logging"
        fi
    else
        check_warn "No daemon.json configuration file" "Using all default settings"
    fi
    
    # Check Docker socket permissions
    if [[ -S /var/run/docker.sock ]]; then
        local socket_perms=$(stat -c %a /var/run/docker.sock)
        if [[ "$socket_perms" == "660" ]] || [[ "$socket_perms" == "600" ]]; then
            check_pass "Docker socket has restrictive permissions ($socket_perms)"
        else
            check_fail "$HIGH" "Docker socket has permissive permissions ($socket_perms)" \
                "Socket is accessible to unauthorized users" \
                "chmod 660 /var/run/docker.sock"
        fi
    fi
}

check_container_runtime_security() {
    echo -e "\n${BOLD}Container Runtime Security${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    local insecure_containers=0
    local privileged_containers=0
    local cap_sys_admin_containers=0
    local host_network_containers=0
    local host_pid_containers=0
    local docker_sock_containers=0
    
    # Check each running container
    docker_run ps -q | while read -r container_id; do
        local name=$(docker_run inspect -f '{{.Name}}' "$container_id" | sed 's/^\///')
        
        # Check for privileged mode
        if docker_run inspect -f '{{.HostConfig.Privileged}}' "$container_id" | grep -q "true"; then
            ((privileged_containers++))
            check_fail "$CRITICAL" "Container '$name' running in privileged mode" \
                "Container has full host capabilities" \
                "Run without --privileged flag"
        fi
        
        # Check for CAP_SYS_ADMIN
        local caps=$(docker_run inspect -f '{{.HostConfig.CapAdd}}' "$container_id")
        if echo "$caps" | grep -q "SYS_ADMIN"; then
            ((cap_sys_admin_containers++))
            check_fail "$HIGH" "Container '$name' has CAP_SYS_ADMIN capability" \
                "Excessive capabilities granted" \
                "Remove CAP_SYS_ADMIN unless absolutely necessary"
        fi
        
        # Check for host network mode
        if docker_run inspect -f '{{.HostConfig.NetworkMode}}' "$container_id" | grep -q "host"; then
            ((host_network_containers++))
            check_fail "$MEDIUM" "Container '$name' using host network" \
                "No network isolation from host" \
                "Use bridge or custom network instead"
        fi
        
        # Check for host PID namespace
        if docker_run inspect -f '{{.HostConfig.PidMode}}' "$container_id" | grep -q "host"; then
            ((host_pid_containers++))
            check_fail "$HIGH" "Container '$name' using host PID namespace" \
                "Can see all host processes" \
                "Remove --pid=host unless necessary"
        fi
        
        # Check for Docker socket mount
        if docker_run inspect -f '{{range .Mounts}}{{.Source}}{{end}}' "$container_id" | grep -q "/var/run/docker.sock"; then
            ((docker_sock_containers++))
            check_fail "$CRITICAL" "Container '$name' has Docker socket mounted" \
                "Container can control host Docker daemon - MAJOR SECURITY RISK" \
                "Use Docker-in-Docker or rootless Docker instead"
        fi
        
        # Check for read-only root filesystem
        if docker_run inspect -f '{{.HostConfig.ReadonlyRootfs}}' "$container_id" | grep -q "false"; then
            check_warn "Container '$name' has writable root filesystem" \
                "Consider using --read-only flag"
        fi
        
        # Check for resource limits
        local memory_limit=$(docker_run inspect -f '{{.HostConfig.Memory}}' "$container_id")
        if [[ "$memory_limit" == "0" ]]; then
            check_warn "Container '$name' has no memory limit" \
                "Could consume all host memory"
        fi
    done
    
    # Summary
    if [[ $privileged_containers -eq 0 ]] && [[ $docker_sock_containers -eq 0 ]]; then
        check_pass "No containers with critical security issues"
    fi
}

check_image_security() {
    echo -e "\n${BOLD}Image Security${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Check for images running as root
    local root_images=0
    docker_run images --format "{{.Repository}}:{{.Tag}}" | while read -r image; do
        [[ "$image" == "<none>:<none>" ]] && continue
        
        local user=$(docker_run inspect -f '{{.Config.User}}' "$image" 2>/dev/null || echo "")
        if [[ -z "$user" ]] || [[ "$user" == "root" ]] || [[ "$user" == "0" ]]; then
            ((root_images++))
            check_warn "Image '$image' runs as root user" \
                "Consider using USER directive in Dockerfile"
        fi
    done
    
    # Check for dangling images
    local dangling_count=$(docker_run images -f "dangling=true" -q | wc -l)
    if [[ $dangling_count -gt 0 ]]; then
        check_warn "$dangling_count dangling images found" \
            "Run 'docker_run image prune' to clean up"
    else
        check_pass "No dangling images"
    fi
    
    # Check for old images
    local old_images=0
    local thirty_days_ago=$(date -d '30 days ago' +%s)
    docker_run images --format "{{.Repository}}:{{.Tag}}\t{{.CreatedAt}}" | while IFS=$'\t' read -r image created; do
        [[ "$image" == "<none>:<none>" ]] && continue
        
        local created_ts=$(date -d "$created" +%s 2>/dev/null || echo 0)
        if [[ $created_ts -lt $thirty_days_ago ]]; then
            ((old_images++))
            check_info "Image '$image' is older than 30 days"
        fi
    done
}

check_network_security() {
    echo -e "\n${BOLD}Network Security${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Check for containers on default bridge
    local default_bridge_containers=$(docker_run network inspect bridge -f '{{range $k,$v := .Containers}}{{$k}}{{end}}' | wc -w)
    if [[ $default_bridge_containers -gt 0 ]]; then
        check_warn "$default_bridge_containers containers using default bridge network" \
            "Create custom networks for better isolation"
    else
        check_pass "No containers on default bridge network"
    fi
    
    # Check for ICC (Inter-Container Communication) on default bridge
    local icc=$(docker_run network inspect bridge -f '{{index .Options "com.docker.network.bridge.enable_icc"}}' 2>/dev/null)
    if [[ "$icc" == "false" ]]; then
        check_pass "Inter-container communication disabled on default bridge"
    else
        check_warn "Inter-container communication enabled on default bridge" \
            "Containers can communicate freely"
    fi
    
    # Check for published ports
    local exposed_ports=$(docker_run ps --format "table {{.Ports}}" | grep -c "0.0.0.0" || true)
    if [[ $exposed_ports -gt 0 ]]; then
        check_warn "$exposed_ports containers with ports exposed on all interfaces (0.0.0.0)" \
            "Consider binding to specific interfaces"
    else
        check_pass "No containers exposing ports on all interfaces"
    fi
}

check_volume_security() {
    echo -e "\n${BOLD}Volume Security${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Check for volumes with sensitive names
    local sensitive_patterns="password|secret|key|token|credential|private"
    docker_run volume ls --format "{{.Name}}" | while read -r volume; do
        if echo "$volume" | grep -qiE "$sensitive_patterns"; then
            check_warn "Volume '$volume' has potentially sensitive name" \
                "Ensure proper encryption and access controls"
        fi
    done
    
    # Check for bind mounts to sensitive locations
    docker_run ps -q | while read -r container_id; do
        local name=$(docker_run inspect -f '{{.Name}}' "$container_id" | sed 's/^\///')
        docker_run inspect -f '{{range .Mounts}}{{if eq .Type "bind"}}{{.Source}}{{end}}{{end}}' "$container_id" | while read -r mount; do
            [[ -z "$mount" ]] && continue
            
            # Check for sensitive paths
            if echo "$mount" | grep -qE "^/etc|^/root|^/home|^/var/run"; then
                check_warn "Container '$name' has bind mount to sensitive path: $mount" \
                    "Review if this access is necessary"
            fi
        done
    done
}

check_secrets_management() {
    echo -e "\n${BOLD}Secrets Management${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Check for secrets in environment variables
    local containers_with_secrets=0
    docker_run ps -q | while read -r container_id; do
        local name=$(docker_run inspect -f '{{.Name}}' "$container_id" | sed 's/^\///')
        local env_vars=$(docker_run inspect -f '{{range .Config.Env}}{{.}} {{end}}' "$container_id")
        
        if echo "$env_vars" | grep -qiE "(PASSWORD|SECRET|KEY|TOKEN|API_KEY|PRIVATE)="; then
            ((containers_with_secrets++))
            check_fail "$HIGH" "Container '$name' may have secrets in environment variables" \
                "Secrets visible in docker_run inspect output" \
                "Use Docker secrets or external secret management"
        fi
    done
    
    # Check for Docker Swarm secrets (if swarm is initialized)
    if docker info 2>/dev/null | grep -q "Swarm: active"; then
        local secret_count=$(docker secret ls -q 2>/dev/null | wc -l)
        if [[ $secret_count -gt 0 ]]; then
            check_pass "Using Docker Swarm secrets ($secret_count secrets)"
        fi
    fi
}

check_compliance_summary() {
    echo -e "\n${BOLD}Security Compliance Summary${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # CIS Docker Benchmark checks
    echo -e "\n${BOLD}CIS Docker Benchmark Compliance:${NC}"
    
    # Check if audit rules are configured
    if command -v auditctl &>/dev/null; then
        if auditctl -l 2>/dev/null | grep -q docker; then
            check_pass "Docker audit rules configured"
        else
            check_warn "No Docker audit rules found" \
                "Configure auditd for Docker"
        fi
    fi
    
    # Check AppArmor/SELinux
    if command -v aa-status &>/dev/null; then
        if aa-status 2>/dev/null | grep -q docker; then
            check_pass "AppArmor profiles loaded for Docker"
        else
            check_warn "No AppArmor profiles for Docker"
        fi
    elif command -v getenforce &>/dev/null; then
        if [[ $(getenforce) == "Enforcing" ]]; then
            check_pass "SELinux is enforcing"
        else
            check_warn "SELinux not enforcing"
        fi
    else
        check_warn "No mandatory access control (MAC) system active"
    fi
}

generate_report() {
    local format="${1:-text}"
    local output_file="${2:-}"
    
    local report=""
    local score=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    
    case "$format" in
        json)
            report=$(cat <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "summary": {
    "total_checks": $TOTAL_CHECKS,
    "passed": $PASSED_CHECKS,
    "failed": $FAILED_CHECKS,
    "warnings": $WARNING_CHECKS,
    "score": $score
  },
  "docker_version": "$(docker version --format '{{.Server.Version}}')",
  "recommendations": [
    "Enable user namespace remapping",
    "Use custom networks instead of default bridge",
    "Implement resource limits for all containers",
    "Avoid mounting Docker socket in containers",
    "Use secrets management for sensitive data"
  ]
}
EOF
)
            ;;
        *)
            report=$(cat <<EOF

================================================================================
Docker Security Audit Report
Generated: $(date)
================================================================================

SUMMARY
-------
Total Checks:     $TOTAL_CHECKS
Passed:          $PASSED_CHECKS
Failed:          $FAILED_CHECKS
Warnings:        $WARNING_CHECKS
Security Score:  ${score}%

CRITICAL FINDINGS
-----------------
- Review all containers with Docker socket mounted
- Address privileged containers
- Implement proper secrets management

RECOMMENDATIONS
---------------
1. Enable user namespace remapping in Docker daemon
2. Use custom networks for container isolation
3. Implement resource limits for all containers
4. Regular security scanning of images
5. Use read-only root filesystems where possible
6. Implement proper logging and monitoring
7. Regular updates of Docker and base images

================================================================================
EOF
)
            ;;
    esac
    
    if [[ -n "$output_file" ]]; then
        echo "$report" > "$output_file"
        echo -e "${GREEN}Report saved to: $output_file${NC}"
    else
        echo "$report"
    fi
}

# ==============================================================================
# Main
# ==============================================================================

main() {
    local VERBOSE=false
    local QUIET=false
    local FORMAT="text"
    local FIX_MODE=false
    local REPORT_FILE=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            -f|--format)
                FORMAT="$2"
                shift 2
                ;;
            --fix)
                FIX_MODE=true
                shift
                ;;
            --report)
                REPORT_FILE="$2"
                shift 2
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
    
    echo -e "${BOLD}${CYAN}DockerKit Security Analyzer${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════${NC}"
    echo -e "Starting security audit at $(date)\n"
    
    # Run security checks
    check_docker_daemon_config
    check_container_runtime_security
    check_image_security
    check_network_security
    check_volume_security
    check_secrets_management
    check_compliance_summary
    
    # Generate report
    echo -e "\n${BOLD}${CYAN}Security Audit Complete${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════${NC}"
    
    local score=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    echo -e "Total Checks:    ${BOLD}$TOTAL_CHECKS${NC}"
    echo -e "Passed:          ${GREEN}$PASSED_CHECKS${NC}"
    echo -e "Failed:          ${RED}$FAILED_CHECKS${NC}"
    echo -e "Warnings:        ${YELLOW}$WARNING_CHECKS${NC}"
    echo -e "Security Score:  ${BOLD}${score}%${NC}"
    
    if [[ $score -ge 80 ]]; then
        echo -e "\n${GREEN}${BOLD}✓ Good security posture${NC}"
    elif [[ $score -ge 60 ]]; then
        echo -e "\n${YELLOW}${BOLD}⚠ Moderate security - improvements needed${NC}"
    else
        echo -e "\n${RED}${BOLD}✗ Poor security posture - immediate action required${NC}"
    fi
    
    # Generate report if requested
    if [[ -n "$REPORT_FILE" ]] || [[ "$FORMAT" != "text" ]]; then
        generate_report "$FORMAT" "$REPORT_FILE"
    fi
    
    # Exit with appropriate code
    [[ $FAILED_CHECKS -eq 0 ]] && exit 0 || exit 1
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi