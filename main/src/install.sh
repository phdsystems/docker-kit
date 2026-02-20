#!/bin/bash

# DockerKit Installation Script
# Installs DockerKit as a standalone tool on the system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'

# Source Docker wrapper for sudo handling
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/docker-wrapper.sh"
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Installation configuration
INSTALL_DIR="${DOCKERKIT_INSTALL_DIR:-/opt/dockerkit}"
BIN_DIR="${DOCKERKIT_BIN_DIR:-/usr/local/bin}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERKIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     DockerKit Installation Script      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    # Check if running as root or with sudo
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Error: This script must be run as root or with sudo${NC}"
        echo "Please run: sudo $0"
        exit 1
    fi
    
    # Check for Docker
    if ! command -v docker &>/dev/null; then
        echo -e "${YELLOW}Warning: Docker is not installed${NC}"
        echo "DockerKit requires Docker to function properly."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        echo -e "${GREEN}✓ Docker found${NC}"
    fi
    
    # Check for required commands
    for cmd in bash grep sed awk; do
        if command -v $cmd &>/dev/null; then
            echo -e "${GREEN}✓ $cmd found${NC}"
        else
            echo -e "${RED}✗ $cmd not found${NC}"
            exit 1
        fi
    done
}

# Create installation directory
create_install_dir() {
    echo -e "\n${YELLOW}Creating installation directory...${NC}"
    
    if [[ -d "$INSTALL_DIR" ]]; then
        echo -e "${YELLOW}Installation directory already exists${NC}"
        read -p "Overwrite existing installation? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$INSTALL_DIR"
        else
            echo "Installation cancelled"
            exit 0
        fi
    fi
    
    mkdir -p "$INSTALL_DIR"
    echo -e "${GREEN}✓ Created $INSTALL_DIR${NC}"
}

# Copy files
copy_files() {
    echo -e "\n${YELLOW}Copying DockerKit files...${NC}"
    
    # Copy main script
    cp "$DOCKERKIT_DIR/dockerkit" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/dockerkit"
    echo -e "${GREEN}✓ Copied main script${NC}"
    
    # Copy scripts directory
    cp -r "$DOCKERKIT_DIR/scripts" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR"/scripts/*.sh
    echo -e "${GREEN}✓ Copied scripts${NC}"
    
    # Copy library files if they exist
    if [[ -d "$DOCKERKIT_DIR/lib" ]]; then
        cp -r "$DOCKERKIT_DIR/lib" "$INSTALL_DIR/"
        echo -e "${GREEN}✓ Copied libraries${NC}"
    fi
    
    # Copy documentation
    if [[ -d "$DOCKERKIT_DIR/docs" ]]; then
        cp -r "$DOCKERKIT_DIR/docs" "$INSTALL_DIR/"
        echo -e "${GREEN}✓ Copied documentation${NC}"
    fi
    
    # Copy README
    if [[ -f "$DOCKERKIT_DIR/README.md" ]]; then
        cp "$DOCKERKIT_DIR/README.md" "$INSTALL_DIR/"
        echo -e "${GREEN}✓ Copied README${NC}"
    fi
}

# Create symlink
create_symlink() {
    echo -e "\n${YELLOW}Creating command symlink...${NC}"
    
    # Remove existing symlink if it exists
    if [[ -L "$BIN_DIR/dockerkit" ]]; then
        rm "$BIN_DIR/dockerkit"
    fi
    
    # Create new symlink
    ln -s "$INSTALL_DIR/dockerkit" "$BIN_DIR/dockerkit"
    echo -e "${GREEN}✓ Created symlink at $BIN_DIR/dockerkit${NC}"
}

# Setup completion (optional)
setup_completion() {
    echo -e "\n${YELLOW}Setting up bash completion...${NC}"
    
    # Create completion script
    cat > "$INSTALL_DIR/dockerkit-completion.bash" << 'EOF'
# DockerKit bash completion
_dockerkit() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    # Main commands
    opts="images containers volumes networks search system security cleanup stats monitor analyze export help version"
    
    # Handle subcommands
    case "${prev}" in
        search)
            local search_opts="images containers volumes networks"
            COMPREPLY=( $(compgen -W "${search_opts}" -- ${cur}) )
            return 0
            ;;
        export)
            local export_opts="images containers volumes networks"
            COMPREPLY=( $(compgen -W "${export_opts}" -- ${cur}) )
            return 0
            ;;
    esac
    
    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    return 0
}
complete -F _dockerkit dockerkit
complete -F _dockerkit dk
EOF
    
    # Add to bashrc if not already present
    if ! grep -q "dockerkit-completion.bash" /etc/bash.bashrc 2>/dev/null; then
        echo "source $INSTALL_DIR/dockerkit-completion.bash" >> /etc/bash.bashrc
        echo -e "${GREEN}✓ Added bash completion${NC}"
    else
        echo -e "${YELLOW}Bash completion already configured${NC}"
    fi
}

# Create uninstaller
create_uninstaller() {
    echo -e "\n${YELLOW}Creating uninstaller...${NC}"
    
    cat > "$INSTALL_DIR/uninstall.sh" << EOF
#!/bin/bash
# DockerKit Uninstaller

echo "Uninstalling DockerKit..."

# Remove symlink
rm -f "$BIN_DIR/dockerkit"
echo "✓ Removed command symlink"

# Remove completion
sed -i '/dockerkit-completion.bash/d' /etc/bash.bashrc 2>/dev/null
echo "✓ Removed bash completion"

# Remove installation directory
rm -rf "$INSTALL_DIR"
echo "✓ Removed installation directory"

echo "DockerKit has been uninstalled"
EOF
    
    chmod +x "$INSTALL_DIR/uninstall.sh"
    echo -e "${GREEN}✓ Created uninstaller${NC}"
}

# Verify installation
verify_installation() {
    echo -e "\n${YELLOW}Verifying installation...${NC}"
    
    if dockerkit version &>/dev/null; then
        echo -e "${GREEN}✓ DockerKit installed successfully!${NC}"
        return 0
    else
        echo -e "${RED}✗ Installation verification failed${NC}"
        return 1
    fi
}

# Main installation
main() {
    check_prerequisites
    create_install_dir
    copy_files
    create_symlink
    setup_completion
    create_uninstaller
    
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     Installation Complete!             ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""
    
    if verify_installation; then
        echo -e "${GREEN}DockerKit has been installed to: $INSTALL_DIR${NC}"
        echo -e "${GREEN}Command available at: $BIN_DIR/dockerkit${NC}"
        echo ""
        echo "You can now use DockerKit with:"
        echo "  dockerkit --help"
        echo ""
        echo "To uninstall, run:"
        echo "  sudo $INSTALL_DIR/uninstall.sh"
    else
        echo -e "${RED}Installation completed but verification failed${NC}"
        echo "Please check the installation and try running:"
        echo "  $BIN_DIR/dockerkit --help"
    fi
}

# Run main installation
main "$@"