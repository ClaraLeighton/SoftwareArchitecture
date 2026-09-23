#!/bin/sh
# ---------------------------------------------------------------------------
# Generates a self-signed certificate for the edge (app.localhost).
# Idempotent: existing certs are left untouched, so restarts do not rotate them.
# ---------------------------------------------------------------------------
set -eu

CERT_DIR=/etc/nginx/certs
CERT="$CERT_DIR/server.crt"
KEY="$CERT_DIR/server.key"

if [ -f "$CERT" ] && [ -f "$KEY" ]; then
  echo "edge: certificate already present, keeping it"
  exit 0
fi

mkdir -p "$CERT_DIR"

openssl req -x509 -nodes -newkey rsa:2048 -days 825 \
  -keyout "$KEY" \
  -out "$CERT" \
  -subj "/CN=app.localhost" \
  -addext "subjectAltName=DNS:app.localhost,DNS:localhost,IP:127.0.0.1" \
  >/dev/null 2>&1

echo "edge: generated self-signed certificate for app.localhost"