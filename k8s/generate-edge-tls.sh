#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Generates the self-signed TLS certificate for the Nginx edge and creates the
# `nginx-edge-tls` Secret in the cluster (idempotent: re-running just updates).
#
#   ./k8s/generate-edge-tls.sh [namespace]   (default: book-reviews)
# ---------------------------------------------------------------------------
set -euo pipefail

NS="${1:-book-reviews}"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

openssl req -x509 -nodes -newkey rsa:2048 -days 825 \
  -keyout "${TMP}/tls.key" \
  -out "${TMP}/tls.crt" \
  -subj "/CN=app.localhost" \
  -addext "subjectAltName=DNS:app.localhost,DNS:localhost,IP:127.0.0.1" \
  >/dev/null 2>&1

kubectl -n "${NS}" create secret tls nginx-edge-tls \
  --key "${TMP}/tls.key" \
  --cert "${TMP}/tls.crt" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "edge: TLS secret 'nginx-edge-tls' ready in namespace ${NS}"