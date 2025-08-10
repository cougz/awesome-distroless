#!/bin/bash
# Modular Tool Manager for Docker Distroless Base Images
# Uses Pure Bash + yq for configuration-driven builds
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
TEMPLATE_DIR="${PROJECT_DIR}/tools/templates"
TEMP_DIR="${PROJECT_DIR}/.tmp"

# Ensure we're in the project directory
cd "${PROJECT_DIR}"

# Create temp directory
mkdir -p "${TEMP_DIR}"

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
        echo -e "${YELLOW}Install yq: wget -qO- https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 | sudo tee /usr/local/bin/yq > /dev/null && sudo chmod +x /usr/local/bin/yq${NC}" >&2
        exit 1
    fi
}

# List available tools
list_tools() {
    echo -e "${GREEN}Available tools:${NC}"
    if [ ! -d "${CONFIG_DIR}" ] || [ -z "$(ls -A "${CONFIG_DIR}")" ]; then
        echo -e "${YELLOW}  No tools configured${NC}"
        return
    fi
    
    for config_file in "${CONFIG_DIR}"/*.yml; do
        if [ -f "${config_file}" ]; then
            local tool_name=$(yq eval '.name' "${config_file}")
            local tool_version=$(yq eval '.version' "${config_file}")
            local tool_description=$(yq eval '.description' "${config_file}")
            local tool_category=$(yq eval '.category' "${config_file}")
            
            echo -e "${BLUE}  ${tool_name}${NC} (v${tool_version}) - ${tool_description} [${tool_category}]"
        fi
    done
}

# Get tool configuration
get_tool_config() {
    local tool_name="$1"
    local config_file="${CONFIG_DIR}/${tool_name}.yml"
    
    if [ ! -f "${config_file}" ]; then
        echo -e "${RED}Error: Tool '${tool_name}' not found${NC}" >&2
        echo -e "${YELLOW}Available tools:${NC}" >&2
        list_tools >&2
        exit 1
    fi
    
    echo "${config_file}"
}

# Generate Dockerfile from template
generate_dockerfile() {
    local tool_name="$1"
    local version="$2"
    local config_file=$(get_tool_config "${tool_name}")
    local output_file="${TEMP_DIR}/${tool_name}.Dockerfile"
    
    echo -e "${BLUE}Generating Dockerfile for ${tool_name}...${NC}" >&2
    
    # Extract configuration values
    local tool_version=$(yq eval '.version' "${config_file}")
    local build_type=$(yq eval '.build.type' "${config_file}")
    local download_url=$(yq eval '.build.url' "${config_file}" | sed "s/{version}/${tool_version}/g")
    local build_deps=$(yq eval '.build.build_dependencies | join(" ")' "${config_file}")
    local runtime_libs=$(yq eval '.build.runtime_libraries[]' "${config_file}" 2>/dev/null || echo "")
    local binary_path=$(yq eval '.build.binary_path' "${config_file}")
    local install_path=$(yq eval '.build.install_path' "${config_file}")
    
    # Generate Dockerfile content based on build type
    cat > "${output_file}" << EOF
# Auto-generated Dockerfile for ${tool_name}
# Based on https://github.com/cougz/docker-distroless

# Stage 1: Base builder
FROM debian:trixie-slim AS base-builder

RUN apt-get update && \\
    apt-get install -y --no-install-recommends ca-certificates tzdata && \\
    apt-get clean && \\
    rm -rf /var/lib/apt/lists/*

RUN echo "app:x:1000:1000:app user:/home/app:/sbin/nologin" > /etc/passwd.minimal && \\
    echo "app:x:1000:" > /etc/group.minimal

RUN echo "hosts: files dns" > /etc/nsswitch.conf

# Stage 2: Tool builder
FROM debian:trixie-slim AS tool-builder

RUN apt-get update && \\
    apt-get install -y --no-install-recommends ${build_deps} && \\
    apt-get clean && \\
    rm -rf /var/lib/apt/lists/*

EOF

    if [ "${build_type}" = "source" ]; then
        local configure_flags=$(yq eval '.build.configure_flags | join(" ")' "${config_file}")
        cat >> "${output_file}" << EOF
ARG TOOL_VERSION=${tool_version}
RUN wget -q "${download_url}" -O /tmp/${tool_name}.tar.gz && \\
    cd /tmp && \\
    tar -xzf ${tool_name}.tar.gz && \\
    cd ${tool_name}-* && \\
    ./configure ${configure_flags} && \\
    make -j\$(nproc) && \\
    make install && \\
    strip ${binary_path} || true

EOF
    else
        cat >> "${output_file}" << EOF
RUN wget -q "${download_url}" -O ${binary_path} && \\
    chmod +x ${binary_path} && \\
    strip ${binary_path} || true

EOF
    fi

    cat >> "${output_file}" << EOF
# Stage 3: Final distroless image
FROM scratch

# Copy base files
COPY --from=base-builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=base-builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=base-builder /etc/passwd.minimal /etc/passwd
COPY --from=base-builder /etc/group.minimal /etc/group
COPY --from=base-builder /etc/nsswitch.conf /etc/nsswitch.conf

# Copy essential libraries
COPY --from=base-builder /lib64/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2
COPY --from=base-builder /lib/x86_64-linux-gnu/libc.so.6 /lib/x86_64-linux-gnu/libc.so.6
COPY --from=base-builder /lib/x86_64-linux-gnu/libpthread.so.0 /lib/x86_64-linux-gnu/libpthread.so.0

EOF

    # Add runtime libraries if they exist
    if [ -n "${runtime_libs}" ]; then
        echo "# Runtime libraries" >> "${output_file}"
        while IFS= read -r lib; do
            if [ -n "${lib}" ]; then
                echo "COPY --from=base-builder ${lib} ${lib}" >> "${output_file}"
            fi
        done <<< "${runtime_libs}"
        echo "" >> "${output_file}"
    fi

    cat >> "${output_file}" << EOF
# Copy tool binary/installation
COPY --from=tool-builder ${binary_path} ${install_path}

# Environment
ENV PATH="/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV HOME="/home/app"
ENV USER="app"
ENV TZ="UTC"
ENV SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"

WORKDIR /home/app
USER 1000:1000

# Labels
LABEL distroless.tool="${tool_name}"
LABEL org.opencontainers.image.description="Distroless base with ${tool_name} v${tool_version}"
LABEL org.opencontainers.image.title="Distroless Base with ${tool_name}"
LABEL org.opencontainers.image.authors="cougz"
LABEL org.opencontainers.image.source="https://github.com/cougz/docker-distroless"
LABEL org.opencontainers.image.base.name="scratch"
EOF
    
    echo -e "${GREEN}✓ Generated: ${output_file}${NC}" >&2
    echo "${output_file}"
}

# Build tool image
build_tool() {
    local tool_name="$1"
    local version="${2:-0.2.0}"
    local config_file=$(get_tool_config "${tool_name}")
    
    echo -e "${GREEN}Building ${tool_name} v$(yq eval '.version' "${config_file}")...${NC}"
    
    # Generate Dockerfile
    local dockerfile=$(generate_dockerfile "${tool_name}" "${version}")
    
    # Build image
    local image_name="distroless-${tool_name}"
    local image_tag="${image_name}:${version}"
    
    echo -e "${BLUE}Building Docker image: ${image_tag}${NC}"
    
    if docker build \
        --platform linux/amd64 \
        --tag "${image_tag}" \
        --label "org.opencontainers.image.version=${version}" \
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
    
    # Cleanup generated Dockerfile
    rm -f "${dockerfile}"
}

# Test tool
test_tool() {
    local tool_name="$1"
    local version="${2:-0.2.0}"
    local config_file=$(get_tool_config "${tool_name}")
    
    local image_tag="distroless-${tool_name}:${version}"
    local test_command=$(yq eval '.build.test_command' "${config_file}")
    
    echo -e "${BLUE}Testing ${tool_name}...${NC}"
    
    if docker run --rm "${image_tag}" ${test_command} >/dev/null 2>&1; then
        echo -e "${GREEN}✓ ${tool_name} test passed${NC}"
    else
        echo -e "${RED}✗ ${tool_name} test failed${NC}" >&2
        exit 1
    fi
}

# Show usage
show_usage() {
    echo "Tool Manager for Docker Distroless Base Images"
    echo ""
    echo "Usage: $0 <command> [arguments]"
    echo ""
    echo "Commands:"
    echo "  list                    List all available tools"
    echo "  build <tool> [version]  Build tool image (default version: 0.2.0)"
    echo "  test <tool> [version]   Test tool image"
    echo "  config <tool>           Show tool configuration"
    echo "  help                    Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 list                 # List available tools"
    echo "  $0 build curl           # Build curl with default version"
    echo "  $0 build curl 0.3.0     # Build curl with specific version"
    echo "  $0 test curl 0.3.0      # Test curl image"
    echo "  $0 config git           # Show git configuration"
    exit 1
}

# Show tool configuration
show_config() {
    local tool_name="$1"
    local config_file=$(get_tool_config "${tool_name}")
    
    echo -e "${GREEN}Configuration for ${tool_name}:${NC}"
    cat "${config_file}"
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
        build)
            if [ $# -eq 0 ]; then
                echo -e "${RED}Error: Tool name required${NC}" >&2
                show_usage
            fi
            build_tool "$1" "${2:-0.2.0}"
            ;;
        test)
            if [ $# -eq 0 ]; then
                echo -e "${RED}Error: Tool name required${NC}" >&2
                show_usage
            fi
            test_tool "$1" "${2:-0.2.0}"
            ;;
        config|show)
            if [ $# -eq 0 ]; then
                echo -e "${RED}Error: Tool name required${NC}" >&2
                show_usage
            fi
            show_config "$1"
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