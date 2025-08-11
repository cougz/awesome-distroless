#!/bin/bash
# Simplified Tool Manager for Docker Distroless Base Images
# Focuses on core responsibilities: list, build, test, show
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
CONFIG_DIR="${PROJECT_DIR}/tools/config"
DOCKERFILE_DIR="${PROJECT_DIR}/tools/dockerfiles"

# Ensure we're in the project directory
cd "${PROJECT_DIR}"

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v yq &> /dev/null; then
        missing_deps+=("yq")
    fi
    
    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}Error: Missing required dependencies: ${missing_deps[*]}${NC}" >&2
        echo -e "${YELLOW}Please install missing dependencies before continuing${NC}" >&2
        exit 1
    fi
}

# Check if tool exists (requires both YAML config AND Dockerfile)
tool_exists() {
    local tool_name="$1"
    local config_file="${CONFIG_DIR}/${tool_name}.yml"
    local dockerfile="${DOCKERFILE_DIR}/${tool_name}.Dockerfile"
    
    [[ -f "${config_file}" && -f "${dockerfile}" ]]
}

# Get tool status (✅ if both YAML + Dockerfile exist, ❌ otherwise)
get_tool_status() {
    local tool_name="$1"
    if tool_exists "${tool_name}"; then
        echo "✅"
    else
        echo "❌"
    fi
}

# List available tools
list_tools() {
    echo -e "${GREEN}Available tools:${NC}"
    
    if [ ! -d "${CONFIG_DIR}" ] || [ -z "$(ls -A "${CONFIG_DIR}" 2>/dev/null || true)" ]; then
        echo -e "${YELLOW}  No tools configured${NC}"
        return
    fi
    
    for config_file in "${CONFIG_DIR}"/*.yml; do
        if [ -f "${config_file}" ]; then
            local tool_name=$(yq eval '.name' "${config_file}")
            local tool_version=$(yq eval '.version' "${config_file}")
            local tool_description=$(yq eval '.description' "${config_file}")
            local tool_category=$(yq eval '.category' "${config_file}")
            local status=$(get_tool_status "${tool_name}")
            
            echo -e "${BLUE}  ${tool_name}${NC} (v${tool_version}) - ${tool_description} [${tool_category}] ${status}"
        fi
    done
    
    echo ""
    echo -e "${YELLOW}Legend: ✅ = Ready (YAML + Dockerfile), ❌ = Missing Dockerfile${NC}"
}

# Validate tool exists
validate_tool() {
    local tool_name="$1"
    
    if ! tool_exists "${tool_name}"; then
        if [ ! -f "${CONFIG_DIR}/${tool_name}.yml" ]; then
            echo -e "${RED}Error: Tool '${tool_name}' has no YAML configuration${NC}" >&2
        fi
        if [ ! -f "${DOCKERFILE_DIR}/${tool_name}.Dockerfile" ]; then
            echo -e "${RED}Error: Tool '${tool_name}' has no Dockerfile${NC}" >&2
        fi
        echo -e "${YELLOW}Available tools:${NC}" >&2
        list_tools >&2
        exit 1
    fi
}

# Check if tools list contains comma (multi-tool build)
is_multi_tool() {
    [[ "$1" == *","* ]]
}

# Ensure distroless base image exists
ensure_base_image() {
    if ! docker image inspect distroless-base:0.2.0 >/dev/null 2>&1; then
        echo -e "${YELLOW}Base image distroless-base:0.2.0 not found${NC}" >&2
        echo -e "${RED}Please build base image first: ./scripts/base-manager.sh build${NC}" >&2
        exit 1
    fi
}

# Build single tool image
build_single_tool() {
    local tool_name="$1"
    
    validate_tool "${tool_name}"
    
    local config_file="${CONFIG_DIR}/${tool_name}.yml"
    local dockerfile="${DOCKERFILE_DIR}/${tool_name}.Dockerfile"
    local tool_version=$(yq eval '.version' "${config_file}")
    
    echo -e "${GREEN}Building ${tool_name} v${tool_version}...${NC}"
    
    # Ensure base image exists
    ensure_base_image
    
    # Build image using existing Dockerfile
    local image_name="distroless-${tool_name}"
    local image_tag="${image_name}:${tool_version}"
    
    echo -e "${BLUE}Building Docker image: ${image_tag}${NC}"
    
    if docker build \
        --platform linux/amd64 \
        --tag "${image_tag}" \
        --label "org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --file "${dockerfile}" \
        . ; then
        echo -e "${GREEN}✓ Build successful: ${image_tag}${NC}"
    else
        echo -e "${RED}✗ Build failed for ${tool_name}${NC}" >&2
        exit 1
    fi
    
    # Show image size
    local size=$(docker image inspect "${image_tag}" --format='{{.Size}}' | numfmt --to=iec)
    echo -e "${YELLOW}Image size: ${size}${NC}"
}

# Build multi-tool image
build_multi_tool() {
    local tools_list="$1"
    
    # Split tools into array and validate each
    IFS=',' read -ra TOOLS <<< "${tools_list}"
    for tool in "${TOOLS[@]}"; do
        validate_tool "${tool}"
    done
    
    echo -e "${GREEN}Building multi-tool image with: ${tools_list}...${NC}"
    
    # Check if we should auto-generate the Dockerfile
    local dockerfile="${PROJECT_DIR}/Dockerfile.multi-tools"
    if [[ "${tools_list}" == "git,go,node" ]] || [[ "${tools_list}" == "node,go,git" ]] || [[ "${tools_list}" == "go,git,node" ]]; then
        echo -e "${BLUE}Auto-generating Dockerfile for git,go,node combination...${NC}"
        if [ -f "${PROJECT_DIR}/scripts/dockerfile-generator.sh" ]; then
            "${PROJECT_DIR}/scripts/dockerfile-generator.sh" multi-tools
            dockerfile="${PROJECT_DIR}/Dockerfile.multi-tools.generated"
        fi
    fi
    
    if [ ! -f "${dockerfile}" ]; then
        echo -e "${RED}Error: Multi-tool Dockerfile not found: ${dockerfile}${NC}" >&2
        echo -e "${YELLOW}Available options:${NC}" >&2
        echo -e "${YELLOW}  - Create Dockerfile.multi-tools manually${NC}" >&2
        echo -e "${YELLOW}  - Use 'git,go,node' combination for auto-generation${NC}" >&2
        exit 1
    fi
    
    # Build image
    local image_name="distroless-tools"
    local image_tag="${image_name}"
    
    echo -e "${BLUE}Building Docker image: ${image_tag}${NC}"
    echo -e "${BLUE}Using Dockerfile: ${dockerfile}${NC}"
    
    if docker build \
        --platform linux/amd64 \
        --tag "${image_tag}" \
        --label "org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --file "${dockerfile}" \
        . ; then
        echo -e "${GREEN}✓ Build successful: ${image_tag}${NC}"
    else
        echo -e "${RED}✗ Build failed for multi-tool image${NC}" >&2
        exit 1
    fi
    
    # Show image size
    local size=$(docker image inspect "${image_tag}" --format='{{.Size}}' | numfmt --to=iec)
    echo -e "${YELLOW}Image size: ${size}${NC}"
}

# Build tool image
build_tool() {
    local tool_input="$1"
    
    # Check if this is a multi-tool build
    if is_multi_tool "${tool_input}"; then
        build_multi_tool "${tool_input}"
    else
        build_single_tool "${tool_input}"
    fi
}

# Test tool
test_tool() {
    local tool_name="$1"
    
    validate_tool "${tool_name}"
    
    local config_file="${CONFIG_DIR}/${tool_name}.yml"
    local tool_version=$(yq eval '.version' "${config_file}")
    local image_tag="distroless-${tool_name}:${tool_version}"
    local test_command=$(yq eval '.build.test_command' "${config_file}")
    
    echo -e "${BLUE}Testing ${tool_name}...${NC}"
    
    if docker run --rm "${image_tag}" ${test_command} >/dev/null 2>&1; then
        echo -e "${GREEN}✓ ${tool_name} test passed${NC}"
    else
        echo -e "${RED}✗ ${tool_name} test failed${NC}" >&2
        exit 1
    fi
}

# Show tool configuration
show_config() {
    local tool_name="$1"
    
    validate_tool "${tool_name}"
    
    local config_file="${CONFIG_DIR}/${tool_name}.yml"
    
    echo -e "${GREEN}Configuration for ${tool_name}:${NC}"
    cat "${config_file}"
}

# Show tool Dockerfile
show_dockerfile() {
    local tool_name="$1"
    
    validate_tool "${tool_name}"
    
    local dockerfile="${DOCKERFILE_DIR}/${tool_name}.Dockerfile"
    
    echo -e "${GREEN}Dockerfile for ${tool_name}:${NC}"
    cat "${dockerfile}"
}

# Show usage
show_usage() {
    echo "Simplified Tool Manager for Docker Distroless Base Images"
    echo ""
    echo "Usage: $0 <command> [arguments]"
    echo ""
    echo "Commands:"
    echo "  list                         List all available tools with status"
    echo "  build <tool>                 Build single tool image"
    echo "  build <tool1,tool2>          Build multi-tool image"
    echo "  test <tool>                  Test tool image"
    echo "  config <tool>                Show tool YAML configuration"
    echo "  dockerfile <tool>            Show tool Dockerfile content"
    echo "  help                         Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 list                      # List available tools with status"
    echo "  $0 build curl                # Build curl image"
    echo "  $0 build git,go,node         # Build multi-tool image with git, go, and node"
    echo "  $0 test curl                 # Test curl image"
    echo "  $0 config git                # Show git YAML configuration"
    echo "  $0 dockerfile postgres       # Show postgres Dockerfile"
    echo ""
    echo "Tool Requirements:"
    echo "  A tool exists only when BOTH files are present:"
    echo "  - tools/config/{tool}.yml    (YAML configuration)"
    echo "  - tools/dockerfiles/{tool}.Dockerfile (build instructions)"
    exit 1
}

# Main command handling
main() {
    check_dependencies
    
    if [ $# -eq 0 ]; then
        show_usage
    fi
    
    local command="$1"
    shift
    
    case "${command}" in
        list|ls)
            list_tools
            ;;
        names)
            # Simple tool names only - for build.sh integration
            if [ -d "${CONFIG_DIR}" ]; then
                for config_file in "${CONFIG_DIR}"/*.yml; do
                    if [ -f "${config_file}" ]; then
                        local tool_name=$(yq eval '.name' "${config_file}")
                        if tool_exists "${tool_name}"; then
                            echo "${tool_name}"
                        fi
                    fi
                done
            fi
            ;;
        build)
            if [ $# -eq 0 ]; then
                echo -e "${RED}Error: Tool name required${NC}" >&2
                show_usage
            fi
            build_tool "$1"
            ;;
        test)
            if [ $# -eq 0 ]; then
                echo -e "${RED}Error: Tool name required${NC}" >&2
                show_usage
            fi
            test_tool "$1"
            ;;
        config|show)
            if [ $# -eq 0 ]; then
                echo -e "${RED}Error: Tool name required${NC}" >&2
                show_usage
            fi
            show_config "$1"
            ;;
        dockerfile|docker)
            if [ $# -eq 0 ]; then
                echo -e "${RED}Error: Tool name required${NC}" >&2
                show_usage
            fi
            show_dockerfile "$1"
            ;;
        help|-h|--help)
            show_usage
            ;;
        *)
            echo -e "${RED}Error: Unknown command '${command}'${NC}" >&2
            show_usage
            ;;
    esac
}

main "$@"