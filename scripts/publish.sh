#!/bin/bash

# Publish script for distroless base image to GitHub Container Registry
set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
VERSION="${1:-0.1.0}"
NAMESPACE="${2:-yourusername}"
REGISTRY="ghcr.io"
IMAGE_NAME="distroless-base"

# Full image references
LOCAL_TAG="${IMAGE_NAME}:${VERSION}"
REGISTRY_TAG="${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:${VERSION}"

# Print publish information
echo -e "${GREEN}Publishing Distroless Base Image to GitHub Container Registry${NC}"
echo -e "${YELLOW}Version:${NC} ${VERSION}"
echo -e "${YELLOW}Registry:${NC} ${REGISTRY}"
echo -e "${YELLOW}Namespace:${NC} ${NAMESPACE}"
echo -e "${YELLOW}Tag to push:${NC} ${VERSION}"
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed or not in PATH${NC}"
    exit 1
fi

# Function to check if image exists locally
check_local_image() {
    if docker image inspect "${1}" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Check if images exist locally
echo -e "${BLUE}Checking for local images...${NC}"
if ! check_local_image "${LOCAL_TAG}"; then
    echo -e "${YELLOW}Warning: Local image ${LOCAL_TAG} not found${NC}"
    echo -e "${YELLOW}Building image first...${NC}"
    
    # Get the script directory
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    
    # Run build script
    if [ -f "${SCRIPT_DIR}/build.sh" ]; then
        "${SCRIPT_DIR}/build.sh" "${VERSION}" "${REGISTRY}" "${NAMESPACE}"
    else
        echo -e "${RED}Error: build.sh not found${NC}"
        exit 1
    fi
fi

# Check GitHub token
echo ""
echo -e "${BLUE}Checking authentication...${NC}"

# Check for GitHub token in environment
if [ -z "${GITHUB_TOKEN:-}" ] && [ -z "${CR_PAT:-}" ]; then
    echo -e "${RED}Error: No GitHub token found${NC}"
    echo ""
    echo "Please set one of the following environment variables:"
    echo "  export GITHUB_TOKEN=your_personal_access_token"
    echo "  export CR_PAT=your_personal_access_token"
    echo ""
    echo "To create a token:"
    echo "  1. Go to https://github.com/settings/tokens"
    echo "  2. Generate new token (classic)"
    echo "  3. Select scopes: write:packages, delete:packages"
    exit 1
fi

# Use CR_PAT if GITHUB_TOKEN is not set
TOKEN="${GITHUB_TOKEN:-${CR_PAT}}"

# Login to GitHub Container Registry
echo -e "${BLUE}Logging in to ${REGISTRY}...${NC}"
echo "${TOKEN}" | docker login "${REGISTRY}" -u "${NAMESPACE}" --password-stdin

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to login to ${REGISTRY}${NC}"
    echo "Please check your token and username"
    exit 1
fi

echo -e "${GREEN}✓ Successfully authenticated to ${REGISTRY}${NC}"

# Tag images for registry if not already tagged
echo ""
echo -e "${BLUE}Preparing images for push...${NC}"

if ! check_local_image "${REGISTRY_TAG}"; then
    echo "Tagging ${LOCAL_TAG} as ${REGISTRY_TAG}"
    docker tag "${LOCAL_TAG}" "${REGISTRY_TAG}"
fi

# Push images
echo ""
echo -e "${BLUE}Pushing images to ${REGISTRY}...${NC}"

# Push versioned tag
echo -e "${YELLOW}Pushing ${REGISTRY_TAG}...${NC}"
if docker push "${REGISTRY_TAG}"; then
    echo -e "${GREEN}✓ Successfully pushed ${REGISTRY_TAG}${NC}"
else
    echo -e "${RED}✗ Failed to push ${REGISTRY_TAG}${NC}"
    exit 1
fi

# Display summary
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Successfully published to GitHub Container Registry!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "Image is now available at:"
echo -e "${BLUE}  ${REGISTRY_TAG}${NC}"
echo ""
echo "To use this image in a Dockerfile:"
echo -e "${YELLOW}  FROM ${REGISTRY_TAG}${NC}"
echo ""
echo "To pull this image:"
echo -e "${YELLOW}  docker pull ${REGISTRY_TAG}${NC}"
echo ""
echo "Package visibility:"
echo -e "${YELLOW}  https://github.com/${NAMESPACE}?tab=packages${NC}"

# Logout from registry
docker logout "${REGISTRY}" >/dev/null 2>&1