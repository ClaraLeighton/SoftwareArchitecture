#!/usr/bin/env bash
set -euo pipefail

# Populates the book_reviews database inside the MongoDB container.
# Run from the repository root: ./mongo-seed/seed.sh

docker compose exec -T mongodb mongosh --quiet \
  "mongodb://localhost:27017/book_reviews" \
  --file /seed/seed.js
