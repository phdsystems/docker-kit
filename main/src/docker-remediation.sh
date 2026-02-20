#!/usr/bin/env bash
#
# Docker Compliance Auto-Remediation Module
# Automatically fixes common Docker security and best practice issues
#

set -euo pipefail

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/docker-wrapper.sh" 2>/dev/null || true

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Remediation modes
REMEDIATION_MODE="manual"  # manual, auto, interactive
BACKUP_ENABLED=true
VERBOSE=false

# Fix tracking
declare -A FIXES_APPLIED
declare -A FIXES_SKIPPED
TOTAL_FIXES=0
APPLIED_FIXES=0
SKIPPED_FIXES=0

# ============================================================================
# Helper Functions
# ============================================================================

log_fix() {
    echo -e "${GREEN}✓${NC} $1"
}

log_skip() {
    echo -e "${YELLOW}⊘${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

backup_file() {
    local file="$1"
    local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
    
    if [[ "$BACKUP_ENABLED" == "true" ]]; then
        cp "$file" "$backup"
        log_info "Created backup: $backup"
        echo "$backup"
    fi
}

prompt_user() {
    local message="$1"
    local response
    
    if [[ "$REMEDIATION_MODE" == "auto" ]]; then
        return 0  # Always apply in auto mode
    elif [[ "$REMEDIATION_MODE" == "interactive" ]]; then
        echo -en "${CYAN}?${NC} $message [Y/n]: "
        read -r response
        [[ -z "$response" || "$response" =~ ^[Yy] ]]
    else
        return 1  # Never apply in manual mode
    fi
}

# ============================================================================
# Dockerfile Remediation Functions
# ============================================================================

fix_missing_user() {
    local dockerfile="$1"
    local fixed_content="$2"
    
    echo -e "\n${YELLOW}→ Fixing: Missing non-root user${NC}" >&2
    
    # Check if USER directive exists
    if ! grep -q "^USER " "$dockerfile"; then
        # Find the best place to add USER directive (before ENTRYPOINT/CMD or at end)
        local insert_line
        if grep -n "^ENTRYPOINT\|^CMD" "$dockerfile" | head -1 > /dev/null; then
            insert_line=$(grep -n "^ENTRYPOINT\|^CMD" "$dockerfile" | head -1 | cut -d: -f1)
        else
            insert_line=$(wc -l < "$dockerfile")
        fi
        
        # Add user creation and USER directive
        local user_setup="# Create non-root user for security
RUN addgroup -g 1001 appuser && \\
    adduser -D -u 1001 -G appuser appuser

USER appuser"
        
        if prompt_user "Add non-root user 'appuser'?"; then
            # Insert user setup before the identified line
            echo "$fixed_content" | awk -v line="$insert_line" -v content="$user_setup" '
                NR==line { print content }
                { print }
            '
            log_fix "Added non-root user 'appuser'"
            ((APPLIED_FIXES++))
            FIXES_APPLIED["missing_user"]=1
        else
            echo "$fixed_content"
            log_skip "Skipped adding non-root user"
            ((SKIPPED_FIXES++))
            FIXES_SKIPPED["missing_user"]=1
        fi
    else
        echo "$fixed_content"
    fi
}

fix_version_pinning() {
    local dockerfile="$1"
    local fixed_content="$2"
    
    echo -e "\n${YELLOW}→ Fixing: Version pinning${NC}"
    
    # Fix base image versions
    if echo "$fixed_content" | grep -q "^FROM.*:latest"; then
        if prompt_user "Pin base image versions (replace :latest tags)?"; then
            fixed_content=$(echo "$fixed_content" | sed -E '
                s/^FROM alpine:latest/FROM alpine:3.19.1/
                s/^FROM ubuntu:latest/FROM ubuntu:22.04/
                s/^FROM node:latest/FROM node:20-alpine/
                s/^FROM python:latest/FROM python:3.12-slim/
                s/^FROM nginx:latest/FROM nginx:1.25-alpine/
                s/^FROM redis:latest/FROM redis:7-alpine/
                s/^FROM postgres:latest/FROM postgres:16-alpine/
                s/^FROM mysql:latest/FROM mysql:8.0/
            ')
            log_fix "Pinned base image versions"
            ((APPLIED_FIXES++))
            FIXES_APPLIED["version_pinning"]=1
        else
            log_skip "Skipped version pinning"
            ((SKIPPED_FIXES++))
            FIXES_SKIPPED["version_pinning"]=1
        fi
    fi
    
    echo "$fixed_content"
}

fix_missing_healthcheck() {
    local dockerfile="$1"
    local fixed_content="$2"
    
    echo -e "\n${YELLOW}→ Fixing: Missing HEALTHCHECK${NC}"
    
    if ! echo "$fixed_content" | grep -q "^HEALTHCHECK"; then
        # Determine appropriate healthcheck based on common patterns
        local healthcheck_cmd=""
        
        if echo "$fixed_content" | grep -q "nginx"; then
            healthcheck_cmd="HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \\
  CMD curl -f http://localhost/ || exit 1"
        elif echo "$fixed_content" | grep -q "node\|npm"; then
            healthcheck_cmd="HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \\
  CMD node -e \"require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})\" || exit 1"
        elif echo "$fixed_content" | grep -q "python"; then
            healthcheck_cmd="HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \\
  CMD python -c \"import urllib.request; urllib.request.urlopen('http://localhost:8000/health')\" || exit 1"
        else
            healthcheck_cmd="HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \\
  CMD curl -f http://localhost/health || exit 1"
        fi
        
        if prompt_user "Add HEALTHCHECK directive?"; then
            # Add healthcheck before CMD/ENTRYPOINT or at end
            if echo "$fixed_content" | grep -q "^CMD\|^ENTRYPOINT"; then
                fixed_content=$(echo "$fixed_content" | awk -v hc="$healthcheck_cmd" '
                    !printed && /^(CMD|ENTRYPOINT)/ { print hc; printed=1 }
                    { print }
                ')
            else
                fixed_content="$fixed_content

$healthcheck_cmd"
            fi
            log_fix "Added HEALTHCHECK directive"
            ((APPLIED_FIXES++))
            FIXES_APPLIED["missing_healthcheck"]=1
        else
            log_skip "Skipped adding HEALTHCHECK"
            ((SKIPPED_FIXES++))
            FIXES_SKIPPED["missing_healthcheck"]=1
        fi
    fi
    
    echo "$fixed_content"
}

fix_hardcoded_secrets() {
    local dockerfile="$1"
    local fixed_content="$2"
    
    echo -e "\n${YELLOW}→ Fixing: Hardcoded secrets${NC}"
    
    # Replace ENV secrets with ARG or remove them
    if echo "$fixed_content" | grep -qE "ENV.*(PASSWORD|SECRET|KEY|TOKEN|API_KEY)"; then
        if prompt_user "Replace hardcoded secrets with build arguments?"; then
            fixed_content=$(echo "$fixed_content" | sed -E '
                s/^ENV (.*PASSWORD[^=]*)=.*/# Security: Use --build-arg instead\nARG \1\nENV \1=${\1}/
                s/^ENV (.*SECRET[^=]*)=.*/# Security: Use --build-arg instead\nARG \1\nENV \1=${\1}/
                s/^ENV (.*KEY[^=]*)=.*/# Security: Use --build-arg instead\nARG \1\nENV \1=${\1}/
                s/^ENV (.*TOKEN[^=]*)=.*/# Security: Use --build-arg instead\nARG \1\nENV \1=${\1}/
            ')
            log_fix "Converted hardcoded secrets to build arguments"
            ((APPLIED_FIXES++))
            FIXES_APPLIED["hardcoded_secrets"]=1
        else
            log_skip "Skipped fixing hardcoded secrets"
            ((SKIPPED_FIXES++))
            FIXES_SKIPPED["hardcoded_secrets"]=1
        fi
    fi
    
    echo "$fixed_content"
}

fix_add_misuse() {
    local dockerfile="$1"
    local fixed_content="$2"
    
    echo -e "\n${YELLOW}→ Fixing: ADD misuse${NC}"
    
    # Replace ADD with COPY where appropriate
    if echo "$fixed_content" | grep -q "^ADD "; then
        if prompt_user "Replace ADD with COPY (except for tar archives)?"; then
            # Replace ADD with COPY except for .tar files
            fixed_content=$(echo "$fixed_content" | awk '
                /^ADD http/ {
                    print "# Fixed: Use RUN to download files instead of ADD"
                    url = $2
                    dest = $3
                    print "RUN curl -fsSL " url " -o " dest
                    next
                }
                /^ADD/ && !/\.tar/ {
                    sub(/^ADD/, "COPY")
                }
                { print }
            ')
            log_fix "Replaced ADD with appropriate commands"
            ((APPLIED_FIXES++))
            FIXES_APPLIED["add_misuse"]=1
        else
            log_skip "Skipped fixing ADD usage"
            ((SKIPPED_FIXES++))
            FIXES_SKIPPED["add_misuse"]=1
        fi
    fi
    
    echo "$fixed_content"
}

fix_cache_cleanup() {
    local dockerfile="$1"
    local fixed_content="$2"
    
    echo -e "\n${YELLOW}→ Fixing: Package cache cleanup${NC}"
    
    # Fix APT cache cleanup
    if echo "$fixed_content" | grep -q "apt-get install" && ! echo "$fixed_content" | grep -q "rm -rf /var/lib/apt/lists"; then
        if prompt_user "Add APT cache cleanup?"; then
            fixed_content=$(echo "$fixed_content" | sed '/apt-get install/ {
                s/$/\\/
                a\    && rm -rf /var/lib/apt/lists/*
            }')
            log_fix "Added APT cache cleanup"
            ((APPLIED_FIXES++))
            FIXES_APPLIED["apt_cache"]=1
        else
            log_skip "Skipped APT cache cleanup"
            ((SKIPPED_FIXES++))
        fi
    fi
    
    # Fix APK cache cleanup
    if echo "$fixed_content" | grep -q "apk add" && ! echo "$fixed_content" | grep -q "no-cache\|rm -rf /var/cache/apk"; then
        if prompt_user "Add APK cache cleanup?"; then
            fixed_content=$(echo "$fixed_content" | sed 's/apk add/apk add --no-cache/')
            log_fix "Added APK --no-cache flag"
            ((APPLIED_FIXES++))
            FIXES_APPLIED["apk_cache"]=1
        else
            log_skip "Skipped APK cache cleanup"
            ((SKIPPED_FIXES++))
        fi
    fi
    
    echo "$fixed_content"
}

fix_missing_workdir() {
    local dockerfile="$1"
    local fixed_content="$2"
    
    echo -e "\n${YELLOW}→ Fixing: Missing WORKDIR${NC}"
    
    if ! echo "$fixed_content" | grep -q "^WORKDIR"; then
        if prompt_user "Add WORKDIR /app?"; then
            # Add WORKDIR after FROM or USER
            if echo "$fixed_content" | grep -q "^USER"; then
                fixed_content=$(echo "$fixed_content" | awk '
                    /^USER/ { print; print "WORKDIR /app"; next }
                    { print }
                ')
            else
                fixed_content=$(echo "$fixed_content" | awk '
                    /^FROM/ { print; print "WORKDIR /app"; next }
                    { print }
                ')
            fi
            log_fix "Added WORKDIR /app"
            ((APPLIED_FIXES++))
            FIXES_APPLIED["missing_workdir"]=1
        else
            log_skip "Skipped adding WORKDIR"
            ((SKIPPED_FIXES++))
            FIXES_SKIPPED["missing_workdir"]=1
        fi
    fi
    
    echo "$fixed_content"
}

fix_metadata_labels() {
    local dockerfile="$1"
    local fixed_content="$2"
    
    echo -e "\n${YELLOW}→ Fixing: Missing metadata labels${NC}"
    
    if ! echo "$fixed_content" | grep -q "^LABEL"; then
        if prompt_user "Add metadata labels?"; then
            local labels="# Metadata labels
LABEL maintainer=\"your-email@example.com\"
LABEL version=\"1.0.0\"
LABEL description=\"Application container\"
LABEL org.opencontainers.image.source=\"https://github.com/yourusername/yourrepo\""
            
            # Add labels after FROM
            fixed_content=$(echo "$fixed_content" | awk -v labels="$labels" '
                /^FROM/ { print; print labels; next }
                { print }
            ')
            log_fix "Added metadata labels"
            ((APPLIED_FIXES++))
            FIXES_APPLIED["metadata_labels"]=1
        else
            log_skip "Skipped adding metadata labels"
            ((SKIPPED_FIXES++))
            FIXES_SKIPPED["metadata_labels"]=1
        fi
    fi
    
    echo "$fixed_content"
}

# ============================================================================
# Main Remediation Function
# ============================================================================

remediate_dockerfile() {
    local dockerfile="$1"
    local mode="${2:-manual}"
    local output_file="${3:-}"
    
    REMEDIATION_MODE="$mode"
    
    if [[ ! -f "$dockerfile" ]]; then
        log_error "Dockerfile not found: $dockerfile"
        return 1
    fi
    
    echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║     Docker Compliance Auto-Remediation        ║${NC}"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}📁 File:${NC} $dockerfile"
    echo -e "${BLUE}🔧 Mode:${NC} $REMEDIATION_MODE"
    
    if [[ -n "$output_file" ]]; then
        echo -e "${BLUE}📝 Output:${NC} $output_file"
    else
        echo -e "${BLUE}📝 Output:${NC} In-place (with backup)"
    fi
    
    echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Create backup if modifying in-place
    local backup_file=""
    if [[ -z "$output_file" ]] && [[ "$BACKUP_ENABLED" == "true" ]]; then
        backup_file=$(backup_file "$dockerfile")
    fi
    
    # Read current content
    local fixed_content
    fixed_content=$(cat "$dockerfile")
    
    # Apply fixes in sequence
    fixed_content=$(fix_version_pinning "$dockerfile" "$fixed_content")
    fixed_content=$(fix_metadata_labels "$dockerfile" "$fixed_content")
    fixed_content=$(fix_missing_user "$dockerfile" "$fixed_content")
    fixed_content=$(fix_missing_healthcheck "$dockerfile" "$fixed_content")
    fixed_content=$(fix_hardcoded_secrets "$dockerfile" "$fixed_content")
    fixed_content=$(fix_add_misuse "$dockerfile" "$fixed_content")
    fixed_content=$(fix_cache_cleanup "$dockerfile" "$fixed_content")
    fixed_content=$(fix_missing_workdir "$dockerfile" "$fixed_content")
    
    # Write output
    if [[ -n "$output_file" ]]; then
        echo "$fixed_content" > "$output_file"
        log_info "Fixed Dockerfile written to: $output_file"
    elif [[ "$APPLIED_FIXES" -gt 0 ]]; then
        echo "$fixed_content" > "$dockerfile"
        log_info "Original Dockerfile updated (backup: $backup_file)"
    else
        log_info "No fixes applied - Dockerfile unchanged"
    fi
    
    # Print summary
    echo ""
    echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN}📊 Remediation Summary${NC}"
    echo -e "${GREEN}✓ Applied:${NC} $APPLIED_FIXES fixes"
    echo -e "${YELLOW}⊘ Skipped:${NC} $SKIPPED_FIXES fixes"
    
    if [[ "$APPLIED_FIXES" -gt 0 ]]; then
        echo ""
        echo -e "${GREEN}Applied fixes:${NC}"
        for fix in "${!FIXES_APPLIED[@]}"; do
            echo "  • $fix"
        done
    fi
    
    if [[ "$SKIPPED_FIXES" -gt 0 ]] && [[ "$REMEDIATION_MODE" != "auto" ]]; then
        echo ""
        echo -e "${YELLOW}Skipped fixes:${NC}"
        for fix in "${!FIXES_SKIPPED[@]}"; do
            echo "  • $fix"
        done
    fi
    
    return 0
}

# ============================================================================
# CLI Interface
# ============================================================================

show_help() {
    cat << EOF
Docker Compliance Auto-Remediation

Usage: $(basename "$0") [OPTIONS] <dockerfile>

Options:
    --mode <mode>       Remediation mode:
                        - manual: Show fixes but don't apply (default)
                        - auto: Apply all fixes automatically
                        - interactive: Prompt for each fix
    
    --output <file>     Write fixed Dockerfile to specified file
                        (default: update in-place with backup)
    
    --no-backup         Don't create backup when updating in-place
    
    --verbose           Show detailed output
    
    --help              Show this help message

Examples:
    # Interactive mode - prompts for each fix
    $(basename "$0") --mode interactive Dockerfile
    
    # Auto-fix all issues
    $(basename "$0") --mode auto Dockerfile
    
    # Generate fixed version without modifying original
    $(basename "$0") --output Dockerfile.fixed Dockerfile
    
    # Auto-fix with custom output
    $(basename "$0") --mode auto --output Dockerfile.secure Dockerfile

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --mode)
            REMEDIATION_MODE="$2"
            shift 2
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --no-backup)
            BACKUP_ENABLED=false
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            DOCKERFILE="$1"
            shift
            ;;
    esac
done

# Main execution
if [[ -z "${DOCKERFILE:-}" ]]; then
    echo -e "${RED}Error: Dockerfile path required${NC}"
    echo ""
    show_help
    exit 1
fi

remediate_dockerfile "$DOCKERFILE" "$REMEDIATION_MODE" "${OUTPUT_FILE:-}"