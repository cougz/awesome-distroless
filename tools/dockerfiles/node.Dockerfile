# Auto-generated Dockerfile for node
# Based on https://github.com/cougz/docker-distroless

# Stage 1: Base builder
FROM debian:trixie-slim AS base-builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates tzdata && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN echo "app:x:1000:1000:app user:/home/app:/sbin/nologin" > /etc/passwd.minimal && \
    echo "app:x:1000:" > /etc/group.minimal

RUN echo "hosts: files dns" > /etc/nsswitch.conf

# Stage 2: Tool builder
FROM debian:trixie-slim AS tool-builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends wget ca-certificates xz-utils binutils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ARG TOOL_VERSION=24.5.0
RUN wget -q "https://nodejs.org/dist/v${TOOL_VERSION}/node-v${TOOL_VERSION}-linux-x64.tar.xz" -O /tmp/node.tar.xz && \
    cd /tmp && \
    tar -xJf node.tar.xz && \
    mv node-v*-linux-x64 node && \
    strip /tmp/node/bin/node && \
    strip /tmp/node/bin/npm || true && \
    strip /tmp/node/bin/npx || true

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

# Runtime libraries
COPY --from=base-builder /lib/x86_64-linux-gnu/libm.so.6 /lib/x86_64-linux-gnu/libm.so.6
COPY --from=base-builder /lib/x86_64-linux-gnu/libdl.so.2 /lib/x86_64-linux-gnu/libdl.so.2
COPY --from=base-builder /lib/x86_64-linux-gnu/librt.so.1 /lib/x86_64-linux-gnu/librt.so.1
COPY --from=base-builder /usr/lib/x86_64-linux-gnu/libstdc++.so.6 /usr/lib/x86_64-linux-gnu/libstdc++.so.6
COPY --from=base-builder /lib/x86_64-linux-gnu/libgcc_s.so.1 /lib/x86_64-linux-gnu/libgcc_s.so.1

# Copy tool binary/installation
COPY --from=tool-builder /tmp/node /usr/local/

# Environment
ENV PATH="/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV HOME="/home/app"
ENV USER="app"
ENV TZ="UTC"
ENV SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"

WORKDIR /home/app
USER 1000:1000

# Labels
LABEL distroless.tool="node"
LABEL org.opencontainers.image.description="Distroless base with node v24.5.0"
LABEL org.opencontainers.image.title="Distroless Base with node"
LABEL org.opencontainers.image.authors="cougz"
LABEL org.opencontainers.image.source="https://github.com/cougz/docker-distroless"
LABEL org.opencontainers.image.base.name="scratch"