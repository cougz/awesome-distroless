#!/bin/bash
# Build.sh - Entry point that delegates to appropriate managers
# Provides backward compatibility while routing to the new 3-tier architecture
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
    echo "Build Entry Point - Delegates to Appropriate Managers"
    echo ""
    echo "Usage: $0 [VERSION] [TOOLS|APP]"
    echo ""
    echo "Arguments:"
    echo "  VERSION     Image version (default: 0.2.0)"
    echo "  TOOLS|APP   Tool name, comma-separated tools, or app name"
    echo ""
    echo "Examples:"
    echo "  $0 0.2.0                        # Build base image (→ base-manager.sh)"
    echo "  $0 0.2.0 curl                   # Build curl tool (→ tool-manager.sh)"
    echo "  $0 0.2.0 \"curl,jq\"              # Build multi-tool (→ tool-manager.sh)"
    echo "  $0 0.2.0 pocket-id               # Build app stack (→ app-manager.sh)"
    echo ""
    echo "Direct manager access:"
    echo "  ./scripts/base-manager.sh        # Base image management"
    echo "  ./scripts/tool-manager.sh        # Tool image management"
    echo "  ./scripts/app-manager.sh         # Application stack management"
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

# Determine which manager to use based on input
if [ -z "${TOOLS}" ]; then
    # No tools specified - build base image via base-manager
    echo -e "${BLUE}Delegating to base-manager.sh...${NC}"
    exec "${SCRIPT_DIR}/base-manager.sh" build "${VERSION}"
elif [[ "${TOOLS}" == *","* ]]; then
    # Multi-tool build - use tool-manager
    echo -e "${BLUE}Delegating to tool-manager.sh (multi-tool)...${NC}"
    exec "${SCRIPT_DIR}/tool-manager.sh" build "${TOOLS}"
elif "${SCRIPT_DIR}/tool-manager.sh" names 2>/dev/null | grep -q "^${TOOLS}$"; then
    # Single tool - use tool-manager
    echo -e "${BLUE}Delegating to tool-manager.sh (single tool)...${NC}"
    exec "${SCRIPT_DIR}/tool-manager.sh" build "${TOOLS}"
elif [ -f "${PROJECT_DIR}/apps/${TOOLS}.yml" ]; then
    # Application stack - use app-manager
    echo -e "${BLUE}Delegating to app-manager.sh (application)...${NC}"
    exec "${SCRIPT_DIR}/app-manager.sh" build "${TOOLS}"
else
    echo -e "${RED}Error: Unknown target '${TOOLS}'${NC}" >&2
    echo -e "${YELLOW}Not found as:${NC}" >&2
    echo -e "  - Tool (check: ./scripts/tool-manager.sh list)" >&2
    echo -e "  - App (check: ./scripts/app-manager.sh list)" >&2
    exit 1
fi

# The rest is legacy code that won't be reached due to exec above
if false; then
    # Legacy base image build code
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
fi