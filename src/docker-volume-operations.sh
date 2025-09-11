#!/bin/bash

# DockerKit Volume Operations  
# Provides create, remove, inspect, prune operations for volumes

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
VOLUME=""
DRIVER="local"
LABELS=()
OPTIONS=()
FORCE=false
ALL=false
FILTER=""

# Show help
show_help() {
    cat << EOF
DockerKit Volume Operations

USAGE:
    $(basename "$0") <action> [volume] [options]

ACTIONS:
    create      Create a new volume
    remove|rm   Remove volume(s)
    inspect     Inspect volume details
    list|ls     List volumes
    prune       Remove unused volumes
    backup      Backup volume data
    restore     Restore volume data
    clone       Clone a volume
    size        Show volume sizes

CREATE OPTIONS:
    -d, --driver DRIVER     Volume driver (default: local)
    -o, --opt KEY=VALUE     Driver options (can be used multiple times)
    -l, --label KEY=VALUE   Set metadata labels (can be used multiple times)

REMOVE OPTIONS:
    -f, --force             Force removal
    -a, --all               Remove all unused volumes

LIST OPTIONS:
    -f, --filter FILTER     Filter volumes (e.g., dangling=true)
    -q, --quiet             Only display volume names
    --format FORMAT         Format output using Go template

BACKUP/RESTORE OPTIONS:
    -o, --output FILE       Output file for backup
    -i, --input FILE        Input file for restore
    -c, --compress          Compress backup with gzip

EXAMPLES:
    # Create a named volume
    $(basename "$0") create my-data

    # Create volume with options
    $(basename "$0") create my-volume --driver local --opt type=tmpfs --opt device=tmpfs

    # Create volume with labels
    $(basename "$0") create my-app-data --label app=myapp --label env=prod

    # Remove a volume
    $(basename "$0") remove my-old-data

    # Force remove volume
    $(basename "$0") remove my-volume --force

    # List all volumes
    $(basename "$0") list

    # List with filter
    $(basename "$0") list --filter dangling=true

    # Inspect volume
    $(basename "$0") inspect my-volume

    # Prune unused volumes
    $(basename "$0") prune

    # Backup volume to tar
    $(basename "$0") backup my-data -o my-data-backup.tar

    # Restore volume from backup
    $(basename "$0") restore my-data -i my-data-backup.tar

    # Clone a volume
    $(basename "$0") clone source-volume target-volume

    # Show volume sizes
    $(basename "$0") size

EOF
}

# Create volume
create_volume() {
    if [[ -z "$VOLUME" ]]; then
        echo -e "${RED}Error: No volume name specified${NC}"
        exit 1
    fi
    
    local create_args=""
    
    if [[ -n "$DRIVER" ]]; then
        create_args="$create_args --driver $DRIVER"
    fi
    
    for label in "${LABELS[@]}"; do
        create_args="$create_args --label $label"
    done
    
    for option in "${OPTIONS[@]}"; do
        create_args="$create_args --opt $option"
    done
    
    echo -e "${CYAN}Creating volume: $VOLUME${NC}"
    
    if $DOCKER_CMD volume create $create_args "$VOLUME"; then
        echo -e "${GREEN}✓ Volume created successfully${NC}"
        
        # Show volume details
        echo -e "\n${CYAN}Volume details:${NC}"
        $DOCKER_CMD volume inspect "$VOLUME" | jq -r '.[0] | {
            Name: .Name,
            Driver: .Driver,
            Mountpoint: .Mountpoint,
            CreatedAt: .CreatedAt,
            Labels: .Labels,
            Options: .Options
        }' 2>/dev/null || $DOCKER_CMD volume inspect "$VOLUME"
    else
        echo -e "${RED}✗ Failed to create volume${NC}"
        exit 1
    fi
}

# Remove volume
remove_volume() {
    if [[ -z "$VOLUME" ]] && [[ "$ALL" != "true" ]]; then
        echo -e "${RED}Error: No volume specified${NC}"
        echo "Use --all to remove all unused volumes"
        exit 1
    fi
    
    local rm_args=""
    
    if [[ "$FORCE" == "true" ]]; then
        rm_args="$rm_args -f"
    fi
    
    if [[ -n "$VOLUME" ]]; then
        # Check if volume is in use
        if [[ "$FORCE" != "true" ]]; then
            local containers
            containers=$($DOCKER_CMD ps -a --filter "volume=$VOLUME" --format "{{.Names}}" 2>/dev/null || true)
            
            if [[ -n "$containers" ]]; then
                echo -e "${YELLOW}Warning: Volume is used by containers:${NC}"
                echo "$containers"
                read -p "Remove anyway? (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    echo -e "${RED}Operation cancelled${NC}"
                    exit 1
                fi
                rm_args="$rm_args -f"
            fi
        fi
        
        echo -e "${CYAN}Removing volume: $VOLUME${NC}"
        
        if $DOCKER_CMD volume rm $rm_args "$VOLUME"; then
            echo -e "${GREEN}✓ Volume removed successfully${NC}"
        else
            echo -e "${RED}✗ Failed to remove volume${NC}"
            exit 1
        fi
    elif [[ "$ALL" == "true" ]]; then
        echo -e "${CYAN}Removing all unused volumes...${NC}"
        
        if [[ "$FORCE" != "true" ]]; then
            # Show volumes to be removed
            local unused_volumes
            unused_volumes=$($DOCKER_CMD volume ls -f dangling=true -q)
            
            if [[ -z "$unused_volumes" ]]; then
                echo -e "${YELLOW}No unused volumes to remove${NC}"
                exit 0
            fi
            
            echo -e "${YELLOW}The following volumes will be removed:${NC}"
            echo "$unused_volumes"
            
            read -p "Continue? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo -e "${RED}Operation cancelled${NC}"
                exit 1
            fi
        fi
        
        $DOCKER_CMD volume prune -f
        echo -e "${GREEN}✓ Unused volumes removed${NC}"
    fi
}

# Inspect volume
inspect_volume() {
    if [[ -z "$VOLUME" ]]; then
        echo -e "${RED}Error: No volume specified${NC}"
        exit 1
    fi
    
    echo -e "${CYAN}Inspecting volume: $VOLUME${NC}"
    
    $DOCKER_CMD volume inspect "$VOLUME" | jq '.' 2>/dev/null || $DOCKER_CMD volume inspect "$VOLUME"
}

# List volumes
list_volumes() {
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
    
    echo -e "${CYAN}Listing volumes...${NC}"
    
    if [[ "$QUIET" == "true" ]]; then
        $DOCKER_CMD volume ls $list_args
    else
        # Show enhanced volume list with usage info
        echo -e "${CYAN}DRIVER    VOLUME NAME                             SIZE       CONTAINERS${NC}"
        echo -e "${CYAN}────────────────────────────────────────────────────────────────────────${NC}"
        
        while IFS= read -r volume; do
            if [[ -n "$volume" ]]; then
                local driver
                driver=$($DOCKER_CMD volume inspect "$volume" --format '{{.Driver}}' 2>/dev/null || echo "unknown")
                
                local containers
                containers=$($DOCKER_CMD ps -a --filter "volume=$volume" --format "{{.Names}}" 2>/dev/null | wc -l || echo "0")
                
                # Try to get size (only works for some drivers)
                local size="N/A"
                local mountpoint
                mountpoint=$($DOCKER_CMD volume inspect "$volume" --format '{{.Mountpoint}}' 2>/dev/null || true)
                
                if [[ -n "$mountpoint" ]] && [[ -d "$mountpoint" ]]; then
                    size=$(du -sh "$mountpoint" 2>/dev/null | cut -f1 || echo "N/A")
                fi
                
                printf "%-9s %-40s %-10s %s\n" "$driver" "$volume" "$size" "$containers"
            fi
        done < <($DOCKER_CMD volume ls -q $list_args)
    fi
}

# Prune volumes
prune_volumes() {
    echo -e "${CYAN}Pruning unused volumes...${NC}"
    
    local prune_args=""
    
    if [[ "$FORCE" == "true" ]]; then
        prune_args="$prune_args -f"
    fi
    
    if [[ "$ALL" == "true" ]]; then
        prune_args="$prune_args -a"
    fi
    
    if [[ "$FORCE" != "true" ]]; then
        # Show what will be removed
        local unused_volumes
        unused_volumes=$($DOCKER_CMD volume ls -f dangling=true -q)
        
        if [[ -z "$unused_volumes" ]]; then
            echo -e "${YELLOW}No unused volumes to prune${NC}"
            exit 0
        fi
        
        echo -e "${YELLOW}The following volumes will be removed:${NC}"
        echo "$unused_volumes"
        
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${RED}Operation cancelled${NC}"
            exit 1
        fi
        
        prune_args="$prune_args -f"
    fi
    
    local result
    result=$($DOCKER_CMD volume prune $prune_args)
    
    echo "$result"
    echo -e "${GREEN}✓ Volume pruning complete${NC}"
}

# Backup volume
backup_volume() {
    if [[ -z "$VOLUME" ]]; then
        echo -e "${RED}Error: No volume specified${NC}"
        exit 1
    fi
    
    local output="${OUTPUT:-${VOLUME}-backup-$(date +%Y%m%d-%H%M%S).tar}"
    
    echo -e "${CYAN}Backing up volume $VOLUME to $output${NC}"
    
    # Create temporary container to access volume
    local temp_container="dockerkit-backup-$$"
    
    # Run backup using alpine container
    $DOCKER_CMD run --rm \
        --name "$temp_container" \
        -v "$VOLUME":/volume:ro \
        -v "$(pwd)":/backup \
        alpine \
        tar -cf "/backup/$output" -C /volume .
    
    if [[ $? -eq 0 ]]; then
        # Compress if requested
        if [[ "$COMPRESS" == "true" ]]; then
            echo -e "${CYAN}Compressing backup...${NC}"
            gzip "$output"
            output="${output}.gz"
        fi
        
        local size
        size=$(du -h "$output" | cut -f1)
        echo -e "${GREEN}✓ Volume backed up successfully (${size})${NC}"
        echo -e "${GREEN}Backup saved to: $output${NC}"
    else
        echo -e "${RED}✗ Failed to backup volume${NC}"
        exit 1
    fi
}

# Restore volume
restore_volume() {
    if [[ -z "$VOLUME" ]]; then
        echo -e "${RED}Error: No volume specified${NC}"
        exit 1
    fi
    
    if [[ -z "$INPUT" ]]; then
        echo -e "${RED}Error: No input file specified${NC}"
        echo "Use -i or --input to specify the backup file"
        exit 1
    fi
    
    if [[ ! -f "$INPUT" ]]; then
        echo -e "${RED}Error: Backup file not found: $INPUT${NC}"
        exit 1
    fi
    
    echo -e "${CYAN}Restoring volume $VOLUME from $INPUT${NC}"
    
    # Check if volume exists
    if ! $DOCKER_CMD volume inspect "$VOLUME" &>/dev/null; then
        echo -e "${YELLOW}Volume doesn't exist, creating it...${NC}"
        $DOCKER_CMD volume create "$VOLUME"
    else
        echo -e "${YELLOW}Warning: This will overwrite existing volume data${NC}"
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${RED}Operation cancelled${NC}"
            exit 1
        fi
    fi
    
    # Decompress if needed
    local backup_file="$INPUT"
    if [[ "$INPUT" =~ \.gz$ ]]; then
        echo -e "${CYAN}Decompressing backup...${NC}"
        backup_file="${INPUT%.gz}"
        gunzip -c "$INPUT" > "$backup_file"
    fi
    
    # Create temporary container to restore volume
    local temp_container="dockerkit-restore-$$"
    
    # Run restore using alpine container
    $DOCKER_CMD run --rm \
        --name "$temp_container" \
        -v "$VOLUME":/volume \
        -v "$(pwd)":/backup:ro \
        alpine \
        sh -c "rm -rf /volume/* /volume/..?* /volume/.[!.]* 2>/dev/null; tar -xf /backup/$(basename "$backup_file") -C /volume"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Volume restored successfully${NC}"
        
        # Clean up temporary file if we decompressed
        if [[ "$backup_file" != "$INPUT" ]]; then
            rm "$backup_file"
        fi
    else
        echo -e "${RED}✗ Failed to restore volume${NC}"
        exit 1
    fi
}

# Clone volume
clone_volume() {
    local source="$1"
    local target="$2"
    
    if [[ -z "$source" ]] || [[ -z "$target" ]]; then
        echo -e "${RED}Error: Source and target volumes required${NC}"
        echo "Usage: $(basename "$0") clone <source> <target>"
        exit 1
    fi
    
    # Check if source exists
    if ! $DOCKER_CMD volume inspect "$source" &>/dev/null; then
        echo -e "${RED}Error: Source volume '$source' not found${NC}"
        exit 1
    fi
    
    # Check if target exists
    if $DOCKER_CMD volume inspect "$target" &>/dev/null 2>&1; then
        echo -e "${YELLOW}Warning: Target volume '$target' already exists${NC}"
        read -p "Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${RED}Operation cancelled${NC}"
            exit 1
        fi
    else
        echo -e "${CYAN}Creating target volume: $target${NC}"
        $DOCKER_CMD volume create "$target"
    fi
    
    echo -e "${CYAN}Cloning volume $source to $target${NC}"
    
    # Use temporary container to clone
    $DOCKER_CMD run --rm \
        -v "$source":/source:ro \
        -v "$target":/target \
        alpine \
        sh -c "rm -rf /target/* /target/..?* /target/.[!.]* 2>/dev/null; cp -av /source/. /target/"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Volume cloned successfully${NC}"
    else
        echo -e "${RED}✗ Failed to clone volume${NC}"
        exit 1
    fi
}

# Show volume sizes
show_volume_sizes() {
    echo -e "${CYAN}Calculating volume sizes...${NC}"
    echo -e "${CYAN}VOLUME NAME                             SIZE       MOUNTPOINT${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────────────────────${NC}"
    
    while IFS= read -r volume; do
        if [[ -n "$volume" ]]; then
            local mountpoint
            mountpoint=$($DOCKER_CMD volume inspect "$volume" --format '{{.Mountpoint}}' 2>/dev/null || echo "N/A")
            
            local size="N/A"
            if [[ "$mountpoint" != "N/A" ]] && [[ -d "$mountpoint" ]]; then
                size=$(du -sh "$mountpoint" 2>/dev/null | cut -f1 || echo "N/A")
            fi
            
            printf "%-40s %-10s %s\n" "$volume" "$size" "$mountpoint"
        fi
    done < <($DOCKER_CMD volume ls -q)
    
    echo -e "${CYAN}────────────────────────────────────────────────────────────────────────${NC}"
    
    # Total size
    local total_size
    total_size=$(du -sh /var/lib/docker/volumes 2>/dev/null | cut -f1 || echo "N/A")
    echo -e "${CYAN}Total volume storage: $total_size${NC}"
}

# Parse arguments
QUIET=false
FORMAT=""
OUTPUT=""
INPUT=""
COMPRESS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        create|remove|rm|inspect|list|ls|prune|backup|restore|clone|size)
            ACTION="$1"
            if [[ "$ACTION" == "rm" ]]; then
                ACTION="remove"
            elif [[ "$ACTION" == "ls" ]]; then
                ACTION="list"
            fi
            shift
            if [[ "$ACTION" == "clone" ]]; then
                SOURCE="$1"
                TARGET="$2"
                shift 2
            elif [[ $# -gt 0 ]] && [[ ! "$1" =~ ^- ]]; then
                VOLUME="$1"
                shift
            fi
            ;;
        -d|--driver)
            DRIVER="$2"
            shift 2
            ;;
        -o|--opt)
            OPTIONS+=("$2")
            shift 2
            ;;
        -l|--label)
            LABELS+=("$2")
            shift 2
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -a|--all)
            ALL=true
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
        --output)
            OUTPUT="$2"
            shift 2
            ;;
        -i|--input)
            INPUT="$2"
            shift 2
            ;;
        -c|--compress)
            COMPRESS=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            if [[ -z "$VOLUME" ]]; then
                VOLUME="$1"
            fi
            shift
            ;;
    esac
done

# Execute action
case "$ACTION" in
    create)
        create_volume
        ;;
    remove)
        remove_volume
        ;;
    inspect)
        inspect_volume
        ;;
    list)
        list_volumes
        ;;
    prune)
        prune_volumes
        ;;
    backup)
        backup_volume
        ;;
    restore)
        restore_volume
        ;;
    clone)
        clone_volume "$SOURCE" "$TARGET"
        ;;
    size)
        show_volume_sizes
        ;;
    *)
        echo -e "${RED}Error: No action specified${NC}"
        show_help
        exit 1
        ;;
esac