# Global ARG for base image
ARG BASE_IMAGE=distroless-base:1.0.0

# Global build args  
ARG VERSION=1.9.1
ARG APP_UID=1000
ARG APP_GID=1000
ARG TZ=UTC
ARG NODE_VERSION=24.7.0
ARG GO_VERSION=1.25.1

# Stage 1: Clone source code using debian with git
FROM debian:trixie-slim AS source-stage
RUN apt-get update && apt-get install -y git ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /build
ARG VERSION
# Clone the repo and checkout specific version
RUN git clone https://github.com/pocket-id/pocket-id.git . && \
    git checkout v${VERSION}

# Stage 2: Build frontend using Node.js
FROM debian:trixie-slim AS frontend-builder
RUN apt-get update && apt-get install -y wget ca-certificates xz-utils && rm -rf /var/lib/apt/lists/*
ARG NODE_VERSION
# Install Node.js
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
ARG GO_VERSION
# Install Go
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
ARG APP_UID
ARG APP_GID
RUN mkdir -p /tmp/app-data && chown -R ${APP_UID}:${APP_GID} /tmp/app-data

# Final stage
FROM $BASE_IMAGE

ARG VERSION
ARG APP_UID
ARG APP_GID
ARG TZ

# Copy essential libraries for the Go binary (from debian)
COPY --from=backend-builder /lib64/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2
COPY --from=backend-builder /lib/x86_64-linux-gnu/libc.so.6 /lib/x86_64-linux-gnu/libc.so.6
COPY --from=backend-builder /lib/x86_64-linux-gnu/libpthread.so.0 /lib/x86_64-linux-gnu/libpthread.so.0

# Copy the built application binary
COPY --from=backend-builder /build/pocket-id /usr/local/bin/pocket-id

# Copy the built frontend assets
COPY --from=frontend-builder /build/backend/frontend/dist /app/frontend/dist

# Copy configuration template
COPY --from=source-stage /build/.env.example /app/.env.example
COPY --from=source-stage /build/.env.example /app/.env

# Copy pre-created data directory with proper ownership
COPY --from=backend-builder --chown=${APP_UID}:${APP_GID} /tmp/app-data /app/data

# Set working directory
WORKDIR /app

# Labels
LABEL distroless.app="pocket-id"
LABEL org.opencontainers.image.description="Distroless pocket-id application built from source"
LABEL org.opencontainers.image.title="Distroless Pocket-ID Application"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.authors="cougz"
LABEL org.opencontainers.image.source="https://github.com/cougz/awesome-distroless"
LABEL org.opencontainers.image.base.name="distroless-base:1.0.0"

# Set user to run as
USER ${APP_UID}:${APP_GID}

# Set timezone
ENV TZ=${TZ}

# Expose port 1411 (default for pocket-id)
EXPOSE 1411

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD ["/usr/local/bin/pocket-id", "healthcheck"]

# Default command to run pocket-id
CMD ["/usr/local/bin/pocket-id"]