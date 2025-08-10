#!/bin/bash

# Enhanced build script for distroless base image with optional tools
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
    list_available_tools_detailed
    exit 1
}

list_available_tools() {
    if [ -d "tools" ]; then
        find tools/ -name "*.Dockerfile" 2>/dev/null | sed 's/tools\///g' | sed 's/\.Dockerfile//g' | tr '\n' ',' | sed 's/,$//' || echo "none"
    else
        echo "none"
    fi
}

list_available_tools_detailed() {
    if [ -d "tools" ]; then
        for dockerfile in tools/*.Dockerfile; do
            if [ -f "$dockerfile" ]; then
                tool_name=$(basename "$dockerfile" .Dockerfile)
                echo "    $tool_name"
            fi
        done
    else
        echo "    No tools directory found"
    fi
}

# Handle help flag
if [[ "${1:-}" =~ ^(-h|--help)$ ]]; then
    show_usage
fi

# Determine image naming
if [ -n "${TOOLS}" ]; then
    # Sort tools for consistent naming
    SORTED_TOOLS=$(echo "${TOOLS}" | tr ',' '\n' | sort | tr '\n' ',' | sed 's/,$//')
    TOOLS_SUFFIX=$(echo "${SORTED_TOOLS}" | tr ',' '-')
    IMAGE_NAME="distroless-${TOOLS_SUFFIX}"
    IMAGE_TAG="${IMAGE_NAME}:${VERSION}"
    DOCKERFILE="tools/combined.Dockerfile"
else
    IMAGE_NAME="distroless-base"
    IMAGE_TAG="${IMAGE_NAME}:${VERSION}"
    DOCKERFILE="Dockerfile"
fi

# Print build information
echo -e "${GREEN}Building Distroless Image${NC}"
echo -e "${YELLOW}Version:${NC} ${VERSION}"
echo -e "${YELLOW}Tools:${NC} ${TOOLS:-"none (base image only)"}"
echo -e "${YELLOW}Image:${NC} ${IMAGE_TAG}"
echo ""

# Validate tools
if [ -n "${TOOLS}" ]; then
    echo -e "${BLUE}Validating requested tools...${NC}"
    AVAILABLE=$(list_available_tools)
    IFS=',' read -ra TOOL_ARRAY <<< "${TOOLS}"
    for tool in "${TOOL_ARRAY[@]}"; do
        if [[ ",${AVAILABLE}," != *",${tool},"* ]]; then
            echo -e "${RED}Error: Unknown tool '${tool}'${NC}"
            echo -e "${YELLOW}Available tools: ${AVAILABLE}${NC}"
            exit 1
        fi
        echo -e "${GREEN}  ✓ ${tool}${NC}"
    done
fi

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed or not in PATH${NC}"
    exit 1
fi

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

# Change to project directory
cd "${PROJECT_DIR}"

# If no tools requested, build base image
if [ -z "${TOOLS}" ]; then
    echo -e "${BLUE}Building base image...${NC}"
    
    if docker build \
        --platform linux/amd64 \
        --tag "${IMAGE_TAG}" \
        --label "org.opencontainers.image.version=${VERSION}" \
        --label "org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --file "${DOCKERFILE}" \
        . ; then
        echo -e "${GREEN}✓ Base image build successful!${NC}"
    else
        echo -e "${RED}✗ Base image build failed!${NC}"
        exit 1
    fi
else
    # Build tools image using individual tool Dockerfiles
    echo -e "${BLUE}Building image with tools...${NC}"
    
    # For single tool, use the individual Dockerfile
    if [[ "${TOOLS}" != *","* ]]; then
        TOOL_DOCKERFILE="tools/${TOOLS}.Dockerfile"
        if [ ! -f "${TOOL_DOCKERFILE}" ]; then
            echo -e "${RED}Error: ${TOOL_DOCKERFILE} not found${NC}"
            exit 1
        fi
        
        if docker build \
            --platform linux/amd64 \
            --tag "${IMAGE_TAG}" \
            --label "org.opencontainers.image.version=${VERSION}" \
            --label "org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            --file "${TOOL_DOCKERFILE}" \
            . ; then
            echo -e "${GREEN}✓ Tools image build successful!${NC}"
        else
            echo -e "${RED}✗ Tools image build failed!${NC}"
            exit 1
        fi
    else
        # For multiple tools, create a combined Dockerfile
        echo -e "${BLUE}Creating combined Dockerfile for multiple tools...${NC}"
        
        TEMP_DOCKERFILE=$(mktemp)
        
        # Start with the base builder stage (same as main Dockerfile)
        cat > "${TEMP_DOCKERFILE}" << 'EOF'
# Multi-stage build for distroless base with multiple tools
FROM debian:trixie-slim AS base-builder

# Install ca-certificates, timezone data, and required libraries
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        tzdata \
        libcurl4-gnutls-dev \
        libpcre2-dev \
        liblzma-dev \
        libexpat1-dev \
        libgnutls30t64 \
        libnettle8t64 \
        libhogweed6t64 \
        libgmp10 \
        libidn2-0 \
        libunistring5 \
        libtasn1-6 \
        libp11-kit0 \
        libffi8 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create user and group files for non-root user
RUN echo "app:x:1000:1000:app user:/home/app:/sbin/nologin" > /etc/passwd.minimal && \
    echo "app:x:1000:" > /etc/group.minimal

# Create minimal nsswitch.conf for proper name resolution
RUN echo "hosts: files dns" > /etc/nsswitch.conf

EOF

        # Add each tool stage
        IFS=',' read -ra TOOL_ARRAY <<< "${TOOLS}"
        for tool in "${TOOL_ARRAY[@]}"; do
            case "${tool}" in
                curl)
                    cat >> "${TEMP_DOCKERFILE}" << 'EOF'

# Build curl
FROM debian:trixie-slim AS curl-builder
ARG CURL_VERSION=8.11.1
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        libssl-dev \
        zlib1g-dev \
        wget \
        ca-certificates \
        pkg-config && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
RUN wget -q https://curl.se/download/curl-${CURL_VERSION}.tar.gz && \
    tar xzf curl-${CURL_VERSION}.tar.gz && \
    cd curl-${CURL_VERSION} && \
    ./configure \
        --disable-shared \
        --enable-static \
        --disable-ldap \
        --disable-ipv6 \
        --with-openssl \
        --with-zlib \
        --disable-docs \
        --disable-manual \
        --without-libpsl \
        --with-ca-bundle=/etc/ssl/certs/ca-certificates.crt && \
    make -j$(nproc) && \
    strip src/curl && \
    cp src/curl /tmp/curl

EOF
                    ;;
                jq)
                    cat >> "${TEMP_DOCKERFILE}" << 'EOF'

# Download jq
FROM debian:trixie-slim AS jq-builder
RUN apt-get update && \
    apt-get install -y --no-install-recommends wget ca-certificates binutils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
RUN wget -q -L "https://github.com/jqlang/jq/releases/latest/download/jq-linux64" -O /tmp/jq && \
    chmod +x /tmp/jq && \
    strip /tmp/jq

EOF
                    ;;
                git)
                    cat >> "${TEMP_DOCKERFILE}" << 'EOF'

# Build git
FROM debian:trixie-slim AS git-builder
ARG GIT_VERSION=2.50.1
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        libssl-dev \
        libghc-zlib-dev \
        libcurl4-gnutls-dev \
        libpcre2-dev \
        liblzma-dev \
        libexpat1-dev \
        gettext \
        unzip \
        wget \
        ca-certificates \
        binutils \
        autoconf \
        make && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
RUN wget -q "https://github.com/git/git/archive/v${GIT_VERSION}.tar.gz" -O /tmp/git.tar.gz && \
    cd /tmp && \
    tar -xzf git.tar.gz && \
    cd git-${GIT_VERSION} && \
    make configure && \
    ./configure \
        --prefix=/tmp/git-install \
        --with-curl \
        --with-expat \
        --with-openssl \
        --without-tcltk \
        --without-python && \
    make -j$(nproc) all && \
    make install && \
    strip /tmp/git-install/bin/git && \
    strip /tmp/git-install/bin/git-* || true && \
    strip /tmp/git-install/libexec/git-core/git || true && \
    strip /tmp/git-install/libexec/git-core/git-* || true

EOF
                    ;;
                go)
                    cat >> "${TEMP_DOCKERFILE}" << 'EOF'

# Download Go
FROM debian:trixie-slim AS go-builder
ARG GO_VERSION=1.24.6
RUN apt-get update && \
    apt-get install -y --no-install-recommends wget ca-certificates tar binutils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
RUN wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -O /tmp/go.tar.gz && \
    cd /tmp && \
    tar -xzf go.tar.gz && \
    strip /tmp/go/bin/* || true

EOF
                    ;;
                node)
                    cat >> "${TEMP_DOCKERFILE}" << 'EOF'

# Download Node.js
FROM debian:trixie-slim AS node-builder
ARG NODE_VERSION=24.5.0
RUN apt-get update && \
    apt-get install -y --no-install-recommends wget ca-certificates xz-utils binutils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
RUN wget -q "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" -O /tmp/node.tar.xz && \
    cd /tmp && \
    tar -xJf node.tar.xz && \
    mv node-v${NODE_VERSION}-linux-x64 node && \
    strip /tmp/node/bin/node && \
    strip /tmp/node/bin/npm || true && \
    strip /tmp/node/bin/npx || true

EOF
                    ;;
            esac
        done

        # Final stage
        cat >> "${TEMP_DOCKERFILE}" << 'EOF'

# Final stage: Build the distroless image from scratch
FROM scratch

# Copy essential files from base-builder
COPY --from=base-builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=base-builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=base-builder /etc/passwd.minimal /etc/passwd
COPY --from=base-builder /etc/group.minimal /etc/group
COPY --from=base-builder /etc/nsswitch.conf /etc/nsswitch.conf

COPY --from=base-builder /lib64/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2
COPY --from=base-builder /lib/x86_64-linux-gnu/libc.so.6 /lib/x86_64-linux-gnu/libc.so.6
COPY --from=base-builder /lib/x86_64-linux-gnu/libpthread.so.0 /lib/x86_64-linux-gnu/libpthread.so.0
COPY --from=base-builder /lib/x86_64-linux-gnu/libssl.so.3 /lib/x86_64-linux-gnu/libssl.so.3
COPY --from=base-builder /lib/x86_64-linux-gnu/libcrypto.so.3 /lib/x86_64-linux-gnu/libcrypto.so.3
COPY --from=base-builder /lib/x86_64-linux-gnu/libz.so.1 /lib/x86_64-linux-gnu/libz.so.1
COPY --from=base-builder /usr/lib/x86_64-linux-gnu/libzstd.so.1 /usr/lib/x86_64-linux-gnu/libzstd.so.1

EOF

        # Copy each tool binary
        for tool in "${TOOL_ARRAY[@]}"; do
            case "${tool}" in
                curl)
                    cat >> "${TEMP_DOCKERFILE}" << 'EOF'
COPY --from=curl-builder /tmp/curl /usr/local/bin/curl
EOF
                    ;;
                jq)
                    cat >> "${TEMP_DOCKERFILE}" << 'EOF'
COPY --from=jq-builder /tmp/jq /usr/local/bin/jq
EOF
                    ;;
                git)
                    cat >> "${TEMP_DOCKERFILE}" << 'EOF'
COPY --from=git-builder /tmp/git-install /usr/local/
# Add additional libraries needed for Git
COPY --from=base-builder /usr/lib/x86_64-linux-gnu/libcurl-gnutls.so.4 /usr/lib/x86_64-linux-gnu/libcurl-gnutls.so.4
COPY --from=base-builder /usr/lib/x86_64-linux-gnu/libpcre2-8.so.0 /usr/lib/x86_64-linux-gnu/libpcre2-8.so.0
COPY --from=base-builder /lib/x86_64-linux-gnu/liblzma.so.5 /lib/x86_64-linux-gnu/liblzma.so.5
COPY --from=base-builder /usr/lib/x86_64-linux-gnu/libexpat.so.1 /usr/lib/x86_64-linux-gnu/libexpat.so.1
COPY --from=base-builder /usr/lib/x86_64-linux-gnu/libgnutls.so.30 /usr/lib/x86_64-linux-gnu/libgnutls.so.30
COPY --from=base-builder /usr/lib/x86_64-linux-gnu/libhogweed.so.6 /usr/lib/x86_64-linux-gnu/libhogweed.so.6
COPY --from=base-builder /usr/lib/x86_64-linux-gnu/libnettle.so.8 /usr/lib/x86_64-linux-gnu/libnettle.so.8
COPY --from=base-builder /usr/lib/x86_64-linux-gnu/libgmp.so.10 /usr/lib/x86_64-linux-gnu/libgmp.so.10
COPY --from=base-builder /usr/lib/x86_64-linux-gnu/libidn2.so.0 /usr/lib/x86_64-linux-gnu/libidn2.so.0
COPY --from=base-builder /usr/lib/x86_64-linux-gnu/libunistring.so.5 /usr/lib/x86_64-linux-gnu/libunistring.so.5
COPY --from=base-builder /usr/lib/x86_64-linux-gnu/libtasn1.so.6 /usr/lib/x86_64-linux-gnu/libtasn1.so.6
COPY --from=base-builder /usr/lib/x86_64-linux-gnu/libp11-kit.so.0 /usr/lib/x86_64-linux-gnu/libp11-kit.so.0
COPY --from=base-builder /usr/lib/x86_64-linux-gnu/libffi.so.8 /usr/lib/x86_64-linux-gnu/libffi.so.8
EOF
                    ;;
                go)
                    cat >> "${TEMP_DOCKERFILE}" << 'EOF'
COPY --from=go-builder /tmp/go /usr/local/go
EOF
                    ;;
                node)
                    cat >> "${TEMP_DOCKERFILE}" << 'EOF'
COPY --from=node-builder /tmp/node/bin/node /usr/local/bin/node
COPY --from=node-builder /tmp/node/bin/npm /usr/local/bin/npm
COPY --from=node-builder /tmp/node/bin/npx /usr/local/bin/npx
COPY --from=node-builder /tmp/node/lib /usr/local/lib
COPY --from=node-builder /tmp/node/include /usr/local/include
COPY --from=node-builder /tmp/node/share /usr/local/share
# Add additional libraries needed for Node.js
COPY --from=base-builder /lib/x86_64-linux-gnu/libm.so.6 /lib/x86_64-linux-gnu/libm.so.6
COPY --from=base-builder /lib/x86_64-linux-gnu/libdl.so.2 /lib/x86_64-linux-gnu/libdl.so.2
COPY --from=base-builder /lib/x86_64-linux-gnu/librt.so.1 /lib/x86_64-linux-gnu/librt.so.1
COPY --from=base-builder /usr/lib/x86_64-linux-gnu/libstdc++.so.6 /usr/lib/x86_64-linux-gnu/libstdc++.so.6
COPY --from=base-builder /lib/x86_64-linux-gnu/libgcc_s.so.1 /lib/x86_64-linux-gnu/libgcc_s.so.1
EOF
                    ;;
            esac
        done

        # Final configuration
        cat >> "${TEMP_DOCKERFILE}" << EOF

# Set environment variables
ENV PATH="/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV HOME="/home/app"
ENV USER="app"
ENV TZ="UTC"
ENV SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"
ENV GOROOT="/usr/local/go"
ENV GOPATH="/home/app/go"
ENV NODE_PATH="/usr/local/lib/node_modules"

WORKDIR /home/app
USER 1000:1000

# Labels
LABEL distroless.tools="${TOOLS}"
LABEL org.opencontainers.image.description="Distroless base with tools: ${TOOLS}"
LABEL org.opencontainers.image.title="Distroless Base with Tools"
LABEL org.opencontainers.image.authors="cougz"
LABEL org.opencontainers.image.source="https://github.com/cougz/docker-distroless"
LABEL org.opencontainers.image.base.name="scratch"
LABEL org.opencontainers.image.version="${VERSION}"
EOF

        # Build the combined image
        if docker build \
            --platform linux/amd64 \
            --tag "${IMAGE_TAG}" \
            --label "org.opencontainers.image.version=${VERSION}" \
            --label "org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            --file "${TEMP_DOCKERFILE}" \
            . ; then
            echo -e "${GREEN}✓ Tools image build successful!${NC}"
        else
            echo -e "${RED}✗ Tools image build failed!${NC}"
            rm "${TEMP_DOCKERFILE}"
            exit 1
        fi

        # Cleanup
        rm "${TEMP_DOCKERFILE}"
    fi
fi

# Display image information
echo ""
echo -e "${GREEN}Image Information:${NC}"
docker images --filter "reference=${IMAGE_NAME}" --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

# Verify image size
SIZE=$(docker image inspect "${IMAGE_TAG}" --format='{{.Size}}' | numfmt --to=iec)
echo ""
echo -e "${YELLOW}Image size:${NC} ${SIZE}"

# Set size expectations
if [ -n "${TOOLS}" ]; then
    SIZE_LIMIT=20971520  # 20MB for tool images
    WARNING_MSG="20MB"
else
    SIZE_LIMIT=5242880   # 5MB for base image
    WARNING_MSG="5MB"
fi

SIZE_BYTES=$(docker image inspect "${IMAGE_TAG}" --format='{{.Size}}')
if [ "${SIZE_BYTES}" -gt "${SIZE_LIMIT}" ]; then
    echo -e "${YELLOW}Warning: Image size (${SIZE}) exceeds expected size of ${WARNING_MSG}${NC}"
else
    echo -e "${GREEN}✓ Image size is reasonable (< ${WARNING_MSG})${NC}"
fi

# Test tools if present
if [ -n "${TOOLS}" ]; then
    echo ""
    echo -e "${GREEN}Testing tools...${NC}"
    IFS=',' read -ra TOOL_ARRAY <<< "${TOOLS}"
    for tool in "${TOOL_ARRAY[@]}"; do
        case "${tool}" in
            curl)
                if docker run --rm "${IMAGE_TAG}" curl --version >/dev/null 2>&1; then
                    echo -e "${GREEN}  ✓ curl is working${NC}"
                else
                    echo -e "${RED}  ✗ curl test failed${NC}"
                fi
                ;;
            jq)
                if docker run --rm "${IMAGE_TAG}" jq --version >/dev/null 2>&1; then
                    echo -e "${GREEN}  ✓ jq is working${NC}"
                else
                    echo -e "${RED}  ✗ jq test failed${NC}"
                fi
                ;;
            *)
                echo -e "${YELLOW}  ? ${tool} (no test defined)${NC}"
                ;;
        esac
    done
fi

echo ""
echo -e "${GREEN}Build complete!${NC}"

if [ -n "${TOOLS}" ]; then
    echo ""
    echo "Image includes tools: ${TOOLS}"
fi

echo ""
echo "To publish to registry, run:"
echo -e "${YELLOW}  ./scripts/publish.sh ${IMAGE_TAG}${NC}"

if [ -n "${TOOLS}" ]; then
    echo ""
    echo "To use this image:"
    echo -e "${YELLOW}  docker run --rm ${IMAGE_TAG} curl --version${NC}"
fi