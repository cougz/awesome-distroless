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

# Stage 2: Download jq binary only
FROM debian:trixie-slim AS jq-builder
RUN apt-get update && \
    apt-get install -y --no-install-recommends wget ca-certificates binutils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download static jq binary
RUN wget -q -L "https://github.com/jqlang/jq/releases/latest/download/jq-linux64" -O /tmp/jq && \
    chmod +x /tmp/jq && \
    strip /tmp/jq

# Stage 3: Build the final distroless image from scratch
FROM scratch

# Copy essential files from base-builder
COPY --from=base-builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=base-builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=base-builder /etc/passwd.minimal /etc/passwd
COPY --from=base-builder /etc/group.minimal /etc/group
COPY --from=base-builder /etc/nsswitch.conf /etc/nsswitch.conf

# Copy only the jq binary
COPY --from=jq-builder /tmp/jq /usr/local/bin/jq

# Set environment variables
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV HOME="/home/app"
ENV USER="app"
ENV TZ="UTC"
ENV SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"

WORKDIR /home/app
USER 1000:1000

LABEL distroless.tool="jq"
LABEL org.opencontainers.image.description="Distroless base with jq"
LABEL org.opencontainers.image.title="Distroless Base with jq"
LABEL org.opencontainers.image.authors="cougz"
LABEL org.opencontainers.image.source="https://github.com/cougz/docker-distroless"
LABEL org.opencontainers.image.base.name="scratch"