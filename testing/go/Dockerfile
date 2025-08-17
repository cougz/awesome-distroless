# Testing utility: Go runtime for building applications
ARG APP_UID=1000
ARG APP_GID=1000
ARG TZ=UTC
ARG VERSION=1.23.5

# Build stage
FROM debian:trixie-slim AS builder

ARG VERSION
ARG APP_UID
ARG APP_GID

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download and install Go
WORKDIR /tmp
RUN wget -O go.tar.gz "https://golang.org/dl/go${VERSION}.linux-amd64.tar.gz" && \
    tar -xf go.tar.gz && \
    mv go /usr/local/

# Final stage
FROM distroless-base:1.0.0

ARG VERSION

# Copy Go installation
COPY --from=builder /usr/local/go /usr/local/go

# Set Go environment
ENV GOROOT="/usr/local/go"
ENV GOPATH="/home/app/go"
ENV PATH="${GOROOT}/bin:${GOPATH}/bin:${PATH}"

# Create Go workspace
USER 0:0
RUN mkdir -p /home/app/go && chown 1000:1000 /home/app/go
USER 1000:1000

WORKDIR /home/app

# Labels
LABEL org.opencontainers.image.title="Distroless Go"
LABEL org.opencontainers.image.description="Minimal distroless image with Go runtime for testing"
LABEL org.opencontainers.image.version="${VERSION}"

ENTRYPOINT ["/usr/local/go/bin/go"]