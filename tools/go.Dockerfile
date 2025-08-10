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

# Stage 2: Download Go binary
FROM debian:trixie-slim AS go-builder

ARG GO_VERSION=1.24.6

RUN apt-get update && \
    apt-get install -y --no-install-recommends wget ca-certificates tar binutils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download and extract Go binary
RUN wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -O /tmp/go.tar.gz && \
    cd /tmp && \
    tar -xzf go.tar.gz && \
    strip /tmp/go/bin/* || true

# Stage 3: Build the final distroless image from scratch
FROM scratch

# Copy essential files from base-builder
COPY --from=base-builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=base-builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=base-builder /etc/passwd.minimal /etc/passwd
COPY --from=base-builder /etc/group.minimal /etc/group
COPY --from=base-builder /etc/nsswitch.conf /etc/nsswitch.conf

# Copy required shared libraries for Go
COPY --from=base-builder /lib64/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2
COPY --from=base-builder /lib/x86_64-linux-gnu/libc.so.6 /lib/x86_64-linux-gnu/libc.so.6
COPY --from=base-builder /lib/x86_64-linux-gnu/libpthread.so.0 /lib/x86_64-linux-gnu/libpthread.so.0

# Copy Go installation
COPY --from=go-builder /tmp/go /usr/local/go

# Set environment variables
ENV PATH="/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV HOME="/home/app"
ENV USER="app"
ENV TZ="UTC"
ENV SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"
ENV GOROOT="/usr/local/go"
ENV GOPATH="/home/app/go"

# Create Go workspace directory
WORKDIR /home/app
USER 1000:1000

LABEL distroless.tool="go"
LABEL org.opencontainers.image.description="Distroless base with Go v1.24.6"
LABEL org.opencontainers.image.title="Distroless Base with Go"
LABEL org.opencontainers.image.authors="cougz"
LABEL org.opencontainers.image.source="https://github.com/cougz/docker-distroless"
LABEL org.opencontainers.image.base.name="scratch"