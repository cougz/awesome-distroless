# Nginx distroless image - rootless friendly
ARG APP_UID=1000
ARG APP_GID=1000
ARG TZ=UTC
ARG VERSION=1.29.1

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
        --error-log-path=/tmp/error.log \
        --http-log-path=/tmp/access.log \
        --pid-path=/tmp/nginx.pid \
        --lock-path=/tmp/nginx.lock \
        --http-client-body-temp-path=/tmp/client_temp \
        --http-proxy-temp-path=/tmp/proxy_temp \
        --http-fastcgi-temp-path=/tmp/fastcgi_temp \
        --http-uwsgi-temp-path=/tmp/uwsgi_temp \
        --http-scgi-temp-path=/tmp/scgi_temp \
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
        --with-http_v2_module \
        --with-http_v3_module && \
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

# Prepare final data directory with correct permissions
RUN mkdir -p /tmp/nginx-final/tmp && \
    chown ${APP_UID}:${APP_GID} /tmp/nginx-final/tmp && \
    chmod 1777 /tmp/nginx-final/tmp && \
    mkdir -p /tmp/nginx-final/tmp/nginx/client_temp \
             /tmp/nginx-final/tmp/nginx/proxy_temp \
             /tmp/nginx-final/tmp/nginx/fastcgi_temp \
             /tmp/nginx-final/tmp/nginx/uwsgi_temp \
             /tmp/nginx-final/tmp/nginx/scgi_temp && \
    chown -R ${APP_UID}:${APP_GID} /tmp/nginx-final

# Generate self-signed ECC SSL certificate and DH params for HTTPS/QUIC
RUN mkdir -p /etc/ssl/nginx && \
    openssl ecparam -genkey -name prime256v1 -out /etc/ssl/nginx/nginx.key && \
    openssl req -new -x509 -key /etc/ssl/nginx/nginx.key -out /etc/ssl/nginx/nginx.crt -days 365 \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" && \
    openssl dhparam -out /etc/ssl/nginx/dhparam.pem 2048 && \
    chown -R ${APP_UID}:${APP_GID} /etc/ssl/nginx && \
    chmod 600 /etc/ssl/nginx/nginx.key && \
    chmod 644 /etc/ssl/nginx/nginx.crt && \
    chmod 644 /etc/ssl/nginx/dhparam.pem

# Create nginx configuration with HTTPS/QUIC support
RUN cat > /etc/nginx/nginx.conf << 'EOF'
worker_processes auto;
error_log stderr warn;
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

    access_log /dev/stdout main;

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
        listen 8443 ssl;
        listen [::]:8443 ssl;
        listen 8443 quic reuseport;
        listen [::]:8443 quic reuseport;
        server_name localhost;
        
        # Enable HTTP/2 and HTTP/3
        http2 on;
        
        # SSL Configuration (ECC Certificate)
        ssl_certificate /etc/ssl/nginx/nginx.crt;
        ssl_certificate_key /etc/ssl/nginx/nginx.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305;
        ssl_prefer_server_ciphers off;
        ssl_ecdh_curve prime256v1;
        
        # QUIC and HTTP/3 headers (same port 8443)
        add_header Alt-Svc 'h3=":8443"; ma=86400';
        add_header QUIC-Status $http3;

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

# Create default pages
RUN cat > /usr/share/nginx/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head><title>Welcome to nginx</title></head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and working.</p>
</body>
</html>
EOF

RUN cat > /usr/share/nginx/html/50x.html << 'EOF'
<!DOCTYPE html>
<html>
<head><title>Error</title></head>
<body>
<h1>An error occurred.</h1>
<p>Sorry, the page you are looking for is currently unavailable.</p>
</body>
</html>
EOF

# Final stage
ARG BASE_IMAGE=distroless-base:1.0.0
FROM ${BASE_IMAGE}

ARG VERSION
ARG APP_UID
ARG APP_GID

# Copy nginx binary
COPY --from=builder /usr/local/bin/nginx /usr/local/bin/nginx

# Copy nginx configuration and SSL certificates
COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder /etc/ssl/nginx /etc/ssl/nginx

# Copy default HTML content
COPY --from=builder /usr/share/nginx/html /usr/share/nginx/html

# Copy nginx temporary directories structure
COPY --from=builder /tmp/nginx-final/ /

# Copy runtime libraries for nginx
COPY --from=builder /lib/x86_64-linux-gnu/libssl.so.3 /lib/x86_64-linux-gnu/libssl.so.3
COPY --from=builder /lib/x86_64-linux-gnu/libcrypto.so.3 /lib/x86_64-linux-gnu/libcrypto.so.3
COPY --from=builder /lib/x86_64-linux-gnu/libz.so.1 /lib/x86_64-linux-gnu/libz.so.1
COPY --from=builder /lib/x86_64-linux-gnu/libc.so.6 /lib/x86_64-linux-gnu/libc.so.6
COPY --from=builder /lib/x86_64-linux-gnu/libpthread.so.0 /lib/x86_64-linux-gnu/libpthread.so.0
COPY --from=builder /lib/x86_64-linux-gnu/libpcre2-8.so.0 /lib/x86_64-linux-gnu/libpcre2-8.so.0
COPY --from=builder /lib/x86_64-linux-gnu/libcrypt.so.1 /lib/x86_64-linux-gnu/libcrypt.so.1
COPY --from=builder /usr/lib/x86_64-linux-gnu/libzstd.so.1 /usr/lib/x86_64-linux-gnu/libzstd.so.1
COPY --from=builder /lib64/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2

# Switch to app user
USER ${APP_UID}:${APP_GID}

# Expose rootless HTTP/HTTPS ports
EXPOSE 8080/tcp 8443/tcp 8443/udp

# Labels
LABEL org.opencontainers.image.title="Distroless Nginx"
LABEL org.opencontainers.image.description="Minimal distroless Nginx image - rootless"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.source="https://github.com/cougz/awesome-distroless"

# Health check - simple curl since we don't have nginx -t access
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["test", "-f", "/tmp/nginx.pid"]

ENTRYPOINT ["/usr/local/bin/nginx"]
CMD ["-g", "daemon off;"]