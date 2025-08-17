# PostgreSQL distroless image
ARG APP_UID=1000
ARG APP_GID=1000
ARG TZ=UTC
ARG VERSION=17.5

# Build stage
FROM debian:trixie-slim AS builder

ARG VERSION
ARG APP_UID
ARG APP_GID
ARG TZ

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        bzip2 \
        wget \
        ca-certificates \
        libssl-dev \
        zlib1g-dev \
        binutils \
        bison \
        flex && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download and build PostgreSQL
WORKDIR /tmp
RUN wget -q "https://ftp.postgresql.org/pub/source/v${VERSION}/postgresql-${VERSION}.tar.bz2" -O postgres.tar.bz2 && \
    tar -xjf postgres.tar.bz2 && \
    cd postgresql-${VERSION} && \
    ./configure \
        --prefix=/usr/local \
        --with-openssl \
        --with-zlib \
        --without-icu \
        --without-readline && \
    make -j$(nproc) && \
    make install && \
    strip /usr/local/bin/* /usr/local/lib/*.so* || true

# Create app user and initialize database
RUN useradd -u ${APP_UID} -g ${APP_GID} -m app || groupadd -g ${APP_GID} app && useradd -u ${APP_UID} -g ${APP_GID} -m app && \
    mkdir -p /tmp/pgdata && \
    chown -R ${APP_UID}:${APP_GID} /tmp/pgdata /usr/local

# Switch to app user and initialize database
USER ${APP_UID}:${APP_GID}
RUN /usr/local/bin/initdb -D /tmp/pgdata -U postgres --auth-local=trust --auth-host=trust && \
    echo "host    all             all             0.0.0.0/0               trust" >> /tmp/pgdata/pg_hba.conf && \
    echo "host    all             all             ::/0                    trust" >> /tmp/pgdata/pg_hba.conf

# Switch back to root to modify configuration
USER root

# Update PostgreSQL configuration
RUN cat > /tmp/pgdata/postgresql.conf << 'EOF'
# PostgreSQL configuration for distroless image
listen_addresses = '*'
port = 5432
max_connections = 100
shared_buffers = 128MB
dynamic_shared_memory_type = posix
max_wal_size = 1GB
min_wal_size = 80MB
log_timezone = 'UTC'
datestyle = 'iso, mdy'
timezone = 'UTC'
default_text_search_config = 'pg_catalog.english'
log_destination = 'stderr'
logging_collector = off
EOF

# Prepare final data directory with correct permissions
RUN chmod 700 /tmp/pgdata && \
    mkdir -p /tmp/pgdata-final/var/lib/postgresql && \
    cp -a /tmp/pgdata /tmp/pgdata-final/var/lib/postgresql/data && \
    chown -R ${APP_UID}:${APP_GID} /tmp/pgdata-final

# Final stage
FROM distroless-base:1.0.0

ARG VERSION
ARG APP_UID
ARG APP_GID

# Copy PostgreSQL installation
COPY --from=builder /usr/local /usr/local

# Copy runtime libraries (essential for PostgreSQL)
COPY --from=builder /lib/x86_64-linux-gnu/libssl.so.3 /lib/x86_64-linux-gnu/libssl.so.3
COPY --from=builder /lib/x86_64-linux-gnu/libcrypto.so.3 /lib/x86_64-linux-gnu/libcrypto.so.3
COPY --from=builder /lib/x86_64-linux-gnu/libz.so.1 /lib/x86_64-linux-gnu/libz.so.1
COPY --from=builder /lib/x86_64-linux-gnu/libm.so.6 /lib/x86_64-linux-gnu/libm.so.6
COPY --from=builder /lib/x86_64-linux-gnu/libc.so.6 /lib/x86_64-linux-gnu/libc.so.6
COPY --from=builder /lib/x86_64-linux-gnu/libpthread.so.0 /lib/x86_64-linux-gnu/libpthread.so.0
COPY --from=builder /lib64/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2
COPY --from=builder /usr/lib/x86_64-linux-gnu/libzstd.so.1 /usr/lib/x86_64-linux-gnu/libzstd.so.1

# Copy default database initialization (can be overridden by bind mount)
COPY --from=builder /tmp/pgdata-final/ /

# Environment variables
ENV PATH="/usr/local/bin:/usr/local/sbin:${PATH}"
ENV LD_LIBRARY_PATH="/usr/local/lib"
ENV PGDATA="/var/lib/postgresql/data"
ENV POSTGRES_USER="postgres"
ENV POSTGRES_PASSWORD="postgres"
ENV POSTGRES_DB="postgres"

# Switch to app user
USER ${APP_UID}:${APP_GID}

# Expose PostgreSQL port
EXPOSE 5432

# Labels
LABEL org.opencontainers.image.title="Distroless PostgreSQL"
LABEL org.opencontainers.image.description="Minimal distroless PostgreSQL image"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.source="https://github.com/cougz/docker-distroless"

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD ["/usr/local/bin/pg_isready", "-U", "postgres", "-d", "postgres"]

ENTRYPOINT ["/usr/local/bin/postgres"]
CMD ["-D", "/var/lib/postgresql/data", "-c", "listen_addresses=*"]