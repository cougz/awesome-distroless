# Auto-generated Dockerfile for postgres
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
    apt-get install -y --no-install-recommends build-essential bzip2 wget ca-certificates libssl-dev zlib1g-dev binutils bison flex && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ARG TOOL_VERSION=17.5
RUN wget -q "https://ftp.postgresql.org/pub/source/v${TOOL_VERSION}/postgresql-${TOOL_VERSION}.tar.bz2" -O /tmp/postgres.tar.bz2 && \
    cd /tmp && \
    tar -xjf postgres.tar.bz2 && \
    cd postgresql* && \
    ./configure --prefix=/tmp/postgres-install --with-openssl --with-zlib --without-icu --without-readline && \
    make -j$(nproc) && \
    make install && \
    strip /tmp/postgres-install/bin/* || true

# Create app user (UID 1000) and initialize database as that user
RUN useradd -u 1000 -m app && \
    mkdir -p /tmp/pgdata && \
    chown -R 1000:1000 /tmp/pgdata /tmp/postgres-install

# Switch to UID 1000 and initialize database
USER 1000
RUN /tmp/postgres-install/bin/initdb -D /tmp/pgdata -U postgres --auth-local=trust --auth-host=trust && \
    /tmp/postgres-install/bin/postgres -D /tmp/pgdata -p 5433 -F & \
    sleep 5 && \
    /tmp/postgres-install/bin/psql -h localhost -p 5433 -U postgres -c "ALTER USER postgres PASSWORD 'postgres';" && \
    /tmp/postgres-install/bin/pg_ctl stop -D /tmp/pgdata -m fast && \
    sleep 2 && \
    chmod 700 /tmp/pgdata && \
    mkdir -p /tmp/pgdata-final/var/lib/postgresql /tmp/pgdata-final/tmp && \
    cp -a /tmp/pgdata /tmp/pgdata-final/var/lib/postgresql/data && \
    chmod 1777 /tmp/pgdata-final/tmp

# Switch back to root for remaining operations
USER root

# Create PostgreSQL configuration files
RUN echo "listen_addresses = '*'" >> /tmp/pgdata/postgresql.conf && \
    echo "port = 5432" >> /tmp/pgdata/postgresql.conf && \
    echo "max_connections = 100" >> /tmp/pgdata/postgresql.conf && \
    echo "shared_buffers = 128MB" >> /tmp/pgdata/postgresql.conf && \
    echo "log_destination = 'stderr'" >> /tmp/pgdata/postgresql.conf

RUN echo "# TYPE  DATABASE        USER            ADDRESS                 METHOD" > /tmp/pgdata/pg_hba.conf && \
    echo "local   all             all                                     trust" >> /tmp/pgdata/pg_hba.conf && \
    echo "host    all             all             127.0.0.1/32            md5" >> /tmp/pgdata/pg_hba.conf && \
    echo "host    all             all             ::1/128                 md5" >> /tmp/pgdata/pg_hba.conf && \
    echo "host    all             all             0.0.0.0/0               md5" >> /tmp/pgdata/pg_hba.conf

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
COPY --from=base-builder /lib/x86_64-linux-gnu/libm.so.6 /lib/x86_64-linux-gnu/libm.so.6
COPY --from=base-builder /usr/lib/x86_64-linux-gnu/libzstd.so.1 /usr/lib/x86_64-linux-gnu/libzstd.so.1

# Copy PostgreSQL installation and shared libraries
COPY --from=tool-builder /tmp/postgres-install /usr/local/
COPY --from=tool-builder /tmp/postgres-install/lib/libpq.so* /usr/local/lib/

# Copy PostgreSQL data directory with defaults (preserve ownership and permissions)  
COPY --from=tool-builder /tmp/pgdata-final/ /

# Environment
ENV PATH="/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV LD_LIBRARY_PATH="/usr/local/lib"
ENV HOME="/home/app"
ENV USER="app"
ENV TZ="UTC"
ENV SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"
ENV PGDATA="/var/lib/postgresql/data"

WORKDIR /home/app
USER 1000:1000

# Expose PostgreSQL port
EXPOSE 5432

# Labels
LABEL distroless.tool="postgres"
LABEL distroless.defaults="user=postgres,password=postgres,database=postgres"
LABEL org.opencontainers.image.description="Distroless PostgreSQL with defaults (postgres/postgres/postgres)"
LABEL org.opencontainers.image.title="Distroless PostgreSQL"
LABEL org.opencontainers.image.authors="cougz"
LABEL org.opencontainers.image.source="https://github.com/cougz/docker-distroless"
LABEL org.opencontainers.image.base.name="scratch"

# Start PostgreSQL directly
ENTRYPOINT ["/usr/local/bin/postgres"]
CMD ["-D", "/var/lib/postgresql/data"]