# Auto-generated Dockerfile for jq
# Based on https://github.com/cougz/docker-distroless

# Stage 1: Tool builder
FROM debian:trixie-slim AS tool-builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends wget ca-certificates binutils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ARG TOOL_VERSION=1.8.1
RUN wget -q "https://github.com/jqlang/jq/releases/download/jq-${TOOL_VERSION}/jq-linux-amd64" -O /tmp/jq && \
    chmod +x /tmp/jq && \
    strip /tmp/jq || true

# Stage 2: Final image using distroless base
FROM distroless-base:0.2.0

# Copy essential libraries for dynamically linked binaries
COPY --from=tool-builder /lib64/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2
COPY --from=tool-builder /lib/x86_64-linux-gnu/libc.so.6 /lib/x86_64-linux-gnu/libc.so.6
COPY --from=tool-builder /lib/x86_64-linux-gnu/libpthread.so.0 /lib/x86_64-linux-gnu/libpthread.so.0

# Copy tool binary/installation
COPY --from=tool-builder /tmp/jq /usr/local/bin/jq

# Labels
LABEL distroless.tool="jq"
LABEL org.opencontainers.image.description="Distroless base with jq v1.8.1"
LABEL org.opencontainers.image.title="Distroless Base with jq"
LABEL org.opencontainers.image.authors="cougz"
LABEL org.opencontainers.image.source="https://github.com/cougz/docker-distroless"
LABEL org.opencontainers.image.base.name="scratch"