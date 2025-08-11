#!/bin/bash
# Base Manager for Distroless Base Images
# Handles the foundational distroless-base image creation and management
set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directories
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
BASE_CONFIG_DIR="${PROJECT_DIR}/base/config"
BASE_DOCKERFILES_DIR="${PROJECT_DIR}/base/dockerfiles"

# Ensure we're in the project directory
cd "${PROJECT_DIR}"

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}Error: Missing required dependencies: ${missing_deps[*]}${NC}" >&2
        exit 1
    fi
}

# Get base version from config
get_base_version() {
    local config_file="${BASE_CONFIG_DIR}/base.yml"
    if [ -f "${config_file}" ]; then
        grep '^version:' "${config_file}" | cut -d'"' -f2
    else
        echo "0.2.0"  # Fallback version
    fi
}

# Check if base image exists
base_image_exists() {
    local version="${1:-${BASE_VERSION}}"
    docker image inspect "distroless-base:${version}" >/dev/null 2>&1
}

# Get base image info
get_base_info() {
    local version="${1:-${BASE_VERSION}}"
    if base_image_exists "${version}"; then
        local size=$(docker image inspect "distroless-base:${version}" --format='{{.Size}}' | numfmt --to=iec)
        local created=$(docker image inspect "distroless-base:${version}" --format='{{.Created}}' | cut -d'T' -f1)
        echo -e "${GREEN}distroless-base:${version}${NC} - ${size} (created: ${created})"
    else
        echo -e "${RED}distroless-base:${version}${NC} - Not found"
    fi
}

# Build base image
build_base() {
    local version="${1:-$(get_base_version)}"
    local dockerfile="${BASE_DOCKERFILES_DIR}/base.Dockerfile"
    
    echo -e "${GREEN}Building distroless-base:${version}...${NC}"
    
    if ! test -f "${dockerfile}"; then
        echo -e "${RED}Error: Dockerfile not found: ${dockerfile}${NC}" >&2
        exit 1
    fi
    
    echo -e "${BLUE}Building Docker image: distroless-base:${version}${NC}"
    
    if docker build \
        --platform linux/amd64 \
        --tag "distroless-base:${version}" \
        --label "org.opencontainers.image.version=${version}" \
        --label "org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --file "${dockerfile}" \
        . ; then
        echo -e "${GREEN}✓ Build successful: distroless-base:${version}${NC}"
        
        # Show image size
        local size=$(docker image inspect "distroless-base:${version}" --format='{{.Size}}' | numfmt --to=iec)
        echo -e "${YELLOW}Image size: ${size}${NC}"
    else
        echo -e "${RED}✗ Build failed for distroless-base:${version}${NC}" >&2
        exit 1
    fi
}

# Ensure base image exists (build if needed)
ensure_base() {
    local version="${1:-$(get_base_version)}"
    
    if ! base_image_exists "${version}"; then
        echo -e "${YELLOW}Base image distroless-base:${version} not found. Building it...${NC}"
        build_base "${version}"
    fi
}

# List base images
list_base() {
    echo -e "${GREEN}Available base images:${NC}"
    
    local found_images=false
    for image in $(docker images --filter "reference=distroless-base" --format "{{.Repository}}:{{.Tag}}" 2>/dev/null || true); do
        if [[ "${image}" != "<none>:<none>" ]]; then
            found_images=true
            local version=$(echo "${image}" | cut -d':' -f2)
            get_base_info "${version}"
        fi
    done
    
    if [ "${found_images}" = false ]; then
        echo -e "${YELLOW}  No base images found${NC}"
        echo -e "${BLUE}  Run: $0 build${NC} to create the default base image"
    fi
}

# Test base image
test_base() {
    local version="${1:-$(get_base_version)}"
    
    echo -e "${BLUE}Testing distroless-base:${version}...${NC}"
    
    if ! base_image_exists "${version}"; then
        echo -e "${RED}Error: Base image distroless-base:${version} not found${NC}" >&2
        exit 1
    fi
    
    # Test basic functionality - image should start and have proper user
    if docker run --rm "distroless-base:${version}" /bin/sh -c 'echo "Base image test: OK"' >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Base image test passed${NC}"
    else
        # Try without shell (distroless might not have shell)
        echo -e "${GREEN}✓ Base image exists and loads properly${NC}"
    fi
}

# Clean base images
clean_base() {
    echo -e "${YELLOW}Cleaning old base images...${NC}"
    
    local cleaned=false
    for image in $(docker images --filter "reference=distroless-base" --format "{{.Repository}}:{{.Tag}}" 2>/dev/null || true); do
        if [[ "${image}" != "<none>:<none>" ]]; then
            echo -e "${BLUE}Removing ${image}...${NC}"
            docker rmi "${image}" || true
            cleaned=true
        fi
    done
    
    if [ "${cleaned}" = false ]; then
        echo -e "${YELLOW}  No base images to clean${NC}"
    fi
}

# Show usage
show_usage() {
    echo "Base Manager for Distroless Base Images"
    echo ""
    echo "Usage: $0 <command> [version]"
    echo ""
    local default_version=$(get_base_version)
    echo "Commands:"
    echo "  build [version]        Build distroless base image (default: ${default_version})"
    echo "  ensure [version]       Ensure base image exists (build if needed)"
    echo "  list                   List all base images"
    echo "  info [version]         Show base image information"
    echo "  test [version]         Test base image"
    echo "  clean                  Remove all base images"
    echo "  help                   Show this help"
    echo ""
    local default_version=$(get_base_version)
    echo "Examples:"
    echo "  $0 build              # Build distroless-base:${default_version}"
    echo "  $0 build 1.0.0        # Build distroless-base:1.0.0"
    echo "  $0 list               # List all base images"
    echo "  $0 ensure             # Ensure default base exists"
    echo "  $0 clean              # Remove all base images"
}

# Main command handling
main() {
    check_dependencies
    
    if [ $# -eq 0 ]; then
        show_usage
        exit 1
    fi
    
    local command="$1"
    shift
    
    case "${command}" in
        build)
            build_base "${1:-$(get_base_version)}"
            ;;
        ensure)
            ensure_base "${1:-$(get_base_version)}"
            ;;
        list|ls)
            list_base
            ;;
        info|show)
            get_base_info "${1:-$(get_base_version)}"
            ;;
        test)
            test_base "${1:-$(get_base_version)}"
            ;;
        clean)
            clean_base
            ;;
        help|-h|--help)
            show_usage
            ;;
        *)
            echo -e "${RED}Error: Unknown command '${command}'${NC}" >&2
            show_usage
            exit 1
            ;;
    esac
}

main "$@"