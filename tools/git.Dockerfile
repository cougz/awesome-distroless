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

# Stage 2: Build static Git binary
FROM debian:trixie-slim AS git-builder

ARG GIT_VERSION=2.50.1

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        libssl-dev \
        libghc-zlib-dev \
        libcurl4-gnutls-dev \
        libpcre3-dev \
        liblzma-dev \
        libexpat1-dev \
        gettext \
        unzip \
        wget \
        ca-certificates \
        binutils \
        autoconf \
        make && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download and build static git
RUN wget -q "https://github.com/git/git/archive/v${GIT_VERSION}.tar.gz" -O /tmp/git.tar.gz && \
    cd /tmp && \
    tar -xzf git.tar.gz && \
    cd git-${GIT_VERSION} && \
    make configure && \
    ./configure \
        --prefix=/tmp/git-install \
        --with-curl \
        --with-expat \
        --with-openssl \
        --without-tcltk \
        --without-python && \
    make -j$(nproc) all && \
    make install && \
    strip /tmp/git-install/bin/git && \
    strip /tmp/git-install/bin/git-* || true && \
    strip /tmp/git-install/libexec/git-core/git || true && \
    strip /tmp/git-install/libexec/git-core/git-* || true

# Stage 3: Build the final distroless image from scratch
FROM scratch

# Copy essential files from base-builder
COPY --from=base-builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=base-builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=base-builder /etc/passwd.minimal /etc/passwd
COPY --from=base-builder /etc/group.minimal /etc/group
COPY --from=base-builder /etc/nsswitch.conf /etc/nsswitch.conf

# Copy required shared libraries for Git
COPY --from=base-builder /lib64/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2
COPY --from=base-builder /lib/x86_64-linux-gnu/libc.so.6 /lib/x86_64-linux-gnu/libc.so.6
COPY --from=base-builder /lib/x86_64-linux-gnu/libpthread.so.0 /lib/x86_64-linux-gnu/libpthread.so.0
COPY --from=base-builder /lib/x86_64-linux-gnu/libssl.so.3 /lib/x86_64-linux-gnu/libssl.so.3
COPY --from=base-builder /lib/x86_64-linux-gnu/libcrypto.so.3 /lib/x86_64-linux-gnu/libcrypto.so.3
COPY --from=base-builder /lib/x86_64-linux-gnu/libz.so.1 /lib/x86_64-linux-gnu/libz.so.1
COPY --from=base-builder /usr/lib/x86_64-linux-gnu/libcurl-gnutls.so.4 /usr/lib/x86_64-linux-gnu/libcurl-gnutls.so.4
COPY --from=base-builder /lib/x86_64-linux-gnu/libpcre.so.3 /lib/x86_64-linux-gnu/libpcre.so.3
COPY --from=base-builder /lib/x86_64-linux-gnu/liblzma.so.5 /lib/x86_64-linux-gnu/liblzma.so.5
COPY --from=base-builder /usr/lib/x86_64-linux-gnu/libexpat.so.1 /usr/lib/x86_64-linux-gnu/libexpat.so.1
COPY --from=base-builder /usr/lib/x86_64-linux-gnu/libgnutls.so.30 /usr/lib/x86_64-linux-gnu/libgnutls.so.30
COPY --from=base-builder /usr/lib/x86_64-linux-gnu/libhogweed.so.6 /usr/lib/x86_64-linux-gnu/libhogweed.so.6
COPY --from=base-builder /usr/lib/x86_64-linux-gnu/libnettle.so.8 /usr/lib/x86_64-linux-gnu/libnettle.so.8
COPY --from=base-builder /usr/lib/x86_64-linux-gnu/libgmp.so.10 /usr/lib/x86_64-linux-gnu/libgmp.so.10
COPY --from=base-builder /usr/lib/x86_64-linux-gnu/libidn2.so.0 /usr/lib/x86_64-linux-gnu/libidn2.so.0
COPY --from=base-builder /usr/lib/x86_64-linux-gnu/libunistring.so.2 /usr/lib/x86_64-linux-gnu/libunistring.so.2
COPY --from=base-builder /usr/lib/x86_64-linux-gnu/libtasn1.so.6 /usr/lib/x86_64-linux-gnu/libtasn1.so.6
COPY --from=base-builder /usr/lib/x86_64-linux-gnu/libp11-kit.so.0 /usr/lib/x86_64-linux-gnu/libp11-kit.so.0
COPY --from=base-builder /usr/lib/x86_64-linux-gnu/libffi.so.8 /usr/lib/x86_64-linux-gnu/libffi.so.8

# Copy Git installation
COPY --from=git-builder /tmp/git-install /usr/local/

# Set environment variables
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV HOME="/home/app"
ENV USER="app"
ENV TZ="UTC"
ENV SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"

WORKDIR /home/app
USER 1000:1000

LABEL distroless.tool="git"
LABEL org.opencontainers.image.description="Distroless base with Git v2.50.1"
LABEL org.opencontainers.image.title="Distroless Base with Git"
LABEL org.opencontainers.image.authors="cougz"
LABEL org.opencontainers.image.source="https://github.com/cougz/docker-distroless"
LABEL org.opencontainers.image.base.name="scratch"