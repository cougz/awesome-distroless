# Redis distroless image
ARG APP_UID=1000
ARG APP_GID=1000
ARG TZ=UTC
ARG VERSION=7.4.2

# Build stage
FROM debian:trixie-slim AS builder

ARG VERSION
ARG APP_UID
ARG APP_GID

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        wget \
        ca-certificates \
        pkg-config \
        libssl-dev \
        binutils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download and build Redis
WORKDIR /tmp
RUN wget -q "https://download.redis.io/releases/redis-${VERSION}.tar.gz" -O redis.tar.gz && \
    tar -xzf redis.tar.gz && \
    cd redis-${VERSION} && \
    make -j$(nproc) && \
    make install PREFIX=/usr/local && \
    strip /usr/local/bin/redis-* || true

# Create data directory with proper permissions
RUN mkdir -p /data && \
    chown ${APP_UID}:${APP_GID} /data

# Final stage
FROM distroless-base:1.0.0

ARG VERSION
ARG APP_UID
ARG APP_GID

# Copy Redis binaries
COPY --from=builder /usr/local/bin/redis-server /usr/local/bin/redis-server
COPY --from=builder /usr/local/bin/redis-cli /usr/local/bin/redis-cli

# Copy runtime libraries for Redis
COPY --from=builder /lib/x86_64-linux-gnu/libc.so.6 /lib/x86_64-linux-gnu/libc.so.6
COPY --from=builder /lib/x86_64-linux-gnu/libpthread.so.0 /lib/x86_64-linux-gnu/libpthread.so.0
COPY --from=builder /lib/x86_64-linux-gnu/libm.so.6 /lib/x86_64-linux-gnu/libm.so.6
COPY --from=builder /lib64/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2

# Create data directory
COPY --from=builder --chown=${APP_UID}:${APP_GID} /data /data

# Environment variables
ENV PATH="/usr/local/bin:${PATH}"

# Switch to app user
USER ${APP_UID}:${APP_GID}

# Set working directory to data directory
WORKDIR /data

# Expose Redis port
EXPOSE 6379

# Labels
LABEL org.opencontainers.image.title="Distroless Redis"
LABEL org.opencontainers.image.description="Minimal distroless Redis image"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.source="https://github.com/cougz/docker-distroless"

# Health check using redis-cli
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/usr/local/bin/redis-cli", "ping"]

ENTRYPOINT ["/usr/local/bin/redis-server"]
CMD ["/etc/redis/redis.conf"]