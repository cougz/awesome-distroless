# Global ARG for base image
ARG BASE_IMAGE=distroless-base:1.0.0

# Global build args
ARG VERSION=1.9.1
ARG APP_UID=1000
ARG APP_GID=1000
ARG TZ=UTC
ARG NODE_VERSION=24.5.0
ARG GO_VERSION=1.24.6
ARG RESTIC_VERSION=0.18.0

# Stage 1: Clone source code using debian with git
FROM debian:trixie-slim AS source-stage
RUN apt-get update && apt-get install -y git ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /build
ARG VERSION
RUN git clone https://github.com/garethgeorge/backrest.git . && \
    git checkout v${VERSION}

# Stage 2: Build frontend using Node.js
FROM debian:trixie-slim AS frontend-builder
RUN apt-get update && apt-get install -y wget ca-certificates xz-utils && rm -rf /var/lib/apt/lists/*
ARG NODE_VERSION
ARG VERSION
RUN wget -q "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" -O /tmp/node.tar.xz && \
    cd /tmp && tar -xJf node.tar.xz && \
    mv node-v*-linux-x64 /usr/local/node
ENV PATH="/usr/local/node/bin:${PATH}"

WORKDIR /build
COPY --from=source-stage /build /build
WORKDIR /build/webui
# Set the version for the frontend build with distroless prefix
ENV BACKREST_BUILD_VERSION="distroless-backrest-v${VERSION}"
RUN npm install -g pnpm && pnpm install && pnpm run build

# Stage 3: Build backend using Go
FROM debian:trixie-slim AS backend-builder
RUN apt-get update && apt-get install -y wget ca-certificates bzip2 && rm -rf /var/lib/apt/lists/*
ARG GO_VERSION
ARG VERSION
ARG RESTIC_VERSION
RUN wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -O /tmp/go.tar.gz && \
    cd /tmp && tar -xzf go.tar.gz && mv go /usr/local/
ENV PATH="/usr/local/go/bin:${PATH}"

WORKDIR /build
COPY --from=source-stage /build /build
COPY --from=frontend-builder /build/webui/dist ./webui/dist

# Build the backend (skip go generate since frontend is already built)
RUN cd cmd/backrest && \
    CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-s -w -X main.version=v${VERSION} -X main.commit=v${VERSION}" \
    -o /tmp/backrest .

# Download and prepare restic dependency
RUN cd /tmp && \
    wget -q https://github.com/restic/restic/releases/download/v${RESTIC_VERSION}/restic_${RESTIC_VERSION}_linux_amd64.bz2 && \
    bunzip2 restic_${RESTIC_VERSION}_linux_amd64.bz2 && \
    mv restic_${RESTIC_VERSION}_linux_amd64 restic && \
    chmod +x restic

# Create data directory structure with proper ownership
ARG APP_UID
ARG APP_GID
RUN mkdir -p /tmp/app-data /tmp/config /tmp/cache /tmp/repos && \
    chown -R ${APP_UID}:${APP_GID} /tmp/app-data /tmp/config /tmp/cache /tmp/repos

# Final stage
FROM $BASE_IMAGE

ARG VERSION
ARG APP_UID
ARG APP_GID
ARG TZ
ARG RESTIC_VERSION

# Copy essential libraries for the Go binary (from debian)
COPY --from=backend-builder /lib64/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2
COPY --from=backend-builder /lib/x86_64-linux-gnu/libc.so.6 /lib/x86_64-linux-gnu/libc.so.6
COPY --from=backend-builder /lib/x86_64-linux-gnu/libpthread.so.0 /lib/x86_64-linux-gnu/libpthread.so.0

# Copy the built application binaries
COPY --from=backend-builder /tmp/backrest /usr/local/bin/backrest
COPY --from=backend-builder /tmp/restic /usr/local/bin/restic

# Copy pre-created directories with proper ownership
COPY --from=backend-builder --chown=${APP_UID}:${APP_GID} /tmp/app-data /var/lib/backrest/data
COPY --from=backend-builder --chown=${APP_UID}:${APP_GID} /tmp/config /etc/backrest
COPY --from=backend-builder --chown=${APP_UID}:${APP_GID} /tmp/cache /var/cache/backrest
COPY --from=backend-builder --chown=${APP_UID}:${APP_GID} /tmp/repos /repos

# Set working directory and environment
WORKDIR /var/lib/backrest
ENV BACKREST_DATA="/var/lib/backrest/data"
ENV BACKREST_CONFIG="/etc/backrest/config.json"
ENV XDG_CACHE_HOME="/var/cache/backrest"
ENV BACKREST_RESTIC_COMMAND="/usr/local/bin/restic"
ENV TZ=${TZ}

# Labels
LABEL distroless.app="backrest"
LABEL org.opencontainers.image.description="Distroless backrest application built from source"
LABEL org.opencontainers.image.title="Distroless Backrest Application"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.authors="cougz"
LABEL org.opencontainers.image.source="https://github.com/cougz/awesome-distroless"
LABEL org.opencontainers.image.base.name="distroless-base:1.0.0"

# Set user to run as
USER ${APP_UID}:${APP_GID}

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD ["/usr/local/bin/backrest", "--version"]

# Expose port and set entrypoint
EXPOSE 9898
ENTRYPOINT ["/usr/local/bin/backrest"]
CMD ["--bind-address", ":9898"]