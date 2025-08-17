# Nginx distroless image - rootless friendly
ARG APP_UID=1000
ARG APP_GID=1000
ARG TZ=UTC
ARG VERSION=1.27.3

# Build stage
FROM debian:trixie-slim AS builder

ARG VERSION
ARG APP_UID
ARG APP_GID

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        wget \
        ca-certificates \
        libssl-dev \
        libpcre2-dev \
        zlib1g-dev \
        binutils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download and build nginx
WORKDIR /tmp
RUN wget -q "http://nginx.org/download/nginx-${VERSION}.tar.gz" -O nginx.tar.gz && \
    tar -xzf nginx.tar.gz && \
    cd nginx-${VERSION} && \
    ./configure \
        --prefix=/usr/local \
        --sbin-path=/usr/local/bin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/tmp/nginx/error.log \
        --http-log-path=/tmp/nginx/access.log \
        --pid-path=/tmp/nginx.pid \
        --lock-path=/tmp/nginx.lock \
        --http-client-body-temp-path=/tmp/nginx/client_temp \
        --http-proxy-temp-path=/tmp/nginx/proxy_temp \
        --http-fastcgi-temp-path=/tmp/nginx/fastcgi_temp \
        --http-uwsgi-temp-path=/tmp/nginx/uwsgi_temp \
        --http-scgi-temp-path=/tmp/nginx/scgi_temp \
        --user=app \
        --group=app \
        --with-http_ssl_module \
        --with-http_realip_module \
        --with-http_addition_module \
        --with-http_sub_module \
        --with-http_gunzip_module \
        --with-http_gzip_static_module \
        --with-http_secure_link_module \
        --with-http_stub_status_module \
        --with-http_auth_request_module \
        --with-threads \
        --with-http_v2_module && \
    make -j$(nproc) && \
    make install && \
    strip /usr/local/bin/nginx

# Create necessary directories
RUN mkdir -p \
        /etc/nginx/conf.d \
        /usr/share/nginx/html \
        /tmp/nginx/client_temp \
        /tmp/nginx/proxy_temp \
        /tmp/nginx/fastcgi_temp \
        /tmp/nginx/uwsgi_temp \
        /tmp/nginx/scgi_temp

# Create nginx configuration for rootless operation (port 8080)
RUN cat > /etc/nginx/nginx.conf << 'EOF'
worker_processes auto;
error_log /tmp/nginx/error.log warn;
pid /tmp/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /tmp/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/rss+xml
        application/atom+xml
        image/svg+xml;

    include /etc/nginx/conf.d/*.conf;

    server {
        listen 8080;
        listen [::]:8080;
        server_name localhost;

        location / {
            root /usr/share/nginx/html;
            index index.html index.htm;
        }

        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }

        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
            root /usr/share/nginx/html;
        }
    }
}
EOF

# Create minimal mime.types
RUN cat > /etc/nginx/mime.types << 'EOF'
types {
    text/html                             html htm shtml;
    text/css                              css;
    text/xml                              xml;
    image/gif                             gif;
    image/jpeg                            jpeg jpg;
    application/javascript                js;
    text/plain                            txt;
    image/png                             png;
    image/svg+xml                         svg svgz;
    application/json                      json;
    application/pdf                       pdf;
    application/zip                       zip;
    font/woff                             woff;
    font/woff2                            woff2;
}
EOF

# Create default error page
RUN cat > /usr/share/nginx/html/50x.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Error</title>
    <style>
        body {
            width: 35em;
            margin: 0 auto;
            font-family: Tahoma, Verdana, Arial, sans-serif;
        }
    </style>
</head>
<body>
<h1>An error occurred.</h1>
<p>Sorry, the page you are looking for is currently unavailable.<br/>
Please try again later.</p>
</body>
</html>
EOF

# Final stage
FROM distroless-base:1.0.0

ARG VERSION
ARG APP_UID
ARG APP_GID

# Copy nginx binary
COPY --from=builder /usr/local/bin/nginx /usr/local/bin/nginx

# Copy nginx configuration
COPY --from=builder /etc/nginx /etc/nginx

# Copy default HTML content
COPY --from=builder /usr/share/nginx/html /usr/share/nginx/html

# Copy runtime libraries for nginx
COPY --from=builder /lib/x86_64-linux-gnu/libssl.so.3 /lib/x86_64-linux-gnu/libssl.so.3
COPY --from=builder /lib/x86_64-linux-gnu/libcrypto.so.3 /lib/x86_64-linux-gnu/libcrypto.so.3
COPY --from=builder /lib/x86_64-linux-gnu/libz.so.1 /lib/x86_64-linux-gnu/libz.so.1
COPY --from=builder /lib/x86_64-linux-gnu/libc.so.6 /lib/x86_64-linux-gnu/libc.so.6
COPY --from=builder /lib/x86_64-linux-gnu/libpthread.so.0 /lib/x86_64-linux-gnu/libpthread.so.0
COPY --from=builder /lib/x86_64-linux-gnu/libpcre2-8.so.0 /lib/x86_64-linux-gnu/libpcre2-8.so.0
COPY --from=builder /lib64/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2

# Switch to app user
USER ${APP_UID}:${APP_GID}

# Expose port 8080 (rootless friendly)
EXPOSE 8080

# Labels
LABEL org.opencontainers.image.title="Distroless Nginx"
LABEL org.opencontainers.image.description="Minimal distroless Nginx image - rootless"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.source="https://github.com/cougz/docker-distroless"

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/usr/local/bin/nginx", "-t"]

ENTRYPOINT ["/usr/local/bin/nginx"]
CMD ["-g", "daemon off;"]