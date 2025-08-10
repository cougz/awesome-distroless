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
        local custom_build_steps=$(yq eval '.build.custom_build_steps[]?' "${config_file}" 2>/dev/null || echo "")
        
        # Determine archive type and extraction command
        local archive_name="${tool_name}.tar.gz"
        local tar_flags="-xzf"
        if [[ "${download_url}" == *".tar.bz2"* ]]; then
            archive_name="${tool_name}.tar.bz2"
            tar_flags="-xjf"
        fi
        
        cat >> "${output_file}" << EOF
ARG TOOL_VERSION=${tool_version}
RUN wget -q "${download_url}" -O /tmp/${archive_name} && \\
    cd /tmp && \\
    tar ${tar_flags} ${archive_name} && \\
    cd postgresql* || cd ${tool_name}* && \\
EOF
        
        # Add custom build steps if they exist
        if [ -n "${custom_build_steps}" ]; then
            while IFS= read -r step; do
                if [ -n "${step}" ]; then
                    echo "    ${step} && \\" >> "${output_file}"
                fi
            done <<< "${custom_build_steps}"
        fi
        
        cat >> "${output_file}" << EOF
    ./configure ${configure_flags} && \\
    make -j\$(nproc) && \\
    make install && \\
    strip ${binary_path} || true

EOF
        
        # Special handling for postgres - initialize with defaults
        if [ "${tool_name}" = "postgres" ]; then
            cat >> "${output_file}" << EOF
# Create app user (UID 1000) and initialize database as that user
RUN useradd -u 1000 -m app && \\
    mkdir -p /tmp/pgdata && \\
    chown -R 1000:1000 /tmp/pgdata /tmp/postgres-install

# Switch to UID 1000 and initialize database
USER 1000
RUN /tmp/postgres-install/bin/initdb -D /tmp/pgdata -U postgres --auth-local=trust --auth-host=trust && \\
    /tmp/postgres-install/bin/postgres -D /tmp/pgdata -p 5433 -F & \\
    sleep 5 && \\
    /tmp/postgres-install/bin/psql -h localhost -p 5433 -U postgres -c "ALTER USER postgres PASSWORD 'postgres';" && \\
    /tmp/postgres-install/bin/pg_ctl stop -D /tmp/pgdata -m fast && \\
    sleep 2 && \\
    chmod 700 /tmp/pgdata && \\
    mkdir -p /tmp/pgdata-final/var/lib/postgresql /tmp/pgdata-final/tmp && \\
    cp -a /tmp/pgdata /tmp/pgdata-final/var/lib/postgresql/data && \\
    chmod 1777 /tmp/pgdata-final/tmp

# Switch back to root for remaining operations
USER root

# Create PostgreSQL configuration files
RUN echo "listen_addresses = '*'" >> /tmp/pgdata/postgresql.conf && \\
    echo "port = 5432" >> /tmp/pgdata/postgresql.conf && \\
    echo "max_connections = 100" >> /tmp/pgdata/postgresql.conf && \\
    echo "shared_buffers = 128MB" >> /tmp/pgdata/postgresql.conf && \\
    echo "log_destination = 'stderr'" >> /tmp/pgdata/postgresql.conf

RUN echo "# TYPE  DATABASE        USER            ADDRESS                 METHOD" > /tmp/pgdata/pg_hba.conf && \\
    echo "local   all             all                                     trust" >> /tmp/pgdata/pg_hba.conf && \\
    echo "host    all             all             127.0.0.1/32            md5" >> /tmp/pgdata/pg_hba.conf && \\
    echo "host    all             all             ::1/128                 md5" >> /tmp/pgdata/pg_hba.conf && \\
    echo "host    all             all             0.0.0.0/0               md5" >> /tmp/pgdata/pg_hba.conf

EOF
        fi
    else
        # Special handling for archives
        if [ "${tool_name}" = "go" ]; then
            cat >> "${output_file}" << EOF
RUN wget -q "${download_url}" -O /tmp/go.tar.gz && \\
    cd /tmp && \\
    tar -xzf go.tar.gz && \\
    strip /tmp/go/bin/* || true

EOF
        elif [ "${tool_name}" = "node" ]; then
            cat >> "${output_file}" << EOF
RUN wget -q "${download_url}" -O /tmp/node.tar.xz && \\
    cd /tmp && \\
    tar -xJf node.tar.xz && \\
    mv node-v*-linux-x64 node && \\
    strip /tmp/node/bin/node && \\
    strip /tmp/node/bin/npm || true && \\
    strip /tmp/node/bin/npx || true

EOF
        else
            cat >> "${output_file}" << EOF
RUN wget -q "${download_url}" -O ${binary_path} && \\
    chmod +x ${binary_path} && \\
    strip ${binary_path} || true

EOF
        fi
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

    # Special handling for postgres - copy libpq shared library
    if [ "${tool_name}" = "postgres" ]; then
        cat >> "${output_file}" << EOF
# Copy PostgreSQL installation and shared libraries
COPY --from=tool-builder ${binary_path} ${install_path}
COPY --from=tool-builder ${binary_path}/lib/libpq.so* /usr/local/lib/

EOF
    else
        cat >> "${output_file}" << EOF
# Copy tool binary/installation
COPY --from=tool-builder ${binary_path} ${install_path}

EOF
    fi
    
    # Special final stage handling for postgres
    if [ "${tool_name}" = "postgres" ]; then
        cat >> "${output_file}" << EOF
# Copy PostgreSQL data directory with defaults (preserve ownership and permissions)  
COPY --from=tool-builder /tmp/pgdata-final/ /

# Environment
ENV PATH="/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV LD_LIBRARY_PATH="/usr/local/lib"
ENV HOME="/home/app"
ENV USER="app"
ENV TZ="UTC"
ENV SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"
ENV PGDATA="/var/lib/postgresql/data"

WORKDIR /home/app
USER 1000:1000

# Expose PostgreSQL port
EXPOSE 5432

# Labels
LABEL distroless.tool="${tool_name}"
LABEL distroless.defaults="user=postgres,password=postgres,database=postgres"
LABEL org.opencontainers.image.description="Distroless PostgreSQL with defaults (postgres/postgres/postgres)"
LABEL org.opencontainers.image.title="Distroless PostgreSQL"
LABEL org.opencontainers.image.authors="cougz"
LABEL org.opencontainers.image.source="https://github.com/cougz/docker-distroless"
LABEL org.opencontainers.image.base.name="scratch"

# Start PostgreSQL directly
ENTRYPOINT ["/usr/local/bin/postgres"]
CMD ["-D", "/var/lib/postgresql/data"]
EOF
    else
        cat >> "${output_file}" << EOF
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
    fi
    
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