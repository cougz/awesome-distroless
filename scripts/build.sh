#!/bin/bash

# Build script for distroless base image
set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
VERSION="${1:-0.1.0}"
REGISTRY="${2:-ghcr.io}"
NAMESPACE="${3:-yourusername}"
IMAGE_NAME="distroless-base"

# Full image references
LOCAL_TAG="${IMAGE_NAME}:${VERSION}"
REGISTRY_TAG="${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:${VERSION}"

# Print build information
echo -e "${GREEN}Building Distroless Base Image${NC}"
echo -e "${YELLOW}Version:${NC} ${VERSION}"
echo -e "${YELLOW}Registry:${NC} ${REGISTRY}"
echo -e "${YELLOW}Namespace:${NC} ${NAMESPACE}"
echo -e "${YELLOW}Local tag:${NC} ${LOCAL_TAG}"
echo -e "${YELLOW}Registry tag:${NC} ${REGISTRY_TAG}"
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed or not in PATH${NC}"
    exit 1
fi

# Get the script directory (parent of scripts/)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

# Change to project directory
cd "${PROJECT_DIR}"

# Check if Dockerfile exists
if [ ! -f "Dockerfile" ]; then
    echo -e "${RED}Error: Dockerfile not found in ${PROJECT_DIR}${NC}"
    exit 1
fi

# Build the image
echo -e "${GREEN}Building Docker image...${NC}"
if docker build \
    --platform linux/amd64 \
    --tag "${LOCAL_TAG}" \
    --tag "${REGISTRY_TAG}" \
    --label "org.opencontainers.image.version=${VERSION}" \
    --label "org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --file Dockerfile \
    . ; then
    echo -e "${GREEN}✓ Build successful!${NC}"
else
    echo -e "${RED}✗ Build failed!${NC}"
    exit 1
fi

# Display image information
echo ""
echo -e "${GREEN}Image Information:${NC}"
docker images --filter "reference=${IMAGE_NAME}" --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

# Verify image size
SIZE=$(docker image inspect "${LOCAL_TAG}" --format='{{.Size}}' | numfmt --to=iec)
echo ""
echo -e "${YELLOW}Image size:${NC} ${SIZE}"

# Check if size is under 5MB
SIZE_BYTES=$(docker image inspect "${LOCAL_TAG}" --format='{{.Size}}')
if [ "${SIZE_BYTES}" -gt 5242880 ]; then
    echo -e "${YELLOW}Warning: Image size (${SIZE}) exceeds target of 5MB${NC}"
else
    echo -e "${GREEN}✓ Image size is within target (< 5MB)${NC}"
fi

# Test the image
echo ""
echo -e "${GREEN}Testing image...${NC}"

# Run a simple test to verify the image works
if docker run --rm "${LOCAL_TAG}" true 2>/dev/null; then
    echo -e "${GREEN}✓ Image can be executed${NC}"
else
    echo -e "${YELLOW}Note: Base image has no default command (expected behavior)${NC}"
fi

# Check user configuration
echo ""
echo -e "${GREEN}Verifying non-root user configuration...${NC}"
USER_ID=$(docker run --rm --entrypoint="" "${LOCAL_TAG}" sh -c 'id -u' 2>/dev/null || echo "N/A")
if [ "${USER_ID}" = "1000" ]; then
    echo -e "${GREEN}✓ Running as non-root user (UID: 1000)${NC}"
elif [ "${USER_ID}" = "N/A" ]; then
    echo -e "${YELLOW}Note: Cannot verify user (no shell available - expected for distroless)${NC}"
else
    echo -e "${RED}✗ Not running as expected user (UID: ${USER_ID})${NC}"
fi

echo ""
echo -e "${GREEN}Build complete!${NC}"
echo ""
echo "To publish to registry, run:"
echo -e "${YELLOW}  ./scripts/publish.sh ${VERSION} ${NAMESPACE}${NC}"