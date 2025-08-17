# Testing utility: Node.js runtime with npm
ARG APP_UID=1000
ARG APP_GID=1000
ARG TZ=UTC
ARG VERSION=22.12.0

# Build stage
FROM debian:trixie-slim AS builder

ARG VERSION
ARG APP_UID
ARG APP_GID

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        wget \
        xz-utils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download and install Node.js
WORKDIR /tmp
RUN wget -O node.tar.xz "https://nodejs.org/dist/v${VERSION}/node-v${VERSION}-linux-x64.tar.xz" && \
    tar -xf node.tar.xz && \
    mv node-v${VERSION}-linux-x64 /usr/local/node

# Final stage
FROM distroless-base:1.0.0

ARG VERSION

# Copy Node.js installation
COPY --from=builder /usr/local/node /usr/local/node

# Set Node.js environment
ENV PATH="/usr/local/node/bin:${PATH}"
ENV NODE_PATH="/usr/local/node/lib/node_modules"

# Labels
LABEL org.opencontainers.image.title="Distroless Node.js"
LABEL org.opencontainers.image.description="Minimal distroless image with Node.js runtime for testing"
LABEL org.opencontainers.image.version="${VERSION}"

ENTRYPOINT ["/usr/local/node/bin/node"]