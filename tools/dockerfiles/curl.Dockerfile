# Auto-generated Dockerfile for curl
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
COPY --from=base-builder /lib/x86_64-linux-gnu/libssl.so.3 /lib/x86_64-linux-gnu/libssl.so.3
COPY --from=base-builder /lib/x86_64-linux-gnu/libcrypto.so.3 /lib/x86_64-linux-gnu/libcrypto.so.3
COPY --from=base-builder /lib/x86_64-linux-gnu/libz.so.1 /lib/x86_64-linux-gnu/libz.so.1
COPY --from=base-builder /usr/lib/x86_64-linux-gnu/libzstd.so.1 /usr/lib/x86_64-linux-gnu/libzstd.so.1

# Copy tool binary/installation
COPY --from=tool-builder /usr/local/bin/curl /usr/local/bin/curl

# Environment
ENV PATH="/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV HOME="/home/app"
ENV USER="app"
ENV TZ="UTC"
ENV SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"

WORKDIR /home/app
USER 1000:1000

# Labels
LABEL distroless.tool="curl"
LABEL org.opencontainers.image.description="Distroless base with curl v8.11.1"
LABEL org.opencontainers.image.title="Distroless Base with curl"
LABEL org.opencontainers.image.authors="cougz"
LABEL org.opencontainers.image.source="https://github.com/cougz/docker-distroless"
LABEL org.opencontainers.image.base.name="scratch"