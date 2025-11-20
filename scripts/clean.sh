#!/usr/bin/env bash

# =============================================================================
# Cleanup Script
# =============================================================================

set -euo pipefail

readonly SCRIPT_DIR
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

CLEAN_DOCKER=false
CLEAN_ALL=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --docker)
            CLEAN_DOCKER=true
            shift
            ;;
        --all)
            CLEAN_ALL=true
            CLEAN_DOCKER=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--docker] [--all]"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}Cleaning build artifacts...${NC}"

cd "${PROJECT_DIR}"

# Remove build artifacts
echo "Removing build artifacts..."
rm -f output.iso boot.img bzImage initramfs initramfs.cpio.gz
rm -rf mnt/ myiso/ initramfs/ build/ output/
echo -e "${GREEN}✓ Build artifacts removed${NC}"

# Clean Docker
if [[ "${CLEAN_DOCKER}" == "true" ]]; then
    echo -e "${BLUE}Cleaning Docker images...${NC}"
    docker rmi handbuilt-linux:latest 2>/dev/null || echo -e "${YELLOW}Image not found${NC}"
    docker rmi handbuilt-linux:kernel 2>/dev/null || true
    docker rmi handbuilt-linux:busybox 2>/dev/null || true
    docker rmi handbuilt-linux:iso 2>/dev/null || true
    echo -e "${GREEN}✓ Docker images removed${NC}"
fi

# Full cleanup
if [[ "${CLEAN_ALL}" == "true" ]]; then
    echo -e "${BLUE}Performing full cleanup...${NC}"
    docker system prune -f 2>/dev/null || true
    echo -e "${GREEN}✓ Full cleanup complete${NC}"
fi

echo -e "${GREEN}Cleanup complete!${NC}"
