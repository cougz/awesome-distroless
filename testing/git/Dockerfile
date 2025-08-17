# Testing utility: git with HTTPS support
ARG APP_UID=1000
ARG APP_GID=1000
ARG TZ=UTC
ARG VERSION=2.47.1

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
        libcurl4-openssl-dev \
        libexpat1-dev \
        gettext \
        zlib1g-dev \
        wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download and build git
WORKDIR /tmp
RUN wget -O git.tar.xz "https://github.com/git/git/archive/v${VERSION}.tar.gz" && \
    tar -xf git.tar.xz && \
    cd git-${VERSION} && \
    ./configure \
        --prefix=/usr/local \
        --with-openssl \
        --with-curl \
        --with-expat && \
    make configure && \
    make -j$(nproc) && \
    make install && \
    strip /usr/local/bin/git*

# Final stage  
FROM distroless-base:1.0.0

ARG VERSION

# Copy git binaries
COPY --from=builder /usr/local/bin/git* /usr/local/bin/
COPY --from=builder /usr/local/libexec/git-core /usr/local/libexec/git-core

# Labels
LABEL org.opencontainers.image.title="Distroless Git"
LABEL org.opencontainers.image.description="Minimal distroless image with Git for testing"
LABEL org.opencontainers.image.version="${VERSION}"

ENTRYPOINT ["/usr/local/bin/git"]