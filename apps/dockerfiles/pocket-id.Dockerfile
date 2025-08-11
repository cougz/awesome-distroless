# Dockerfile for pocket-id application
# Follows the official source installation instructions
# Uses multi-stage builds with debian builders and distroless final stage
# Based on https://github.com/pocket-id/pocket-id

# Stage 1: Clone source code using debian with git (reliable HTTPS support)
FROM debian:trixie-slim AS source-stage
RUN apt-get update && apt-get install -y git ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /build
# Clone the repo and checkout v1.7.0
RUN git clone https://github.com/pocket-id/pocket-id.git . && \
    git checkout v1.7.0

# Stage 2: Build frontend using Node.js
FROM debian:trixie-slim AS frontend-builder
RUN apt-get update && apt-get install -y wget ca-certificates xz-utils && rm -rf /var/lib/apt/lists/*
# Install Node.js 24.5.0
ARG NODE_VERSION=24.5.0
RUN wget -q "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" -O /tmp/node.tar.xz && \
    cd /tmp && tar -xJf node.tar.xz && \
    mv node-v*-linux-x64 /usr/local/node
ENV PATH="/usr/local/node/bin:${PATH}"
WORKDIR /build
# Copy source from git stage
COPY --from=source-stage /build /build
# Build the frontend  
WORKDIR /build/frontend
RUN npm install -g pnpm && pnpm install && pnpm run build

# Stage 3: Build backend using Go
FROM debian:trixie-slim AS backend-builder  
RUN apt-get update && apt-get install -y wget ca-certificates && rm -rf /var/lib/apt/lists/*
# Install Go 1.24.6
ARG GO_VERSION=1.24.6
RUN wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -O /tmp/go.tar.gz && \
    cd /tmp && tar -xzf go.tar.gz && \
    mv go /usr/local/
ENV PATH="/usr/local/go/bin:${PATH}"
WORKDIR /build
# Copy source from git stage
COPY --from=source-stage /build /build
# Copy built frontend assets from frontend stage to backend/frontend/dist
COPY --from=frontend-builder /build/backend/frontend/dist /build/backend/frontend/dist
# Build the backend
WORKDIR /build/backend/cmd
RUN go build -o ../../pocket-id

# Create data directory structure with proper ownership
RUN mkdir -p /tmp/app-data && chown -R 1000:1000 /tmp/app-data

# Stage 4: Final application image using distroless base
FROM distroless-base:0.2.0

# Copy essential libraries for the Go binary (from our distroless-go image)
COPY --from=distroless-go:1.24.6 /lib64/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2
COPY --from=distroless-go:1.24.6 /lib/x86_64-linux-gnu/libc.so.6 /lib/x86_64-linux-gnu/libc.so.6
COPY --from=distroless-go:1.24.6 /lib/x86_64-linux-gnu/libpthread.so.0 /lib/x86_64-linux-gnu/libpthread.so.0

# Copy the built application binary
COPY --from=backend-builder /build/pocket-id /usr/local/bin/pocket-id

# Copy the built frontend assets
COPY --from=frontend-builder /build/backend/frontend/dist /app/frontend/dist

# Copy configuration template
COPY --from=source-stage /build/.env.example /app/.env.example
COPY --from=source-stage /build/.env.example /app/.env

# Copy pre-created data directory with proper ownership
# This ensures Docker volumes inherit correct permissions
COPY --from=backend-builder --chown=1000:1000 /tmp/app-data /app/data

# Set working directory
WORKDIR /app

# Labels
LABEL distroless.app="pocket-id"
LABEL org.opencontainers.image.description="Distroless pocket-id application built from source"
LABEL org.opencontainers.image.title="Distroless Pocket-ID Application"
LABEL org.opencontainers.image.authors="cougz"
LABEL org.opencontainers.image.source="https://github.com/pocket-id/pocket-id"
LABEL org.opencontainers.image.base.name="distroless-base:0.2.0"

# Expose port 3000 (default for pocket-id)
EXPOSE 3000

# Default command to run pocket-id
CMD ["/usr/local/bin/pocket-id"]