#!/usr/bin/env bash
#
# Docker Complete Template Generator
# Generates complete Docker stack templates with all configurations
#

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/../template/complete"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Available templates
declare -A TEMPLATES=(
    ["language/node"]="Node.js with PostgreSQL, Redis, Nginx"
    ["language/python"]="Python with PostgreSQL, Redis, Celery, Nginx"
    ["language/go"]="Go with PostgreSQL, Redis"
    ["database/postgresql"]="PostgreSQL with replication, backup, monitoring"
    ["database/redis"]="Redis with persistence, RedisInsight"
    ["monitoring/prometheus"]="Prometheus stack with Grafana, exporters"
    ["iam/keycloak"]="Keycloak with PostgreSQL backend"
)

# ============================================================================
# Helper Functions
# ============================================================================

show_help() {
    cat << EOF
${BOLD}${CYAN}Docker Complete Template Generator${NC}

Generate complete, production-ready Docker stacks with all configurations.

${BOLD}Usage:${NC}
    $(basename "$0") <template> [options]
    $(basename "$0") list
    $(basename "$0") info <template>

${BOLD}Commands:${NC}
    list                List all available templates
    info <template>     Show detailed information about a template
    <template>          Generate specified template stack

${BOLD}Available Templates:${NC}
EOF
    for key in "${!TEMPLATES[@]}"; do
        printf "    ${GREEN}%-20s${NC} - %s\n" "$key" "${TEMPLATES[$key]}"
    done | sort
    
    cat << EOF

${BOLD}Options:${NC}
    --output <dir>      Output directory (default: current directory)
    --name <name>       Project name (default: template name)
    --no-env           Don't copy .env.example
    --no-compose       Don't copy docker-compose.yml
    --force            Overwrite existing files

${BOLD}Examples:${NC}
    # Generate Node.js complete stack
    $(basename "$0") language/node --output ./myapp

    # Generate PostgreSQL setup
    $(basename "$0") database/postgresql --name mydb

    # List all available templates
    $(basename "$0") list

    # Get info about a template
    $(basename "$0") info language/python

${BOLD}What's Included:${NC}
    ✅ Optimized Dockerfile
    ✅ Complete docker-compose.yml
    ✅ Environment variables (.env.example)
    ✅ Supporting configuration files
    ✅ Health checks and networking
    ✅ Development and production setups

EOF
}

list_templates() {
    echo -e "${BOLD}${CYAN}Available Complete Docker Templates:${NC}\n"
    
    echo -e "${BOLD}Programming Languages:${NC}"
    for key in "${!TEMPLATES[@]}"; do
        if [[ "$key" == language/* ]]; then
            printf "  ${GREEN}%-18s${NC} - %s\n" "$key" "${TEMPLATES[$key]}"
        fi
    done | sort
    
    echo -e "\n${BOLD}Databases:${NC}"
    for key in "${!TEMPLATES[@]}"; do
        if [[ "$key" == database/* ]]; then
            printf "  ${GREEN}%-18s${NC} - %s\n" "$key" "${TEMPLATES[$key]}"
        fi
    done | sort
    
    echo -e "\n${BOLD}Monitoring:${NC}"
    for key in "${!TEMPLATES[@]}"; do
        if [[ "$key" == monitoring/* ]]; then
            printf "  ${GREEN}%-18s${NC} - %s\n" "$key" "${TEMPLATES[$key]}"
        fi
    done | sort
    
    echo -e "\n${BOLD}Identity & Access:${NC}"
    for key in "${!TEMPLATES[@]}"; do
        if [[ "$key" == iam/* ]]; then
            printf "  ${GREEN}%-18s${NC} - %s\n" "$key" "${TEMPLATES[$key]}"
        fi
    done | sort
    
    echo ""
    echo -e "${BLUE}ℹ${NC} Use '$(basename "$0") <template>' to generate a complete stack"
}

info_template() {
    local template="$1"
    
    if [[ -z "${TEMPLATES[$template]:-}" ]]; then
        echo -e "${RED}Error: Unknown template '$template'${NC}"
        echo "Use '$(basename "$0") list' to see available templates"
        exit 1
    fi
    
    local template_path="${TEMPLATE_DIR}/${template}"
    
    if [[ ! -d "$template_path" ]]; then
        echo -e "${RED}Error: Template directory not found: $template_path${NC}"
        exit 1
    fi
    
    echo -e "${BOLD}${CYAN}Template: ${template}${NC}"
    echo -e "${TEMPLATES[$template]}\n"
    
    echo -e "${BOLD}Files included:${NC}"
    ls -la "$template_path" | grep -v "^total" | grep -v "^d" | awk '{print "  • " $9}'
    
    if [[ -f "$template_path/.env.example" ]]; then
        echo -e "\n${BOLD}Environment variables:${NC}"
        grep "^[A-Z]" "$template_path/.env.example" | cut -d= -f1 | head -10 | awk '{print "  • " $1}'
        local count=$(grep "^[A-Z]" "$template_path/.env.example" | wc -l)
        if [[ $count -gt 10 ]]; then
            echo "  ... and $((count - 10)) more"
        fi
    fi
    
    if [[ -f "$template_path/docker-compose.yml" ]]; then
        echo -e "\n${BOLD}Services:${NC}"
        grep "^  [a-z]" "$template_path/docker-compose.yml" | grep -v "#" | sed 's/://' | awk '{print "  • " $1}'
    fi
    
    echo -e "\n${BOLD}Usage:${NC}"
    echo "  $(basename "$0") $template --output ./myproject"
}

generate_template() {
    local template="$1"
    local output_dir="${OUTPUT_DIR:-.}"
    local project_name="${PROJECT_NAME:-$(basename "$template")}"
    
    if [[ -z "${TEMPLATES[$template]:-}" ]]; then
        echo -e "${RED}Error: Unknown template '$template'${NC}"
        echo "Use '$(basename "$0") list' to see available templates"
        exit 1
    fi
    
    local template_path="${TEMPLATE_DIR}/${template}"
    
    if [[ ! -d "$template_path" ]]; then
        echo -e "${RED}Error: Template directory not found: $template_path${NC}"
        exit 1
    fi
    
    # Create output directory
    if [[ ! -d "$output_dir" ]]; then
        echo -e "${BLUE}Creating directory: $output_dir${NC}"
        mkdir -p "$output_dir"
    fi
    
    echo -e "${BLUE}🐳 Generating ${BOLD}$template${NC}${BLUE} stack in ${output_dir}...${NC}"
    
    # Copy files
    local copied=0
    
    # Copy Dockerfile
    if [[ -f "$template_path/Dockerfile" ]]; then
        if [[ -f "$output_dir/Dockerfile" ]] && [[ "${FORCE:-false}" != "true" ]]; then
            echo -e "${YELLOW}⚠ Dockerfile already exists (use --force to overwrite)${NC}"
        else
            cp "$template_path/Dockerfile" "$output_dir/Dockerfile"
            echo -e "${GREEN}✅ Copied Dockerfile${NC}"
            ((copied++))
        fi
    fi
    
    # Copy docker-compose.yml
    if [[ "${NO_COMPOSE:-false}" != "true" ]] && [[ -f "$template_path/docker-compose.yml" ]]; then
        if [[ -f "$output_dir/docker-compose.yml" ]] && [[ "${FORCE:-false}" != "true" ]]; then
            echo -e "${YELLOW}⚠ docker-compose.yml already exists (use --force to overwrite)${NC}"
        else
            cp "$template_path/docker-compose.yml" "$output_dir/docker-compose.yml"
            echo -e "${GREEN}✅ Copied docker-compose.yml${NC}"
            ((copied++))
        fi
    fi
    
    # Copy .env.example
    if [[ "${NO_ENV:-false}" != "true" ]] && [[ -f "$template_path/.env.example" ]]; then
        cp "$template_path/.env.example" "$output_dir/.env.example"
        echo -e "${GREEN}✅ Copied .env.example${NC}"
        ((copied++))
        
        # Create .env if it doesn't exist
        if [[ ! -f "$output_dir/.env" ]]; then
            cp "$output_dir/.env.example" "$output_dir/.env"
            echo -e "${GREEN}✅ Created .env from .env.example${NC}"
        fi
    fi
    
    # Copy .dockerignore if exists
    if [[ -f "$template_path/.dockerignore" ]]; then
        cp "$template_path/.dockerignore" "$output_dir/.dockerignore"
        echo -e "${GREEN}✅ Copied .dockerignore${NC}"
        ((copied++))
    fi
    
    # Copy any other configuration files
    for file in "$template_path"/*.conf "$template_path"/*.yml "$template_path"/*.yaml "$template_path"/*.json "$template_path"/*.sql "$template_path"/*.sh; do
        if [[ -f "$file" ]] && [[ "$(basename "$file")" != "docker-compose.yml" ]]; then
            cp "$file" "$output_dir/"
            echo -e "${GREEN}✅ Copied $(basename "$file")${NC}"
            ((copied++))
        fi
    done 2>/dev/null || true
    
    if [[ $copied -eq 0 ]]; then
        echo -e "${RED}No files were copied!${NC}"
        exit 1
    fi
    
    echo ""
    echo -e "${GREEN}${BOLD}✅ Template generated successfully!${NC}"
    echo ""
    echo -e "${BOLD}Template Information:${NC}"
    echo "  Type: ${TEMPLATES[$template]}"
    echo "  Location: $output_dir"
    echo "  Files copied: $copied"
    
    echo ""
    echo -e "${BLUE}ℹ${NC} Next steps:"
    echo "  1. Review and edit .env file with your values"
    echo "  2. Customize Dockerfile and docker-compose.yml as needed"
    echo "  3. Run: docker-compose up -d"
    echo ""
    echo -e "${BOLD}Quick start:${NC}"
    echo "  cd $output_dir"
    echo "  vim .env"
    echo "  docker-compose up -d"
}

# ============================================================================
# Main Execution
# ============================================================================

# Parse arguments
COMMAND="${1:-}"
shift || true

OUTPUT_DIR=""
PROJECT_NAME=""
NO_ENV=false
NO_COMPOSE=false
FORCE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --name)
            PROJECT_NAME="$2"
            shift 2
            ;;
        --no-env)
            NO_ENV=true
            shift
            ;;
        --no-compose)
            NO_COMPOSE=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            if [[ -n "$1" ]]; then
                echo -e "${RED}Unknown option: $1${NC}"
                echo "Use --help for usage information"
                exit 1
            fi
            shift
            ;;
    esac
done

# Execute command
case "$COMMAND" in
    list)
        list_templates
        ;;
    info)
        if [[ -z "${1:-}" ]]; then
            echo -e "${RED}Error: Template name required${NC}"
            echo "Usage: $(basename "$0") info <template>"
            exit 1
        fi
        info_template "$1"
        ;;
    help|--help)
        show_help
        ;;
    "")
        echo -e "${RED}Error: No command specified${NC}"
        echo "Use --help for usage information"
        exit 1
        ;;
    *)
        generate_template "$COMMAND"
        ;;
esac