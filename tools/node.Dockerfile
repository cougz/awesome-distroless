# Multi-stage build that extends the base distroless build process
FROM debian:trixie-slim AS base-builder

# Install ca-certificates and timezone data (same as main Dockerfile)
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates tzdata && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create user and group files for non-root user
RUN echo "app:x:1000:1000:app user:/home/app:/sbin/nologin" > /etc/passwd.minimal && \
    echo "app:x:1000:" > /etc/group.minimal

# Create minimal nsswitch.conf for proper name resolution
RUN echo "hosts: files dns" > /etc/nsswitch.conf

# Stage 2: Download Node.js binary
FROM debian:trixie-slim AS node-builder

ARG NODE_VERSION=24.5.0

RUN apt-get update && \
    apt-get install -y --no-install-recommends wget ca-certificates xz-utils binutils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download and extract Node.js binary
RUN wget -q "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" -O /tmp/node.tar.xz && \
    cd /tmp && \
    tar -xJf node.tar.xz && \
    mv node-v${NODE_VERSION}-linux-x64 node && \
    strip /tmp/node/bin/node && \
    strip /tmp/node/bin/npm || true && \
    strip /tmp/node/bin/npx || true

# Stage 3: Build the final distroless image from scratch
FROM scratch

# Copy essential files from base-builder
COPY --from=base-builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=base-builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=base-builder /etc/passwd.minimal /etc/passwd
COPY --from=base-builder /etc/group.minimal /etc/group
COPY --from=base-builder /etc/nsswitch.conf /etc/nsswitch.conf

# Copy required shared libraries for Node.js
COPY --from=base-builder /lib64/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2
COPY --from=base-builder /lib/x86_64-linux-gnu/libc.so.6 /lib/x86_64-linux-gnu/libc.so.6
COPY --from=base-builder /lib/x86_64-linux-gnu/libm.so.6 /lib/x86_64-linux-gnu/libm.so.6
COPY --from=base-builder /lib/x86_64-linux-gnu/libpthread.so.0 /lib/x86_64-linux-gnu/libpthread.so.0
COPY --from=base-builder /lib/x86_64-linux-gnu/libdl.so.2 /lib/x86_64-linux-gnu/libdl.so.2
COPY --from=base-builder /lib/x86_64-linux-gnu/librt.so.1 /lib/x86_64-linux-gnu/librt.so.1
COPY --from=base-builder /usr/lib/x86_64-linux-gnu/libstdc++.so.6 /usr/lib/x86_64-linux-gnu/libstdc++.so.6
COPY --from=base-builder /lib/x86_64-linux-gnu/libgcc_s.so.1 /lib/x86_64-linux-gnu/libgcc_s.so.1

# Copy Node.js binaries and libraries
COPY --from=node-builder /tmp/node/bin/node /usr/local/bin/node
COPY --from=node-builder /tmp/node/bin/npm /usr/local/bin/npm
COPY --from=node-builder /tmp/node/bin/npx /usr/local/bin/npx
COPY --from=node-builder /tmp/node/lib /usr/local/lib
COPY --from=node-builder /tmp/node/include /usr/local/include
COPY --from=node-builder /tmp/node/share /usr/local/share

# Set environment variables
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV HOME="/home/app"
ENV USER="app"
ENV TZ="UTC"
ENV SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"
ENV NODE_PATH="/usr/local/lib/node_modules"

WORKDIR /home/app
USER 1000:1000

LABEL distroless.tool="node"
LABEL org.opencontainers.image.description="Distroless base with Node.js v24.5.0"
LABEL org.opencontainers.image.title="Distroless Base with Node.js"
LABEL org.opencontainers.image.authors="cougz"
LABEL org.opencontainers.image.source="https://github.com/cougz/docker-distroless"
LABEL org.opencontainers.image.base.name="scratch"