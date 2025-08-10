#!/bin/bash
# New build.sh - delegates to tool manager for backward compatibility
set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
VERSION="${1:-0.2.0}"
TOOLS="${2:-}"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

cd "${PROJECT_DIR}"

show_usage() {
    echo "Usage: $0 [VERSION] [TOOLS]"
    echo ""
    echo "Arguments:"
    echo "  VERSION     Image version (default: 0.2.0)"
    echo "  TOOLS       Comma-separated tools to add (optional)"
    echo ""
    echo "Examples:"
    echo "  $0 0.2.0                        # Build base image only"
    echo "  $0 0.2.0 curl                   # Build curl image"
    echo "  $0 0.2.0 \"curl,jq\"              # Build curl + jq image"
    echo ""
    echo "Available tools:"
    "${SCRIPT_DIR}/tool-manager.sh" list | grep -v "Available tools:" || echo "    Run './scripts/tool-manager.sh list' for details"
    exit 1
}

# Handle help flag
if [[ "${1:-}" =~ ^(-h|--help)$ ]]; then
    show_usage
fi

echo -e "${GREEN}Building Distroless Image${NC}"
echo -e "${YELLOW}Version:${NC} ${VERSION}"
echo -e "${YELLOW}Tools:${NC} ${TOOLS:-"none (base image only)"}"
echo ""

if [ -z "${TOOLS}" ]; then
    # Build base image as before
    echo -e "${BLUE}Building base image...${NC}"
    
    if docker build \
        --platform linux/amd64 \
        --tag "distroless-base:${VERSION}" \
        --label "org.opencontainers.image.version=${VERSION}" \
        --label "org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --file Dockerfile \
        . ; then
        echo -e "${GREEN}✓ Base image build successful!${NC}"
        
        # Display image information
        echo ""
        echo -e "${GREEN}Image Information:${NC}"
        docker images --filter "reference=distroless-base" --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
        
        SIZE=$(docker image inspect "distroless-base:${VERSION}" --format='{{.Size}}' | numfmt --to=iec)
        echo ""
        echo -e "${YELLOW}Image size:${NC} ${SIZE}"
        
        echo ""
        echo -e "${GREEN}Build complete!${NC}"
    else
        echo -e "${RED}✗ Base image build failed!${NC}"
        exit 1
    fi
else
    # Use tool manager for tools
    IFS=',' read -ra TOOL_ARRAY <<< "${TOOLS}"
    
    if [ ${#TOOL_ARRAY[@]} -eq 1 ]; then
        # Single tool - use new tool manager
        echo -e "${BLUE}Using new tool manager for ${TOOL_ARRAY[0]}...${NC}"
        "${SCRIPT_DIR}/tool-manager.sh" build "${TOOL_ARRAY[0]}" "${VERSION}"
        "${SCRIPT_DIR}/tool-manager.sh" test "${TOOL_ARRAY[0]}" "${VERSION}"
        
        echo ""
        echo -e "${GREEN}Build complete!${NC}"
        echo ""
        echo "Image includes tool: ${TOOLS}"
        echo ""
        echo "To use this image:"
        echo -e "${YELLOW}  docker run --rm distroless-${TOOL_ARRAY[0]}:${VERSION} ${TOOL_ARRAY[0]} --version${NC}"
    else
        # Multiple tools - fallback to old system for now
        echo -e "${YELLOW}Multiple tools detected: ${TOOLS}${NC}"
        echo -e "${YELLOW}Using legacy multi-tool build system...${NC}"
        
        # Use the backup build script for multi-tool builds
        if [ -f "${SCRIPT_DIR}/build.sh.backup" ]; then
            exec "${SCRIPT_DIR}/build.sh.backup" "${VERSION}" "${TOOLS}"
        else
            echo -e "${RED}Error: Legacy build system not available${NC}"
            echo -e "${YELLOW}Please build tools individually:${NC}"
            for tool in "${TOOL_ARRAY[@]}"; do
                echo -e "${YELLOW}  $0 ${VERSION} ${tool}${NC}"
            done
            exit 1
        fi
    fi
fi

if [ -n "${TOOLS}" ]; then
    echo ""
    echo "To publish to registry, run:"
    echo -e "${YELLOW}  ./scripts/publish.sh distroless-${TOOLS}:${VERSION}${NC}"
fi