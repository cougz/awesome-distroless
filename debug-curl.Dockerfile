# Debug Dockerfile to check curl dependencies
FROM debian:12-slim AS curl-builder

ARG CURL_VERSION=8.11.1

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        libssl-dev \
        zlib1g-dev \
        wget \
        ca-certificates \
        pkg-config \
        file && \
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
        --disable-docs \
        --disable-manual \
        --without-libpsl && \
    make -j$(nproc) && \
    strip src/curl && \
    cp src/curl /tmp/curl && \
    echo "=== CURL BINARY INFO ===" && \
    file /tmp/curl && \
    echo "=== LDD OUTPUT ===" && \
    ldd /tmp/curl || echo "Static binary - no dynamic dependencies" && \
    echo "=== SIZE ===" && \
    ls -lh /tmp/curl