# Multi-stage build for minimal distroless base image
# Stage 1: Prepare essential files using Debian 12
FROM debian:12-slim AS builder

# Install ca-certificates and timezone data
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates tzdata && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create user and group files for non-root user
# UID/GID 1000 for 'app' user
RUN echo "app:x:1000:1000:app user:/home/app:/sbin/nologin" > /etc/passwd.minimal && \
    echo "app:x:1000:" > /etc/group.minimal

# Create minimal nsswitch.conf for proper name resolution
RUN echo "hosts: files dns" > /etc/nsswitch.conf

# Stage 2: Build the final distroless image from scratch
FROM scratch

# Copy essential files from builder
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /etc/passwd.minimal /etc/passwd
COPY --from=builder /etc/group.minimal /etc/group
COPY --from=builder /etc/nsswitch.conf /etc/nsswitch.conf

# Set environment variables
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV HOME="/home/app"
ENV USER="app"
ENV TZ="UTC"
ENV SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"

# Create home directory for app user
WORKDIR /home/app

# Switch to non-root user
USER 1000:1000

# Add labels for metadata
LABEL org.opencontainers.image.title="Distroless Base"
LABEL org.opencontainers.image.description="Minimal distroless base image with CA certificates and timezone data"
LABEL org.opencontainers.image.authors="cougz"
LABEL org.opencontainers.image.source="https://github.com/cougz/docker-distroless-base"
LABEL org.opencontainers.image.base.name="scratch"
LABEL org.opencontainers.image.version="0.1.0"

# No ENTRYPOINT or CMD - this is a base image