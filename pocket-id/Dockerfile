ARG VERSION=1.13.0
ARG APP_UID=1000
ARG APP_GID=1000
ARG TZ=UTC
ARG BASE_IMAGE=distroless-base:1.0.0

# Use the official pocket-id image as a builder
FROM ghcr.io/pocket-id/pocket-id:v${VERSION} AS builder

# Use your existing distroless base image
FROM ${BASE_IMAGE}

ARG VERSION
ARG APP_UID
ARG APP_GID
ARG TZ

LABEL \
    org.opencontainers.image.authors="cougz" \
    org.opencontainers.image.title="pocket-id" \
    org.opencontainers.image.description="Run pocket-id rootless and distroless" \
    org.opencontainers.image.documentation="https://github.com/cougz/awesome-distroless" \
    org.opencontainers.image.source="https://github.com/cougz/awesome-distroless" \
    org.opencontainers.image.version="${VERSION}" \
    org.opencontainers.image.licenses="MIT"

WORKDIR /app

# Copy the pocket-id binary from the builder stage
COPY --from=builder /app/pocket-id /app/pocket-id

USER ${APP_UID}:${APP_GID}

ENV TZ=${TZ}

EXPOSE 1411

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD ["/app/pocket-id", "healthcheck"]

ENTRYPOINT ["/app/pocket-id"]