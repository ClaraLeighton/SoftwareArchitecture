# ---------------------------------------------------------------------------
# Edge reverse proxy for BookReviews (Assignment 4).
#
# * TLS termination (self-signed cert generated on first boot by gen-certs.sh)
# * reverse proxy / load balancer toward the app upstream (NGINX_UPSTREAM)
# * static assets and uploads served from the shared volume at /data
#
# The official nginx entrypoint renders templates from /etc/nginx/templates
# into /etc/nginx/conf.d using envsubst, so the upstream can be injected per
# deployment through the NGINX_UPSTREAM environment variable.
# ---------------------------------------------------------------------------
FROM nginx:1.27-alpine

RUN apk add --no-cache openssl

COPY templates/app-edge.conf.template /etc/nginx/templates/app-edge.conf.template
COPY bin/gen-certs.sh /usr/local/bin/gen-certs.sh

RUN chmod +x /usr/local/bin/gen-certs.sh \
    && mkdir -p /etc/nginx/certs /var/cache/nginx/edge \
    && rm -f /etc/nginx/conf.d/default.conf

# The official nginx entrypoint only runs /docker-entrypoint.d/*.sh when the
# container command is `nginx`. The default CMD is left untouched; this script
# generates the self-signed certificate before nginx starts.
COPY bin/gen-certs.sh /docker-entrypoint.d/40-gen-certs.sh
RUN chmod +x /docker-entrypoint.d/40-gen-certs.sh

EXPOSE 80 443