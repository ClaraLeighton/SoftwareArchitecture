#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Per-configuration Docker metrics watcher (Assignment 4, Load Test section).
#
# Watches `docker stats` AND the number of threads per container, sampling
# once every second, and appends the readings to a plain-text log per
# configuration (profile):
#
#   loadtest/results/<config>/metrics/docker_stats.txt   (CPU %, memory, PIDs)
#   loadtest/results/<config>/metrics/threads.txt        (threads per container)
#
# Usage:
#   watch_metrics.sh <config> [seconds]      run while that compose profile is up
#   watch_metrics.sh all [seconds]           same, sequentially for base proxy full scale
#   watch_metrics.sh <config> 0              run until Ctrl-C
#
# Examples:
#   docker compose --profile scale up -d
#   loadtest/watch_metrics.sh scale 60        # sample for 60 seconds
#   loadtest/watch_metrics.sh all 30          # 30s per profile, one .txt each
# ---------------------------------------------------------------------------
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  echo "usage: $0 <config> [seconds]   |   $0 all [seconds]"
  exit 1
}

CONFIG="${1:-}"; [ -z "$CONFIG" ] && usage
DURATION="${2:-0}"

# `all` = loop over every deployment profile.
if [ "$CONFIG" = "all" ]; then
  for cfg in base proxy full scale; do
    echo ">>> watching configuration: ${cfg} (${3:-until Ctrl-C})"
    "$0" "$cfg" "${3:-${DURATION}}"
  done
  exit 0
fi

[ -n "${DURATION}" ] && ! [[ "${DURATION}" =~ ^[0-9]+$ ]] && usage

OUT_DIR="loadtest/results/${CONFIG}/metrics"
mkdir -p "$OUT_DIR"
STATS="$OUT_DIR/docker_stats.txt"
THREADS="$OUT_DIR/threads.txt"

# Header row (the log is append-friendly for later plotting).
printf 'timestamp|container|cpu_percent|mem_usage|mem_limit|processes\n' > "$STATS"
printf 'timestamp|container|threads\n' > "$THREADS"

echo "> sampling docker stats + threads every second"
echo "> writing to ${STATS} and ${THREADS}"
echo "> press Ctrl-C to stop (or it stops automatically after ${DURATION}s)"

START="$(date +%s)"
trap 'echo ""; echo "stopped. see: ${STATS}"; exit 0' INT

while true; do
  TS="$(date +%s.%N)"

  # CPU %, memory (used/limit) and number of processes per container.
  docker stats --no-stream --format '{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}|{{.PIDs}}' 2>/dev/null |
    while IFS='|' read -r name cpu mem pids; do
      mem_used="${mem% / *}"; mem_limit="${mem#* / }"
      printf '%s|%s|%s|%s|%s|%s\n' "$TS" "$name" "$cpu" "$mem_used" "$mem_limit" "$pids" >> "$STATS"
    done

  # Thread count per container = sum of kernel task dirs under each PID.
  for c in $(docker ps --format '{{.Names}}' 2>/dev/null); do
    T="$(
      docker exec "$c" sh -c \
        'n=0; for p in /proc/[0-9]*; do [ -d "$p/task" ] && n=$(( n + $(ls "$p/task" | wc -l) )); done; echo $n' \
        2>/dev/null || echo 0
    )"
    printf '%s|%s|%s\n' "$TS" "$c" "$T" >> "$THREADS"
  done

  if [ "${DURATION}" -gt 0 ] 2>/dev/null; then
    ELAPSED=$(( $(date +%s) - START ))
    if [ "$ELAPSED" -ge "$DURATION" ]; then
      echo "> finished (${DURATION}s elapsed)"
      echo "> logs: ${STATS}  and  ${THREADS}"
      exit 0
    fi
  fi

  sleep 1
done