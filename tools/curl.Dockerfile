# Multi-stage build that extends the base distroless build process
# Stage 1: Use same base as main Dockerfile
FROM debian:12-slim AS base-builder

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

# Stage 2: Build static curl binary only
FROM debian:12-slim AS curl-builder

ARG CURL_VERSION=8.11.1

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        libssl-dev \
        wget \
        ca-certificates \
        pkg-config && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download and build static curl
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
        --without-zlib \
        --disable-docs \
        --disable-manual \
        --without-libpsl && \
    make -j$(nproc) && \
    strip src/curl && \
    cp src/curl /tmp/curl

# Stage 3: Build the final distroless image from scratch
FROM scratch

# Copy essential files from base-builder (same as main Dockerfile)
COPY --from=base-builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=base-builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=base-builder /etc/passwd.minimal /etc/passwd
COPY --from=base-builder /etc/group.minimal /etc/group
COPY --from=base-builder /etc/nsswitch.conf /etc/nsswitch.conf

COPY --from=base-builder /lib64/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2
COPY --from=base-builder /lib/x86_64-linux-gnu/libc.so.6 /lib/x86_64-linux-gnu/libc.so.6
COPY --from=base-builder /lib/x86_64-linux-gnu/libpthread.so.0 /lib/x86_64-linux-gnu/libpthread.so.0
COPY --from=base-builder /lib/x86_64-linux-gnu/libssl.so.3 /lib/x86_64-linux-gnu/libssl.so.3
COPY --from=base-builder /lib/x86_64-linux-gnu/libcrypto.so.3 /lib/x86_64-linux-gnu/libcrypto.so.3

# Copy only the curl binary
COPY --from=curl-builder /tmp/curl /usr/local/bin/curl

# Set environment variables (same as main Dockerfile)
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV HOME="/home/app"
ENV USER="app"
ENV TZ="UTC"
ENV SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"

# Create home directory for app user
WORKDIR /home/app

# Switch to non-root user
USER 1000:1000

# Metadata
LABEL distroless.tool="curl"
LABEL org.opencontainers.image.description="Distroless base with curl"
LABEL org.opencontainers.image.title="Distroless Base with Curl"
LABEL org.opencontainers.image.authors="cougz"
LABEL org.opencontainers.image.source="https://github.com/cougz/docker-distroless"
LABEL org.opencontainers.image.base.name="scratch"