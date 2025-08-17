# Testing utility: curl with SSL support
ARG APP_UID=1000
ARG APP_GID=1000
ARG TZ=UTC
ARG VERSION=8.11.1

# Build stage
FROM debian:trixie-slim AS builder

ARG VERSION
ARG APP_UID
ARG APP_GID

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        libssl-dev \
        libnghttp2-dev \
        libzstd-dev \
        zlib1g-dev \
        wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download and build curl
WORKDIR /tmp
RUN wget -O curl.tar.xz "https://curl.se/download/curl-${VERSION}.tar.xz" && \
    tar -xf curl.tar.xz && \
    cd curl-${VERSION} && \
    ./configure \
        --prefix=/usr/local \
        --with-openssl \
        --with-nghttp2 \
        --enable-static \
        --disable-shared \
        --disable-ldap \
        --disable-ldaps \
        --disable-rtsp \
        --disable-dict \
        --disable-telnet \
        --disable-tftp \
        --disable-pop3 \
        --disable-imap \
        --disable-smb \
        --disable-smtp \
        --disable-gopher \
        --disable-manual && \
    make -j$(nproc) && \
    make install && \
    strip /usr/local/bin/curl

# Final stage
FROM distroless-base:1.0.0

ARG VERSION

# Copy curl binary
COPY --from=builder /usr/local/bin/curl /usr/local/bin/curl

# Labels
LABEL org.opencontainers.image.title="Distroless cURL"
LABEL org.opencontainers.image.description="Minimal distroless image with cURL for testing"
LABEL org.opencontainers.image.version="${VERSION}"

ENTRYPOINT ["/usr/local/bin/curl"]