#!/bin/bash
# Dockerfile Generator - Creates Dockerfiles from YAML configurations
# This demonstrates how to integrate YAML configs with Docker builds
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
TOOLS_CONFIG_DIR="${PROJECT_DIR}/tools/config"
TOOLS_DOCKERFILES_DIR="${PROJECT_DIR}/tools/dockerfiles"

cd "${PROJECT_DIR}"

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v yq &> /dev/null; then
        missing_deps+=("yq")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}Error: Missing required dependencies: ${missing_deps[*]}${NC}" >&2
        echo -e "${YELLOW}Please install missing dependencies before continuing${NC}" >&2
        exit 1
    fi
}

# Generate URL from template
generate_url() {
    local tool_name="$1"
    local tool_version="$2"
    
    case "${tool_name}" in
        git)
            echo "https://github.com/git/git/archive/v${tool_version}.tar.gz"
            ;;
        go)
            echo "https://go.dev/dl/go${tool_version}.linux-amd64.tar.gz"
            ;;
        node)
            echo "https://nodejs.org/dist/v${tool_version}/node-v${tool_version}-linux-x64.tar.xz"
            ;;
        postgres)
            echo "https://ftp.postgresql.org/pub/source/v${tool_version}/postgresql-${tool_version}.tar.bz2"
            ;;
        curl)
            echo "https://curl.se/download/curl-${tool_version}.tar.gz"
            ;;
        jq)
            echo "https://github.com/jqlang/jq/releases/download/jq-${tool_version}/jq-linux-amd64"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Get build dependencies for a tool
get_build_dependencies() {
    local tool_name="$1"
    
    case "${tool_name}" in
        git)
            echo "build-essential libssl-dev zlib1g-dev libcurl4-gnutls-dev libpcre2-dev liblzma-dev libexpat1-dev gettext unzip wget ca-certificates binutils autoconf make"
            ;;
        go)
            echo "wget ca-certificates tar binutils"
            ;;
        node)
            echo "wget ca-certificates xz-utils binutils"
            ;;
        postgres)
            echo "build-essential bzip2 wget ca-certificates libssl-dev zlib1g-dev binutils bison flex"
            ;;
        curl)
            echo "build-essential libssl-dev zlib1g-dev wget ca-certificates pkg-config"
            ;;
        jq)
            echo "wget ca-certificates"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Generate enhanced Dockerfile.multi-tools
generate_multi_tools_dockerfile() {
    echo -e "${BLUE}Generating enhanced Dockerfile.multi-tools from YAML configs...${NC}"
    
    # Get versions from YAML configs
    local git_version=$(grep '^version:' "${TOOLS_CONFIG_DIR}/git.yml" | cut -d'"' -f2)
    local go_version=$(grep '^version:' "${TOOLS_CONFIG_DIR}/go.yml" | cut -d'"' -f2)
    local node_version=$(grep '^version:' "${TOOLS_CONFIG_DIR}/node.yml" | cut -d'"' -f2)
    
    # Generate URLs
    local git_url=$(generate_url "git" "${git_version}")
    local go_url=$(generate_url "go" "${go_version}")
    local node_url=$(generate_url "node" "${node_version}")
    
    # Get dependencies
    local git_deps=$(get_build_dependencies "git")
    local go_deps=$(get_build_dependencies "go")
    local node_deps=$(get_build_dependencies "node")
    
    # Combine and deduplicate dependencies
    local all_deps=$(echo "${git_deps} ${go_deps} ${node_deps}" | tr ' ' '\n' | sort -u | tr '\n' ' ')
    
    cat > "${PROJECT_DIR}/Dockerfile.multi-tools.generated" << EOF
# Auto-generated Multi-tool Distroless Image: Git + Go + Node.js
# Generated from YAML configurations on $(date -u +%Y-%m-%dT%H:%M:%SZ)
# Based on https://github.com/cougz/docker-distroless

# Tool versions from YAML configs:
# - Git: ${git_version}
# - Go: ${go_version}
# - Node.js: ${node_version}

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

# Install all build dependencies (auto-generated from YAML configs)
RUN apt-get update && \\
    apt-get install -y --no-install-recommends \\
$(echo "${all_deps}" | sed 's/ / \\\\\n    /g') && \\
    apt-get clean && \\
    rm -rf /var/lib/apt/lists/*

# Build Git from source (version ${git_version})
RUN wget -q "${git_url}" -O /tmp/git.tar.gz && \\
    cd /tmp && \\
    tar -xzf git.tar.gz && \\
    cd git-* && \\
    make configure && \\
    ./configure --prefix=/tmp/git-install --with-curl --with-expat --with-openssl --without-tcltk --without-python && \\
    make -j\$(nproc) && \\
    make install && \\
    strip /tmp/git-install/bin/* || true

# Download and extract Go (version ${go_version})
RUN wget -q "${go_url}" -O /tmp/go.tar.gz && \\
    cd /tmp && \\
    tar -xzf go.tar.gz && \\
    strip /tmp/go/bin/* || true

# Download and extract Node.js (version ${node_version})
RUN wget -q "${node_url}" -O /tmp/node.tar.xz && \\
    cd /tmp && \\
    tar -xJf node.tar.xz && \\
    mv node-v*-linux-x64 node && \\
    strip /tmp/node/bin/node && \\
    # Don't strip npm/npx as they are scripts, not binaries
    ls -la /tmp/node/bin/

# Stage 3: Final distroless image
FROM distroless-base:0.2.0

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

# Runtime libraries for Git
COPY --from=base-builder /lib/x86_64-linux-gnu/libpcre2-8.so.0 /lib/x86_64-linux-gnu/libpcre2-8.so.0
COPY --from=base-builder /lib/x86_64-linux-gnu/libz.so.1 /lib/x86_64-linux-gnu/libz.so.1

# Copy tools
COPY --from=tool-builder /tmp/git-install/ /usr/local/
COPY --from=tool-builder /tmp/go/ /usr/local/go/
COPY --from=tool-builder /tmp/node/ /usr/local/node/

# Environment
ENV PATH="/usr/local/go/bin:/usr/local/node/bin:/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV GOROOT="/usr/local/go"
ENV HOME="/home/app"
ENV USER="app"
ENV TZ="UTC"
ENV SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"

WORKDIR /home/app
USER 1000:1000

# Labels (auto-generated)
LABEL distroless.tools="git,go,node"
LABEL distroless.versions="git=${git_version},go=${go_version},node=${node_version}"
LABEL org.opencontainers.image.description="Auto-generated distroless base with Git ${git_version}, Go ${go_version}, and Node.js ${node_version}"
LABEL org.opencontainers.image.title="Distroless Multi-Tools (Auto-Generated)"
LABEL org.opencontainers.image.authors="cougz"
LABEL org.opencontainers.image.source="https://github.com/cougz/docker-distroless"
LABEL org.opencontainers.image.base.name="distroless-base:0.2.0"
LABEL org.opencontainers.image.created="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
EOF
    
    echo -e "${GREEN}✓ Generated: Dockerfile.multi-tools.generated${NC}"
    echo -e "${YELLOW}Tools included: Git ${git_version}, Go ${go_version}, Node.js ${node_version}${NC}"
    echo -e "${BLUE}Dependencies auto-detected: $(echo "${all_deps}" | wc -w) packages${NC}"
}

# Show usage
show_usage() {
    echo "Dockerfile Generator for Docker Distroless Project"
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  multi-tools            Generate Dockerfile.multi-tools from YAML configs"
    echo "  help                   Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 multi-tools         # Generate enhanced multi-tools Dockerfile"
    echo ""
    echo "This tool demonstrates integration between YAML configurations"
    echo "and Dockerfile generation for maintainable builds."
}

# Main command handling
main() {
    check_dependencies
    
    if [ $# -eq 0 ]; then
        show_usage
        exit 1
    fi
    
    local command="$1"
    
    case "${command}" in
        multi-tools)
            generate_multi_tools_dockerfile
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