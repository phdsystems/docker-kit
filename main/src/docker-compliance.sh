#!/usr/bin/env bash
#
# Docker Compliance and Security Module for DCK
# Implements Docker best practices enforcement and validation
#

set -uo pipefail  # Don't use -e as grep returns non-zero when no match
IFS=$'\n\t'

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/docker-wrapper.sh"

# Debug: Ensure DOCKER_CMD is set
if [[ -z "${DOCKER_CMD:-}" ]]; then
    echo "ERROR: DOCKER_CMD not set after sourcing docker-wrapper.sh" >&2
    exit 1
fi

# Compliance levels
readonly COMPLIANCE_CRITICAL=0
readonly COMPLIANCE_HIGH=1
readonly COMPLIANCE_MEDIUM=2
readonly COMPLIANCE_LOW=3
readonly COMPLIANCE_INFO=4

# Color codes for output
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[1;33m'
COLOR_GREEN='\033[0;32m'
COLOR_BLUE='\033[0;34m'
COLOR_RESET='\033[0m'

# Compliance check results
declare -A COMPLIANCE_RESULTS
declare -i TOTAL_CHECKS=0
declare -i PASSED_CHECKS=0
declare -i FAILED_CHECKS=0
declare -i WARNING_CHECKS=0

# Exit code handling
STRICT_MODE=false
MIN_COMPLIANCE_SCORE=70  # Default threshold for CI/CD
LAST_COMPLIANCE_SCORE=0

# Helper function to run docker commands
docker_exec() {
    local cmd="$DOCKER_CMD $@"
    # echo "DEBUG: Running: $cmd" >&2
    eval "$cmd"
}

# ============================================================================
# Dockerfile Compliance Checks
# ============================================================================

check_dockerfile_compliance() {
    local dockerfile="${1:-Dockerfile}"
    
    if [[ ! -f "$dockerfile" ]]; then
        log_error "Dockerfile not found: $dockerfile"
        return 1
    fi
    
    echo "🔍 Analyzing Dockerfile: $dockerfile"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check for non-root user
    check_nonroot_user "$dockerfile"
    
    # Check for version pinning
    check_version_pinning "$dockerfile"
    
    # Check for health check
    check_healthcheck "$dockerfile"
    
    # Check for metadata labels
    check_metadata_labels "$dockerfile"
    
    # Check for secrets
    check_no_secrets "$dockerfile"
    
    # Check for proper COPY vs ADD usage
    check_copy_usage "$dockerfile"
    
    # Check for cache cleanup
    check_cache_cleanup "$dockerfile"
    
    # Check for workdir
    check_workdir "$dockerfile"
    
    # Check base image
    check_base_image "$dockerfile"
    
    # Generate compliance score
    generate_compliance_report
}

check_nonroot_user() {
    local dockerfile="$1"
    local check_name="Non-root User"
    
    ((TOTAL_CHECKS++))
    
    if grep -q "^USER " "$dockerfile" && ! grep -q "^USER root" "$dockerfile"; then
        log_success "$check_name: ✅ Non-root user configured"
        COMPLIANCE_RESULTS["$check_name"]="PASS"
        ((PASSED_CHECKS++))
    else
        log_error "$check_name: ❌ No non-root user found"
        echo "  Fix: Add 'USER <username>' directive"
        COMPLIANCE_RESULTS["$check_name"]="FAIL"
        ((FAILED_CHECKS++))
    fi
}

check_version_pinning() {
    local dockerfile="$1"
    local check_name="Version Pinning"
    
    ((TOTAL_CHECKS++))
    
    # Check base image version
    if grep -q "^FROM.*:latest" "$dockerfile" || grep -E "^FROM [^:]+$" "$dockerfile" | grep -qv scratch; then
        log_warning "$check_name: ⚠️ Base image not version-pinned"
        echo "  Fix: Use specific versions (e.g., alpine:3.19.1)"
        COMPLIANCE_RESULTS["$check_name"]="WARN"
        ((WARNING_CHECKS++))
    else
        log_success "$check_name: ✅ Base image version pinned"
        COMPLIANCE_RESULTS["$check_name"]="PASS"
        ((PASSED_CHECKS++))
    fi
}

check_healthcheck() {
    local dockerfile="$1"
    local check_name="Health Check"
    
    ((TOTAL_CHECKS++))
    
    if grep -q "^HEALTHCHECK" "$dockerfile"; then
        log_success "$check_name: ✅ HEALTHCHECK configured"
        COMPLIANCE_RESULTS["$check_name"]="PASS"
        ((PASSED_CHECKS++))
    else
        log_warning "$check_name: ⚠️ No HEALTHCHECK found"
        echo "  Fix: Add HEALTHCHECK directive"
        COMPLIANCE_RESULTS["$check_name"]="WARN"
        ((WARNING_CHECKS++))
    fi
}

check_metadata_labels() {
    local dockerfile="$1"
    local check_name="Metadata Labels"
    
    ((TOTAL_CHECKS++))
    
    local required_labels=("maintainer" "version" "description")
    local missing_labels=()
    
    for label in "${required_labels[@]}"; do
        if ! grep -qi "^LABEL.*$label" "$dockerfile"; then
            missing_labels+=("$label")
        fi
    done
    
    if [[ ${#missing_labels[@]} -eq 0 ]]; then
        log_success "$check_name: ✅ All metadata labels present"
        COMPLIANCE_RESULTS["$check_name"]="PASS"
        ((PASSED_CHECKS++))
    else
        log_warning "$check_name: ⚠️ Missing labels: ${missing_labels[*]}"
        echo "  Fix: Add LABEL directives for metadata"
        COMPLIANCE_RESULTS["$check_name"]="WARN"
        ((WARNING_CHECKS++))
    fi
}

check_no_secrets() {
    local dockerfile="$1"
    local check_name="No Hardcoded Secrets"
    
    ((TOTAL_CHECKS++))
    
    # Check for potential secrets
    if grep -qE "(PASSWORD|SECRET|KEY|TOKEN|APIKEY|API_KEY)=['\"]" "$dockerfile"; then
        log_error "$check_name: ❌ Potential secrets found"
        echo "  Fix: Use build arguments or runtime environment variables"
        COMPLIANCE_RESULTS["$check_name"]="FAIL"
        ((FAILED_CHECKS++))
    else
        log_success "$check_name: ✅ No hardcoded secrets detected"
        COMPLIANCE_RESULTS["$check_name"]="PASS"
        ((PASSED_CHECKS++))
    fi
}

check_copy_usage() {
    local dockerfile="$1"
    local check_name="COPY vs ADD Usage"
    
    ((TOTAL_CHECKS++))
    
    # Check for ADD usage - it's only acceptable for local tar files
    if grep -q "^ADD " "$dockerfile"; then
        # Check if ADD is used with HTTP/HTTPS URLs (always bad)
        if grep -q "^ADD http" "$dockerfile"; then
            log_warning "$check_name: ⚠️ ADD used instead of COPY"
            echo "  Fix: Use COPY unless extracting local archives"
            COMPLIANCE_RESULTS["$check_name"]="WARN"
            ((WARNING_CHECKS++))
        # Check if ADD is used for non-tar files
        elif grep "^ADD " "$dockerfile" | grep -qv "\\.tar"; then
            log_warning "$check_name: ⚠️ ADD used instead of COPY"
            echo "  Fix: Use COPY unless extracting local archives"
            COMPLIANCE_RESULTS["$check_name"]="WARN"
            ((WARNING_CHECKS++))
        else
            log_success "$check_name: ✅ Proper COPY usage"
            COMPLIANCE_RESULTS["$check_name"]="PASS"
            ((PASSED_CHECKS++))
        fi
    else
        log_success "$check_name: ✅ Proper COPY usage"
        COMPLIANCE_RESULTS["$check_name"]="PASS"
        ((PASSED_CHECKS++))
    fi
}

check_cache_cleanup() {
    local dockerfile="$1"
    local check_name="Cache Cleanup"
    
    ((TOTAL_CHECKS++))
    
    if grep -q "apt-get install" "$dockerfile" && ! grep -q "rm -rf /var/lib/apt/lists" "$dockerfile"; then
        log_warning "$check_name: ⚠️ APT cache not cleaned"
        echo "  Fix: Add && rm -rf /var/lib/apt/lists/*"
        COMPLIANCE_RESULTS["$check_name"]="WARN"
        ((WARNING_CHECKS++))
    elif grep -q "apk add" "$dockerfile" && ! grep -q "rm -rf /var/cache/apk" "$dockerfile"; then
        log_warning "$check_name: ⚠️ APK cache not cleaned"
        echo "  Fix: Add && rm -rf /var/cache/apk/*"
        COMPLIANCE_RESULTS["$check_name"]="WARN"
        ((WARNING_CHECKS++))
    else
        log_success "$check_name: ✅ Package cache cleaned"
        COMPLIANCE_RESULTS["$check_name"]="PASS"
        ((PASSED_CHECKS++))
    fi
}

check_workdir() {
    local dockerfile="$1"
    local check_name="WORKDIR Usage"
    
    ((TOTAL_CHECKS++))
    
    if grep -q "^WORKDIR" "$dockerfile"; then
        log_success "$check_name: ✅ WORKDIR configured"
        COMPLIANCE_RESULTS["$check_name"]="PASS"
        ((PASSED_CHECKS++))
    else
        log_info "$check_name: ℹ️ No WORKDIR set"
        COMPLIANCE_RESULTS["$check_name"]="INFO"
        ((PASSED_CHECKS++))
    fi
}

check_base_image() {
    local dockerfile="$1"
    local check_name="Trusted Base Image"
    
    ((TOTAL_CHECKS++))
    
    local trusted_bases=("alpine" "ubuntu" "debian" "node" "python" "golang" "scratch" "distroless")
    local base_image
    base_image=$(grep "^FROM" "$dockerfile" | head -1 | awk '{print $2}' | cut -d: -f1 | cut -d/ -f2-)
    
    local is_trusted=false
    for trusted in "${trusted_bases[@]}"; do
        if [[ "$base_image" == *"$trusted"* ]]; then
            is_trusted=true
            break
        fi
    done
    
    if $is_trusted; then
        log_success "$check_name: ✅ Using trusted base image"
        COMPLIANCE_RESULTS["$check_name"]="PASS"
        ((PASSED_CHECKS++))
    else
        log_warning "$check_name: ⚠️ Verify base image trustworthiness"
        COMPLIANCE_RESULTS["$check_name"]="WARN"
        ((WARNING_CHECKS++))
    fi
}

# ============================================================================
# Container Runtime Compliance Checks
# ============================================================================

check_container_compliance() {
    local container="${1:-}"
    
    if [[ -z "$container" ]]; then
        log_error "Container name or ID required"
        return 1
    fi
    
    echo "🔍 Analyzing Container: $container"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check if container exists
    if ! docker_exec inspect "$container" &>/dev/null; then
        log_error "Container not found: $container"
        return 1
    fi
    
    # Runtime security checks
    check_container_user "$container"
    check_container_capabilities "$container"
    check_container_readonly "$container"
    check_container_privileged "$container"
    check_container_resources "$container"
    check_container_restart_policy "$container"
    check_container_health "$container"
    check_container_network "$container"
    
    generate_compliance_report
}

check_container_user() {
    local container="$1"
    local check_name="Container User"
    
    ((TOTAL_CHECKS++))
    
    local user
    user=$(docker_exec inspect "$container" --format '{{.Config.User}}')
    
    if [[ -z "$user" ]] || [[ "$user" == "root" ]] || [[ "$user" == "0" ]]; then
        log_error "$check_name: ❌ Running as root"
        COMPLIANCE_RESULTS["$check_name"]="FAIL"
        ((FAILED_CHECKS++))
    else
        log_success "$check_name: ✅ Running as non-root ($user)"
        COMPLIANCE_RESULTS["$check_name"]="PASS"
        ((PASSED_CHECKS++))
    fi
}

check_container_capabilities() {
    local container="$1"
    local check_name="Capabilities"
    
    ((TOTAL_CHECKS++))
    
    local cap_add cap_drop
    cap_add=$(docker_exec inspect "$container" --format '{{.HostConfig.CapAdd}}')
    cap_drop=$(docker_exec inspect "$container" --format '{{.HostConfig.CapDrop}}')
    
    if [[ "$cap_drop" == *"ALL"* ]]; then
        log_success "$check_name: ✅ All capabilities dropped"
        COMPLIANCE_RESULTS["$check_name"]="PASS"
        ((PASSED_CHECKS++))
    elif [[ -n "$cap_drop" ]]; then
        log_warning "$check_name: ⚠️ Some capabilities dropped"
        COMPLIANCE_RESULTS["$check_name"]="WARN"
        ((WARNING_CHECKS++))
    else
        log_error "$check_name: ❌ No capabilities dropped"
        COMPLIANCE_RESULTS["$check_name"]="FAIL"
        ((FAILED_CHECKS++))
    fi
}

check_container_readonly() {
    local container="$1"
    local check_name="Read-only Root"
    
    ((TOTAL_CHECKS++))
    
    local readonly_root
    readonly_root=$(docker_exec inspect "$container" --format '{{.HostConfig.ReadonlyRootfs}}')
    
    if [[ "$readonly_root" == "true" ]]; then
        log_success "$check_name: ✅ Read-only root filesystem"
        COMPLIANCE_RESULTS["$check_name"]="PASS"
        ((PASSED_CHECKS++))
    else
        log_warning "$check_name: ⚠️ Writable root filesystem"
        COMPLIANCE_RESULTS["$check_name"]="WARN"
        ((WARNING_CHECKS++))
    fi
}

check_container_privileged() {
    local container="$1"
    local check_name="Privileged Mode"
    
    ((TOTAL_CHECKS++))
    
    local privileged
    privileged=$(docker_exec inspect "$container" --format '{{.HostConfig.Privileged}}')
    
    if [[ "$privileged" == "true" ]]; then
        log_error "$check_name: ❌ Running in privileged mode"
        COMPLIANCE_RESULTS["$check_name"]="FAIL"
        ((FAILED_CHECKS++))
    else
        log_success "$check_name: ✅ Not privileged"
        COMPLIANCE_RESULTS["$check_name"]="PASS"
        ((PASSED_CHECKS++))
    fi
}

check_container_resources() {
    local container="$1"
    local check_name="Resource Limits"
    
    ((TOTAL_CHECKS++))
    
    local memory_limit cpu_quota
    memory_limit=$(docker_exec inspect "$container" --format '{{.HostConfig.Memory}}')
    cpu_quota=$(docker_exec inspect "$container" --format '{{.HostConfig.CpuQuota}}')
    
    if [[ "$memory_limit" != "0" ]] || [[ "$cpu_quota" != "0" ]]; then
        log_success "$check_name: ✅ Resource limits configured"
        COMPLIANCE_RESULTS["$check_name"]="PASS"
        ((PASSED_CHECKS++))
    else
        log_warning "$check_name: ⚠️ No resource limits"
        COMPLIANCE_RESULTS["$check_name"]="WARN"
        ((WARNING_CHECKS++))
    fi
}

check_container_restart_policy() {
    local container="$1"
    local check_name="Restart Policy"
    
    ((TOTAL_CHECKS++))
    
    local restart_policy
    restart_policy=$(docker_exec inspect "$container" --format '{{.HostConfig.RestartPolicy.Name}}')
    
    if [[ "$restart_policy" == "on-failure" ]]; then
        log_success "$check_name: ✅ Proper restart policy"
        COMPLIANCE_RESULTS["$check_name"]="PASS"
        ((PASSED_CHECKS++))
    elif [[ "$restart_policy" == "always" ]]; then
        log_warning "$check_name: ⚠️ Consider on-failure instead of always"
        COMPLIANCE_RESULTS["$check_name"]="WARN"
        ((WARNING_CHECKS++))
    else
        log_info "$check_name: ℹ️ Restart policy: $restart_policy"
        COMPLIANCE_RESULTS["$check_name"]="INFO"
        ((PASSED_CHECKS++))
    fi
}

check_container_health() {
    local container="$1"
    local check_name="Health Check"
    
    ((TOTAL_CHECKS++))
    
    local health_check
    health_check=$(docker_exec inspect "$container" --format '{{.Config.Healthcheck}}')
    
    if [[ "$health_check" != "<nil>" ]] && [[ "$health_check" != "{<nil>}" ]]; then
        log_success "$check_name: ✅ Health check configured"
        COMPLIANCE_RESULTS["$check_name"]="PASS"
        ((PASSED_CHECKS++))
    else
        log_warning "$check_name: ⚠️ No health check"
        COMPLIANCE_RESULTS["$check_name"]="WARN"
        ((WARNING_CHECKS++))
    fi
}

check_container_network() {
    local container="$1"
    local check_name="Network Mode"
    
    ((TOTAL_CHECKS++))
    
    local network_mode
    network_mode=$(docker_exec inspect "$container" --format '{{.HostConfig.NetworkMode}}')
    
    if [[ "$network_mode" == "host" ]]; then
        log_warning "$check_name: ⚠️ Using host network"
        COMPLIANCE_RESULTS["$check_name"]="WARN"
        ((WARNING_CHECKS++))
    else
        log_success "$check_name: ✅ Isolated network ($network_mode)"
        COMPLIANCE_RESULTS["$check_name"]="PASS"
        ((PASSED_CHECKS++))
    fi
}

# ============================================================================
# Image Security Scanning
# ============================================================================

scan_image_security() {
    local image="${1:-}"
    
    if [[ -z "$image" ]]; then
        log_error "Image name required"
        return 1
    fi
    
    echo "🔍 Security Scan: $image"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check if trivy is available
    if command -v trivy &>/dev/null; then
        echo "Running Trivy security scan..."
        trivy image --severity HIGH,CRITICAL "$image"
    elif command -v docker &>/dev/null && docker_exec scout version &>/dev/null; then
        echo "Running Docker Scout scan..."
        docker_exec scout cves "$image"
    else
        log_warning "No security scanner available (install trivy or docker scout)"
        echo ""
        echo "Install options:"
        echo "  Trivy: curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin"
        echo "  Scout: docker scout version (requires Docker Desktop or Scout CLI)"
    fi
}

# ============================================================================
# Compliance Report Generation
# ============================================================================

generate_compliance_report() {
    echo ""
    echo "📊 Compliance Report"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local compliance_score
    if [[ $TOTAL_CHECKS -gt 0 ]]; then
        compliance_score=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
    else
        compliance_score=0
    fi
    
    echo "Total Checks: $TOTAL_CHECKS"
    echo -e "${COLOR_GREEN}Passed: $PASSED_CHECKS${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}Warnings: $WARNING_CHECKS${COLOR_RESET}"
    echo -e "${COLOR_RED}Failed: $FAILED_CHECKS${COLOR_RESET}"
    echo ""
    echo "Compliance Score: ${compliance_score}%"
    
    # Store score for exit code handling
    LAST_COMPLIANCE_SCORE=$compliance_score
    
    # Determine compliance level
    if [[ $compliance_score -ge 90 ]]; then
        echo -e "${COLOR_GREEN}✅ EXCELLENT - Production Ready${COLOR_RESET}"
    elif [[ $compliance_score -ge 70 ]]; then
        echo -e "${COLOR_YELLOW}⚠️ GOOD - Minor improvements needed${COLOR_RESET}"
    elif [[ $compliance_score -ge 50 ]]; then
        echo -e "${COLOR_YELLOW}⚠️ FAIR - Significant improvements recommended${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}❌ POOR - Major security issues${COLOR_RESET}"
    fi
    
    # Show failed checks
    if [[ $FAILED_CHECKS -gt 0 ]]; then
        echo ""
        echo "Failed Checks:"
        for check in "${!COMPLIANCE_RESULTS[@]}"; do
            if [[ "${COMPLIANCE_RESULTS[$check]}" == "FAIL" ]]; then
                echo "  ❌ $check"
            fi
        done
    fi
    
    # Reset counters
    TOTAL_CHECKS=0
    PASSED_CHECKS=0
    FAILED_CHECKS=0
    WARNING_CHECKS=0
    unset COMPLIANCE_RESULTS
    declare -gA COMPLIANCE_RESULTS
}

# ============================================================================
# CIS Benchmark Checks
# ============================================================================

run_cis_benchmark() {
    echo "🔍 Running CIS Docker Benchmark"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check if docker-bench-security is available
    if [[ -f /usr/local/bin/docker-bench-security.sh ]]; then
        /usr/local/bin/docker-bench-security.sh
    else
        echo "Downloading and running Docker Bench Security..."
        docker_exec run --rm --net host --pid host --userns host --cap-add audit_control \
            -e DOCKER_CONTENT_TRUST=$DOCKER_CONTENT_TRUST \
            -v /var/lib:/var/lib:ro \
            -v /var/run/docker.sock:/var/run/docker.sock:ro \
            -v /etc:/etc:ro \
            docker/docker-bench-security
    fi
}

# ============================================================================
# Hadolint Integration
# ============================================================================

lint_dockerfile() {
    local dockerfile="${1:-Dockerfile}"
    
    if [[ ! -f "$dockerfile" ]]; then
        log_error "Dockerfile not found: $dockerfile"
        return 1
    fi
    
    echo "🔍 Linting Dockerfile: $dockerfile"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if command -v hadolint &>/dev/null; then
        hadolint "$dockerfile"
    else
        echo "Running Hadolint via Docker..."
        docker_exec run --rm -i hadolint/hadolint < "$dockerfile"
    fi
}

# ============================================================================
# Main Function
# ============================================================================

main() {
    local command="${1:-}"
    shift || true
    
    # Parse global options
    local remediate_mode=""
    local output_file=""
    
    while [[ $# -gt 0 ]] && [[ "$1" == --* ]]; do
        case "$1" in
            --fix|--auto)
                remediate_mode="auto"
                shift
                ;;
            --interactive)
                remediate_mode="interactive"
                shift
                ;;
            --generate-fixed)
                output_file="${2:-Dockerfile.fixed}"
                remediate_mode="auto"
                shift 2
                ;;
            --strict)
                STRICT_MODE=true
                if [[ "${2:-}" =~ ^[0-9]+$ ]]; then
                    MIN_COMPLIANCE_SCORE="$2"
                    shift 2
                else
                    shift
                fi
                ;;
            --threshold)
                if [[ "${2:-}" =~ ^[0-9]+$ ]]; then
                    MIN_COMPLIANCE_SCORE="$2"
                    STRICT_MODE=true
                    shift 2
                else
                    echo "Error: --threshold requires a numeric value (0-100)"
                    exit 1
                fi
                ;;
            *)
                break
                ;;
        esac
    done
    
    case "$command" in
        dockerfile|df)
            check_dockerfile_compliance "$@"
            
            # Apply remediation if requested
            if [[ -n "$remediate_mode" ]] && [[ -f "${1:-}" ]]; then
                echo ""
                "${SCRIPT_DIR}/docker-remediation.sh" \
                    --mode "$remediate_mode" \
                    ${output_file:+--output "$output_file"} \
                    "$1"
            fi
            ;;
        container|ct)
            check_container_compliance "$@"
            ;;
        image|img)
            scan_image_security "$@"
            ;;
        lint)
            lint_dockerfile "$@"
            ;;
        cis|benchmark)
            run_cis_benchmark
            ;;
        remediate|fix)
            # Direct remediation command
            shift
            "${SCRIPT_DIR}/docker-remediation.sh" "$@"
            ;;
        all)
            # Run all compliance checks
            local target="${1:-.}"
            if [[ -f "$target/Dockerfile" ]]; then
                check_dockerfile_compliance "$target/Dockerfile"
            fi
            if [[ -n "${2:-}" ]]; then
                check_container_compliance "$2"
            fi
            ;;
        *)
            echo "DCK Docker Compliance Module"
            echo ""
            echo "Usage: dck compliance <command> [options]"
            echo ""
            echo "Commands:"
            echo "  dockerfile, df <file>  Check Dockerfile compliance"
            echo "  container, ct <name>   Check container runtime compliance"
            echo "  image, img <name>      Security scan Docker image"
            echo "  lint <file>           Lint Dockerfile with Hadolint"
            echo "  cis, benchmark        Run CIS Docker Benchmark"
            echo "  remediate, fix <file> Auto-fix Dockerfile issues"
            echo "  all <dir> [container] Run all compliance checks"
            echo ""
            echo "Options:"
            echo "  --fix, --auto         Automatically fix issues"
            echo "  --interactive         Prompt for each fix"
            echo "  --generate-fixed      Generate fixed version (Dockerfile.fixed)"
            echo "  --strict [threshold]  Exit with code 1 if score < threshold (default: 70)"
            echo "  --threshold <score>   Set minimum score and enable strict mode (0-100)"
            echo ""
            echo "Examples:"
            echo "  dck compliance dockerfile Dockerfile"
            echo "  dck compliance dockerfile --fix Dockerfile"
            echo "  dck compliance dockerfile --interactive Dockerfile"
            echo "  dck compliance dockerfile --generate-fixed Dockerfile"
            echo "  dck compliance remediate --mode auto Dockerfile"
            echo "  dck compliance container nginx"
            echo "  dck compliance image alpine:3.19"
            echo "  dck compliance lint Dockerfile.prod"
            echo "  dck compliance cis"
            echo ""
            echo "CI/CD Integration:"
            echo "  dck compliance dockerfile --strict Dockerfile        # Fail if score < 70%"
            echo "  dck compliance dockerfile --threshold 90 Dockerfile  # Fail if score < 90%"
            echo "  dck compliance dockerfile --strict 80 Dockerfile     # Fail if score < 80%"
            ;;
    esac
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    
    # Handle exit code based on compliance score
    if [[ "$STRICT_MODE" == "true" ]] && [[ $LAST_COMPLIANCE_SCORE -gt 0 ]]; then
        if [[ $LAST_COMPLIANCE_SCORE -lt $MIN_COMPLIANCE_SCORE ]]; then
            echo ""
            echo -e "${COLOR_RED}❌ Compliance check failed: Score ${LAST_COMPLIANCE_SCORE}% is below threshold ${MIN_COMPLIANCE_SCORE}%${COLOR_RESET}"
            exit 1
        else
            echo ""
            echo -e "${COLOR_GREEN}✅ Compliance check passed: Score ${LAST_COMPLIANCE_SCORE}% meets threshold ${MIN_COMPLIANCE_SCORE}%${COLOR_RESET}"
            exit 0
        fi
    fi
fi