# Multi-stage build for minimal distroless base image
# Configurable build arguments
ARG APP_UID=1000
ARG APP_GID=1000
ARG TZ=UTC
ARG VERSION=1.0.0

# Stage 1: Prepare essential files using Debian 13
FROM debian:trixie-slim AS builder

# Pass build args to builder stage
ARG APP_UID
ARG APP_GID
ARG TZ

# Install ca-certificates and timezone data
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates tzdata && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create user and group files for non-root user with configurable UID/GID
RUN echo "app:x:${APP_UID}:${APP_GID}:app user:/home/app:/sbin/nologin" > /etc/passwd.minimal && \
    echo "app:x:${APP_GID}:" > /etc/group.minimal

# Create minimal nsswitch.conf for proper name resolution
RUN echo "hosts: files dns" > /etc/nsswitch.conf

# Stage 2: Build the final distroless image from scratch
FROM scratch

# Pass build args to final stage
ARG APP_UID
ARG APP_GID
ARG TZ
ARG VERSION

# Copy essential files from builder
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /etc/passwd.minimal /etc/passwd
COPY --from=builder /etc/group.minimal /etc/group
COPY --from=builder /etc/nsswitch.conf /etc/nsswitch.conf

# Set environment variables with configurable timezone
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV HOME="/home/app"
ENV USER="app"
ENV TZ="${TZ}"
ENV SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"

# Create home directory for app user
WORKDIR /home/app

# Switch to configurable non-root user
USER ${APP_UID}:${APP_GID}

# Add labels for metadata
LABEL org.opencontainers.image.title="Distroless Base"
LABEL org.opencontainers.image.description="Minimal distroless base image with CA certificates and timezone data"
LABEL org.opencontainers.image.authors="cougz"
LABEL org.opencontainers.image.source="https://github.com/cougz/awesome-distroless"
LABEL org.opencontainers.image.base.name="scratch"
LABEL org.opencontainers.image.version="${VERSION}"

# No ENTRYPOINT or CMD - this is a base image