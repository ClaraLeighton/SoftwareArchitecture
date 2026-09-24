#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Orchestrates the Assignment 4 load test.
#
# Runs 4 endpoints x {1, 10, 100, 1000, 5000} requests inside a 5-minute
# budget, while metrics are captured once per second (CPU %, mem, threads).
#
# Usage:
#   run.sh https://app.localhost single            # proxy/single or scaled
#   run.sh http://localhost:4000   single_node     # deployment 1, no proxy
#
# Endpoints tested (each stresses a different tier):
#   1. static asset      /assets/css/app.css    -> edge / app static serving
#   2. expensive agg     /books/top-selling     -> app CPU + DB + cache
#   3. search window     /books/search?q=novel  -> search engine
#   4. cheap dyn read    /books/<first id>      -> app + DB baseline
# ---------------------------------------------------------------------------
set -euo pipefail

BASE_URL="${1:-https://app.localhost}"
LABEL="${2:-loadtest}"
OUT_ROOT="loadtest/results/${LABEL}"
MAX_SECONDS=${MAX_SECONDS:-300}
# Optional: "app.localhost:443:127.0.0.1" to avoid an /etc/hosts entry
# (used by curl for resolving a first book id; load_test.py rewrites itself).
HOST_ROUTE="${HOST_ROUTE:-}"
PY_HOST_ARGS=()
CURL_RESOLVE=()
# When a route override is set, curl needs a URL whose port matches the
# resolved host:port pair (python's loader rewrites itself + keeps Host).
CURL_BASE="$BASE_URL"
if [ -n "$HOST_ROUTE" ]; then
  PY_HOST_ARGS=(--host "$(echo "$HOST_ROUTE" | cut -d: -f1)")
  HR_HOST="$(echo "$HOST_ROUTE" | cut -d: -f1)"
  HR_PORT="$(echo "$HOST_ROUTE" | cut -d: -f2)"
  CURL_RESOLVE=(--resolve "$HOST_ROUTE")
  CURL_BASE="https://${HR_HOST}:${HR_PORT}"
fi

mkdir -p "${OUT_ROOT}/metrics"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GEN="${SCRIPT_DIR}/load_test.py"

ENDPOINT_STATIC="${STATIC_ASSET_PATH:-/assets/css/app.css}"
ENDPOINT_TOP_SELLING="/books/top-selling"
ENDPOINT_SEARCH="/books/search?q=novel"
ENDPOINT_BOOK_DETAIL="/books/detail"

# Resolve a real book-detail URL from the books index (cheap dynamic read).
echo "> resolving a book id for the detail endpoint..."
FIRST_BOOK="$(
  curl -sk "${CURL_RESOLVE[@]}" "${CURL_BASE}/books" 2>/dev/null \
    | grep -oE '/books/[a-f0-9]{24}' | head -1 || true
)"
if [ -n "$FIRST_BOOK" ]; then
  ENDPOINT_BOOK_DETAIL="${FIRST_BOOK}"
else
  echo "! could not resolve a book id; detail endpoint will 404"
fi

echo ">>> load test against ${BASE_URL} (label: ${LABEL})"
echo ">>> endpoints tested:"
for key in static top_selling search book_detail; do
  case "$key" in
    static) value="$ENDPOINT_STATIC" ;;
    top_selling) value="$ENDPOINT_TOP_SELLING" ;;
    search) value="$ENDPOINT_SEARCH" ;;
    book_detail) value="$ENDPOINT_BOOK_DETAIL" ;;
    *) value="" ;;
  esac
  echo "    ${key}: ${BASE_URL}${value}"
done

echo ">>> starting metrics capture"
"${SCRIPT_DIR}/capture_metrics.sh" start "${OUT_ROOT}/metrics"

BUDGET_START="$(date +%s)"
total=0
for key in static top_selling search book_detail; do
  for n in 1 10 100 1000 5000; do
    elapsed=$(( $(date +%s) - BUDGET_START ))
    if [ "$elapsed" -ge "$MAX_SECONDS" ]; then
      echo "!!! 5-minute budget reached after ${elapsed}s; skipping remaining runs"
      "${SCRIPT_DIR}/capture_metrics.sh" stop
      exit 0
    fi

    c=$n
    if [ "$c" -gt 50 ]; then c=50; fi

    case "$key" in
      static) value="$ENDPOINT_STATIC" ;;
      top_selling) value="$ENDPOINT_TOP_SELLING" ;;
      search) value="$ENDPOINT_SEARCH" ;;
      book_detail) value="$ENDPOINT_BOOK_DETAIL" ;;
      *) value="" ;;
    esac

    SUBDIR="${OUT_ROOT}/${key}"
    mkdir -p "$SUBDIR"
    OUT_PREFIX="${SUBDIR}/${key}_${n}"
    URL="${BASE_URL}${value}"

    echo ""
    echo "== ${key} n=${n} c=${c} : ${URL}"
    python3 "$GEN" "$URL" -n "$n" -c "$c" -o "$OUT_PREFIX" "${PY_HOST_ARGS[@]}" \
      | tee "${OUT_PREFIX}.console.txt"
    total=$(( total + n ))
  done
done

"${SCRIPT_DIR}/capture_metrics.sh" stop
echo ""
echo ">>> done. total requests issued: ${total}"
echo ">>> results under ${OUT_ROOT}/ ; metrics under ${OUT_ROOT}/metrics/"