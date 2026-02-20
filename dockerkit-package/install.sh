#!/bin/bash

# ==============================================================================
# DockerKit Installation Script
# ==============================================================================
# Installs DockerKit tools for Docker compliance and management
# ==============================================================================

set -euo pipefail

# Configuration
INSTALL_DIR="${DOCKERKIT_HOME:-/usr/local/dockerkit}"
BIN_DIR="${BIN_DIR:-/usr/local/bin}"
VERSION="1.0.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# ==============================================================================
# Functions
# ==============================================================================

print_banner() {
    echo -e "${BLUE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    DockerKit Installer                       ║"
    echo "║                       Version $VERSION                       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_requirements() {
    local missing_deps=()
    
    # Check for required commands
    command -v docker >/dev/null 2>&1 || missing_deps+=("docker")
    command -v bash >/dev/null 2>&1 || missing_deps+=("bash")
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${RED}Error: Missing required dependencies:${NC}"
        printf '%s\n' "${missing_deps[@]}"
        echo -e "${YELLOW}Please install missing dependencies and try again.${NC}"
        exit 1
    fi
}

create_directories() {
    echo -e "${BLUE}Creating installation directories...${NC}"
    
    # Create directories with sudo if needed
    if [[ -w "$(dirname "$INSTALL_DIR")" ]]; then
        mkdir -p "$INSTALL_DIR"/{bin,lib,templates,docs}
    else
        echo -e "${YELLOW}Need sudo access to create directories${NC}"
        sudo mkdir -p "$INSTALL_DIR"/{bin,lib,templates,docs}
        sudo chown -R "$(whoami)" "$INSTALL_DIR"
    fi
}

install_files() {
    echo -e "${BLUE}Installing DockerKit files...${NC}"
    
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Copy main binaries
    cp -r "$script_dir/bin/"* "$INSTALL_DIR/bin/" 2>/dev/null || true
    cp -r "$script_dir/main/src/"* "$INSTALL_DIR/lib/" 2>/dev/null || true
    cp -r "$script_dir/templates/"* "$INSTALL_DIR/templates/" 2>/dev/null || true
    cp -r "$script_dir/docs/"* "$INSTALL_DIR/docs/" 2>/dev/null || true
    
    # Make scripts executable
    chmod +x "$INSTALL_DIR/bin/"* 2>/dev/null || true
    chmod +x "$INSTALL_DIR/lib/"*.sh 2>/dev/null || true
}

create_symlinks() {
    echo -e "${BLUE}Creating command symlinks...${NC}"
    
    # Create symlinks in bin directory
    local commands=("dck" "dockerkit" "docker-comply" "docker-template")
    
    for cmd in "${commands[@]}"; do
        if [[ -f "$INSTALL_DIR/bin/$cmd" ]]; then
            if [[ -w "$BIN_DIR" ]]; then
                ln -sf "$INSTALL_DIR/bin/$cmd" "$BIN_DIR/$cmd"
            else
                echo -e "${YELLOW}Need sudo access to create symlinks${NC}"
                sudo ln -sf "$INSTALL_DIR/bin/$cmd" "$BIN_DIR/$cmd"
            fi
            echo -e "${GREEN}✓${NC} Installed command: $cmd"
        fi
    done
}

setup_environment() {
    echo -e "${BLUE}Setting up environment...${NC}"
    
    # Create environment file
    cat > "$INSTALL_DIR/.env" << EOF
# DockerKit Environment Configuration
export DOCKERKIT_HOME="$INSTALL_DIR"
export DOCKERKIT_VERSION="$VERSION"
export PATH="\$PATH:$INSTALL_DIR/bin"
EOF
    
    # Add to shell profile if not already present
    local shell_rc=""
    if [[ -n "${BASH_VERSION:-}" ]]; then
        shell_rc="$HOME/.bashrc"
    elif [[ -n "${ZSH_VERSION:-}" ]]; then
        shell_rc="$HOME/.zshrc"
    fi
    
    if [[ -n "$shell_rc" ]] && [[ -f "$shell_rc" ]]; then
        if ! grep -q "DOCKERKIT_HOME" "$shell_rc"; then
            echo "" >> "$shell_rc"
            echo "# DockerKit Configuration" >> "$shell_rc"
            echo "export DOCKERKIT_HOME=\"$INSTALL_DIR\"" >> "$shell_rc"
            echo "export PATH=\"\$PATH:$INSTALL_DIR/bin\"" >> "$shell_rc"
            echo -e "${GREEN}✓${NC} Updated shell configuration: $shell_rc"
        fi
    fi
}

verify_installation() {
    echo -e "${BLUE}Verifying installation...${NC}"
    
    local failed=0
    
    # Check main executable
    if [[ -x "$INSTALL_DIR/bin/dck" ]]; then
        echo -e "${GREEN}✓${NC} Main executable installed"
    else
        echo -e "${RED}✗${NC} Main executable not found"
        failed=1
    fi
    
    # Check library files
    if [[ -d "$INSTALL_DIR/lib" ]] && [[ "$(ls -A "$INSTALL_DIR/lib")" ]]; then
        echo -e "${GREEN}✓${NC} Library files installed"
    else
        echo -e "${RED}✗${NC} Library files not found"
        failed=1
    fi
    
    # Check templates
    if [[ -d "$INSTALL_DIR/templates" ]] && [[ "$(ls -A "$INSTALL_DIR/templates")" ]]; then
        echo -e "${GREEN}✓${NC} Templates installed"
    else
        echo -e "${YELLOW}⚠${NC} Templates not found (optional)"
    fi
    
    return $failed
}

print_success() {
    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║            DockerKit Installation Successful!                ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BOLD}Installation Details:${NC}"
    echo -e "  Install Directory: ${BLUE}$INSTALL_DIR${NC}"
    echo -e "  Binary Directory:  ${BLUE}$BIN_DIR${NC}"
    echo -e "  Version:          ${BLUE}$VERSION${NC}"
    echo ""
    echo -e "${BOLD}Available Commands:${NC}"
    echo -e "  ${GREEN}dck${NC}              - Main DockerKit CLI"
    echo -e "  ${GREEN}dockerkit${NC}        - Alternative CLI name"
    echo -e "  ${GREEN}docker-comply${NC}    - Docker compliance checker"
    echo -e "  ${GREEN}docker-template${NC}  - Template generator"
    echo ""
    echo -e "${BOLD}Quick Start:${NC}"
    echo -e "  ${BLUE}dck --help${NC}       - Show help"
    echo -e "  ${BLUE}dck version${NC}      - Show version"
    echo -e "  ${BLUE}dck check${NC}        - Run compliance check"
    echo -e "  ${BLUE}dck template ls${NC}  - List templates"
    echo ""
    echo -e "${YELLOW}Note: You may need to restart your shell or run:${NC}"
    echo -e "  ${BLUE}source ~/.bashrc${NC} (or ~/.zshrc)"
    echo ""
}

uninstall() {
    echo -e "${RED}${BOLD}Uninstalling DockerKit...${NC}"
    
    # Remove symlinks
    local commands=("dck" "dockerkit" "docker-comply" "docker-template")
    for cmd in "${commands[@]}"; do
        if [[ -L "$BIN_DIR/$cmd" ]]; then
            if [[ -w "$BIN_DIR" ]]; then
                rm -f "$BIN_DIR/$cmd"
            else
                sudo rm -f "$BIN_DIR/$cmd"
            fi
            echo -e "${GREEN}✓${NC} Removed command: $cmd"
        fi
    done
    
    # Remove installation directory
    if [[ -d "$INSTALL_DIR" ]]; then
        if [[ -w "$(dirname "$INSTALL_DIR")" ]]; then
            rm -rf "$INSTALL_DIR"
        else
            sudo rm -rf "$INSTALL_DIR"
        fi
        echo -e "${GREEN}✓${NC} Removed installation directory"
    fi
    
    echo -e "${GREEN}DockerKit has been uninstalled.${NC}"
    echo -e "${YELLOW}Note: Shell configuration entries were not removed.${NC}"
}

# ==============================================================================
# Main Installation
# ==============================================================================

main() {
    # Parse arguments
    case "${1:-}" in
        --uninstall)
            uninstall
            exit 0
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --uninstall    Remove DockerKit installation"
            echo "  --prefix DIR   Set installation prefix (default: /usr/local/dockerkit)"
            echo "  --bin DIR      Set binary directory (default: /usr/local/bin)"
            echo "  --help         Show this help message"
            exit 0
            ;;
        --prefix)
            INSTALL_DIR="${2:-$INSTALL_DIR}"
            shift 2
            ;;
        --bin)
            BIN_DIR="${2:-$BIN_DIR}"
            shift 2
            ;;
    esac
    
    print_banner
    check_requirements
    create_directories
    install_files
    create_symlinks
    setup_environment
    
    if verify_installation; then
        print_success
    else
        echo -e "${RED}Installation completed with errors. Please check the output above.${NC}"
        exit 1
    fi
}

# Run main function
main "$@"