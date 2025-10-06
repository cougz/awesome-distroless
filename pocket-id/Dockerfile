ARG VERSION=1.13.0
ARG APP_UID=1000
ARG APP_GID=1000
ARG TZ=UTC

# Download stage
FROM alpine:3.20 AS pocket-id-download
ARG VERSION
RUN apk add --no-cache curl tar binutils
RUN curl -fL "https://github.com/pocket-id/pocket-id/releases/download/v${VERSION}/pocket-id_${VERSION}_linux_amd64.tar.gz" -o pocket-id.tar.gz
RUN tar -xzf pocket-id.tar.gz -C /
RUN strip /pocket-id

# Final stage
FROM gcr.io/distroless/static-debian12
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

COPY --from=pocket-id-download /pocket-id /pocket-id
COPY --from=pocket-id-download /LICENSE /LICENSE

USER ${APP_UID}:${APP_GID}

ENV TZ=${TZ}

EXPOSE 1411

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD ["/pocket-id", "healthcheck"]

ENTRYPOINT ["/pocket-id"]
