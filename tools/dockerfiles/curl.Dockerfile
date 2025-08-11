# Auto-generated Dockerfile for curl
# Based on https://github.com/cougz/docker-distroless

# Stage 1: Tool builder
FROM debian:trixie-slim AS tool-builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential libssl-dev zlib1g-dev wget ca-certificates pkg-config && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ARG TOOL_VERSION=8.11.1
RUN wget -q "https://curl.se/download/curl-${TOOL_VERSION}.tar.gz" -O /tmp/curl.tar.gz && \
    cd /tmp && \
    tar -xzf curl.tar.gz && \
    cd curl-* && \
    ./configure --disable-shared --enable-static --disable-ldap --disable-ipv6 --with-openssl --with-zlib --disable-docs --disable-manual --without-libpsl --with-ca-bundle=/etc/ssl/certs/ca-certificates.crt && \
    make -j$(nproc) && \
    make install && \
    strip /usr/local/bin/curl || true

# Stage 2: Final image using distroless base
FROM distroless-base:0.2.0

# Copy essential libraries
COPY --from=tool-builder /lib64/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2
COPY --from=tool-builder /lib/x86_64-linux-gnu/libc.so.6 /lib/x86_64-linux-gnu/libc.so.6
COPY --from=tool-builder /lib/x86_64-linux-gnu/libpthread.so.0 /lib/x86_64-linux-gnu/libpthread.so.0

# Runtime libraries
COPY --from=tool-builder /lib/x86_64-linux-gnu/libssl.so.3 /lib/x86_64-linux-gnu/libssl.so.3
COPY --from=tool-builder /lib/x86_64-linux-gnu/libcrypto.so.3 /lib/x86_64-linux-gnu/libcrypto.so.3
COPY --from=tool-builder /lib/x86_64-linux-gnu/libz.so.1 /lib/x86_64-linux-gnu/libz.so.1
COPY --from=tool-builder /usr/lib/x86_64-linux-gnu/libzstd.so.1 /usr/lib/x86_64-linux-gnu/libzstd.so.1

# Copy tool binary/installation
COPY --from=tool-builder /usr/local/bin/curl /usr/local/bin/curl

# Labels
LABEL distroless.tool="curl"
LABEL org.opencontainers.image.description="Distroless base with curl v8.11.1"
LABEL org.opencontainers.image.title="Distroless Base with curl"
LABEL org.opencontainers.image.authors="cougz"
LABEL org.opencontainers.image.source="https://github.com/cougz/docker-distroless"
LABEL org.opencontainers.image.base.name="scratch"