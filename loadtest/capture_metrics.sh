#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Metrics sampler for the load test: CPU %, memory and thread count, per
# running container (and its processes), sampled once per second.
#
# Usage:
#   capture_metrics.sh start <output_dir>
#   capture_metrics.sh stop
# ---------------------------------------------------------------------------
set -u

ACTION="${1:-start}"
OUT_DIR="${2:-loadtest/results/metrics}"

PID_FILE="/tmp/bookreviews_metrics.pid"

if [ "$ACTION" = "stop" ]; then
  if [ -f "$PID_FILE" ]; then
    kill "$(cat "$PID_FILE")" 2>/dev/null || true
    rm -f "$PID_FILE"
    echo "metrics capture stopped"
  else
    echo "metrics capture not running"
  fi
  exit 0
fi

if [ -f "$PID_FILE" ]; then
  echo "metrics capture already running (pid $(cat "$PID_FILE"))"
  exit 1
fi

mkdir -p "$OUT_DIR"
STATS="${OUT_DIR}/docker_stats.csv"
THREADS="${OUT_DIR}/threads.csv"
: > "$STATS"
: > "$THREADS"

(
  while true; do
    TS="$(date +%s.%N)"

    docker stats --no-stream --format '{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}|{{.PIDs}}' 2>/dev/null |
      while IFS='|' read -r name cpu mem pids; do
        printf '%s|%s|%s|%s|%s\n' "$TS" "$name" "$cpu" "$mem" "$pids" >> "$STATS"
      done

    for c in $(docker ps --format '{{.Names}}' 2>/dev/null); do
      # Total threads in the container: count kernel task dirs across its PIDs.
      T="$(
        docker exec "$c" sh -c \
          'n=0; for p in /proc/[0-9]*; do [ -d "$p/task" ] && n=$(( n + $(ls "$p/task" | wc -l) )); done; echo $n' \
          2>/dev/null || echo 0
      )"
      printf '%s|%s|threads|%s\n' "$TS" "$c" "$T" >> "$THREADS"
    done

    sleep 1
  done
) >/dev/null 2>&1 &

echo $! > "$PID_FILE"
echo "metrics capture started (pid $(cat "$PID_FILE")) -> ${OUT_DIR}"