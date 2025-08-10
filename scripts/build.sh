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
REGISTRY="${3:-ghcr.io}"
NAMESPACE="${4:-yourusername}"
IMAGE_NAME="distroless-base"

show_usage() {
    echo "Usage: $0 [VERSION] [TOOLS] [REGISTRY] [NAMESPACE]"
    echo ""
    echo "Arguments:"
    echo "  VERSION     Image version (default: 0.2.0)"
    echo "  TOOLS       Comma-separated tools to add (optional)"
    echo "  REGISTRY    Container registry (default: ghcr.io)"
    echo "  NAMESPACE   Registry namespace (default: yourusername)"
    echo ""
    echo "Examples:"
    echo "  $0 0.2.0                        # Build base image only"
    echo "  $0 0.2.0 curl                   # Build base + curl"
    echo "  $0 0.2.0 \"curl,jq\"              # Build base + curl + jq"
    echo "  $0 0.2.0 curl ghcr.io myorg     # Build for custom org"
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
    IMAGE_TAG="${IMAGE_NAME}-${TOOLS_SUFFIX}:${VERSION}"
    REGISTRY_TAG="${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}-${TOOLS_SUFFIX}:${VERSION}"
    DOCKERFILE="tools/combined.Dockerfile"
else
    IMAGE_TAG="${IMAGE_NAME}:${VERSION}"
    REGISTRY_TAG="${REGISTRY}/${NAMESPACE}/${IMAGE_NAME}:${VERSION}"
    DOCKERFILE="Dockerfile"
fi

# Print build information
echo -e "${GREEN}Building Distroless Base Image${NC}"
echo -e "${YELLOW}Version:${NC} ${VERSION}"
echo -e "${YELLOW}Tools:${NC} ${TOOLS:-"none (base image only)"}"
echo -e "${YELLOW}Registry:${NC} ${REGISTRY}"
echo -e "${YELLOW}Namespace:${NC} ${NAMESPACE}"
echo -e "${YELLOW}Local tag:${NC} ${IMAGE_TAG}"
echo -e "${YELLOW}Registry tag:${NC} ${REGISTRY_TAG}"
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
        --tag "${REGISTRY_TAG}" \
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
            --tag "${REGISTRY_TAG}" \
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
FROM debian:12-slim AS base-builder

# Install ca-certificates and timezone data
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates tzdata && \
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
FROM debian:12-slim AS curl-builder
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
    LDFLAGS="-static" PKG_CONFIG="pkg-config --static" \
    ./configure \
        --disable-shared \
        --enable-static \
        --disable-ldap \
        --disable-ipv6 \
        --with-ssl \
        --disable-docs \
        --disable-manual \
        --without-libpsl && \
    make -j$(nproc) && \
    strip src/curl \
    upx --best src/curl || true

EOF
                    ;;
                jq)
                    cat >> "${TEMP_DOCKERFILE}" << 'EOF'

# Download jq
FROM debian:12-slim AS jq-builder
RUN apt-get update && \
    apt-get install -y --no-install-recommends wget ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
RUN wget -q -L "https://github.com/jqlang/jq/releases/latest/download/jq-linux64" -O /tmp/jq && \
    chmod +x /tmp/jq && \
    strip /tmp/jq

EOF
                    ;;
                dig)
                    cat >> "${TEMP_DOCKERFILE}" << 'EOF'

# Get dig
FROM debian:12-slim AS dig-builder
RUN apt-get update && \
    apt-get install -y --no-install-recommends dnsutils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
RUN cp /usr/bin/dig /tmp/dig && \
    strip /tmp/dig

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

EOF

        # Copy each tool binary
        for tool in "${TOOL_ARRAY[@]}"; do
            case "${tool}" in
                curl)
                    cat >> "${TEMP_DOCKERFILE}" << 'EOF'
COPY --from=curl-builder /curl-*/src/curl /usr/local/bin/curl
EOF
                    ;;
                jq)
                    cat >> "${TEMP_DOCKERFILE}" << 'EOF'
COPY --from=jq-builder /tmp/jq /usr/local/bin/jq
EOF
                    ;;
                dig)
                    cat >> "${TEMP_DOCKERFILE}" << 'EOF'
COPY --from=dig-builder /tmp/dig /usr/local/bin/dig
EOF
                    ;;
            esac
        done

        # Final configuration
        cat >> "${TEMP_DOCKERFILE}" << EOF

# Set environment variables
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV HOME="/home/app"
ENV USER="app"
ENV TZ="UTC"
ENV SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"

WORKDIR /home/app
USER 1000:1000

# Labels
LABEL distroless.tools="${TOOLS}"
LABEL org.opencontainers.image.description="Distroless base with tools: ${TOOLS}"
LABEL org.opencontainers.image.title="Distroless Base with Tools"
LABEL org.opencontainers.image.authors="cougz"
LABEL org.opencontainers.image.source="https://github.com/cougz/docker-distroless-base"
LABEL org.opencontainers.image.base.name="scratch"
LABEL org.opencontainers.image.version="${VERSION}"
EOF

        # Build the combined image
        if docker build \
            --platform linux/amd64 \
            --tag "${IMAGE_TAG}" \
            --tag "${REGISTRY_TAG}" \
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
if [ -n "${TOOLS}" ]; then
    docker images --filter "reference=${IMAGE_NAME}-*" --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
else
    docker images --filter "reference=${IMAGE_NAME}" --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
fi

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
            dig)
                if docker run --rm "${IMAGE_TAG}" dig -v >/dev/null 2>&1; then
                    echo -e "${GREEN}  ✓ dig is working${NC}"
                else
                    echo -e "${RED}  ✗ dig test failed${NC}"
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
echo -e "${YELLOW}  ./scripts/publish.sh ${VERSION} ${NAMESPACE}${NC}"

if [ -n "${TOOLS}" ]; then
    echo ""
    echo "To use this image:"
    echo -e "${YELLOW}  docker run --rm ${IMAGE_TAG} curl --version${NC}"
fi