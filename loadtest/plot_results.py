#!/usr/bin/env python3
"""Plot the Assignment 4 load-test results.

Reads the outputs produced by loadtest/run.sh (or watch_metrics.sh) and
renders publication-friendly PNG graphs:

  1. throughput.png          requests/s per endpoint vs request count
                             (one panel per results directory)
  2. latency.png             latency p50/p95/p99 vs request count, faceted
                             per endpoint (compose vs k8s compared)
  3. latencies_dist.png      per-request latency distribution (CDF) at the
                             largest size, per endpoint / results directory
  4. metrics_<dir>.png       CPU %, memory and thread count per container
                             over time (from the metrics CSVs/txts)

Usage:
  plot_results.py [--dirs compose_scale k8s_scale] [--out loadtest/results/plots]
                  [--max-containers 8] [--show]
"""

import argparse
import csv
import os
import re
import sys
from collections import defaultdict

import numpy as np

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

ENDPOINT_LABELS = {
    "static": "Static asset (edge)",
    "top_selling": "Aggregation (DB+cache)",
    "search": "Search window (OpenSearch)",
    "book_detail": "Cheap dynamic read (DB)",
}

SIZES = [1, 10, 100, 1000, 5000]

ENDPOINT_COLORS = {
    "static": "#1f77b4",
    "top_selling": "#ff7f0e",
    "search": "#2ca02c",
    "book_detail": "#d62728",
}

options = None


def results_dir(label):
    return os.path.join(options.dir_root, label)


def parse_summary(path):
    """Read a *.summary.txt into a dict of labelled scalar stats."""
    stats = {}
    summary = open(path).read()
    for label in ["requests/s", "ok (<400)", "failed/timeout", "elapsed (s)",
                  "latency mean", "latency median", "latency p90",
                  "latency p95", "latency p99", "latency max"]:
        m = re.search(r"^" + re.escape(label) + r":\s*([0-9.]+)", summary, re.M)
        if m:
            stats[label] = float(m.group(1))
    return stats


def mem_to_mib(value):
    """'23.75MiB / 7.406GiB' or '902.1MiB' -> float MiB."""
    if not value:
        return float("nan")
    number = re.match(r"([0-9.]+)([KMGT])iB", value)
    if number:
        n, unit = float(number.group(1)), number.group(2)
        return n * {"": 1, "K": 1e-3, "M": 1, "G": 1e3, "T": 1e6}[unit]
    return float("nan")


def collect(dirpath):
    """Index every *.summary.txt as {endpoint: {size: stats}}.

    Each endpoint's summaries live in a sub-directory next to its latencies
    and codes CSVs (loadtest/run.sh layout).
    """
    data = defaultdict(dict)
    for root, _dirs, files in os.walk(dirpath):
        for fname in files:
            if not fname.endswith(".summary.txt"):
                continue
            m = re.match(r"(.+)_(\d+)\.summary\.txt$", fname)
            if not m:
                continue
            endpoint, size = m.group(1), int(m.group(2))
            data[endpoint][size] = parse_summary(os.path.join(root, fname))
    return data


def load_latencies(latencies_path, ok_only=True):
    """Per-request latencies (seconds) from a latencies.csv."""
    seconds = []
    try:
        with open(latencies_path) as f:
            for row in csv.DictReader(f):
                if ok_only and int(row["status"]) >= 400:
                    continue
                seconds.append(float(row["seconds"]))
    except (FileNotFoundError, ValueError, KeyError):
        pass
    return np.array(seconds) * 1000.0  # ms


def read_metrics(dirpath):
    """Load the per-second metrics log(s) (CSV or watcher TXT)."""
    stats_path = os.path.join(dirpath, "metrics", "docker_stats.csv")
    if not os.path.exists(stats_path):
        stats_path = os.path.join(dirpath, "metrics", "docker_stats.txt")
    threads_path = None
    for p in ("threads.csv", "threads.txt"):
        cand = os.path.join(dirpath, "metrics", p)
        if os.path.exists(cand):
            threads_path = cand
            break
    if not os.path.exists(stats_path):
        return None

    containers = defaultdict(lambda: {"t": [], "cpu": [], "mem_mib": [],
                                      "pids": []})
    with open(stats_path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("timestamp"):
                continue
            parts = line.split("|")
            if len(parts) < 5:
                continue
            ts, name, cpu, mem, pids = parts[0], parts[1], parts[2], parts[3], parts[4]
            if " / " in mem:
                mem = mem.split(" / ")[0]
            row = containers[name]
            row["t"].append(float(ts))
            row["cpu"].append(float(cpu.rstrip("%")))
            row["mem_mib"].append(mem_to_mib(mem))
            row["pids"].append(int(pids))

    threads = None
    if threads_path:
        threads = defaultdict(lambda: {"t": [], "threads": []})
        with open(threads_path) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("timestamp"):
                    continue
                parts = line.split("|")
                # layout: timestamp|container|threads|count
                # (the watcher .txt uses timestamp|container|count)
                if len(parts) >= 4 and parts[2] == "threads":
                    threads[parts[1]]["t"].append(float(parts[0]))
                    threads[parts[1]]["threads"].append(int(parts[3]))
                elif len(parts) == 3:
                    threads[parts[1]]["t"].append(float(parts[0]))
                    threads[parts[1]]["threads"].append(int(parts[2]))

    return {"containers": containers, "threads": threads}


def plot_throughput(sets, out_path):
    ncols = len(sets)
    fig, axes = plt.subplots(1, ncols, figsize=(6.5 * ncols, 5.2), sharey=True)
    if ncols == 1:
        axes = [axes]
    for ax, (label, data) in zip(axes, sets.items()):
        for endpoint, size_map in data.items():
            sizes = sorted(size_map)
            rps = [size_map[s]["requests/s"] for s in sizes]
            ax.plot(sizes, rps, marker="o", ms=4, lw=1.8,
                    label=ENDPOINT_LABELS.get(endpoint, endpoint),
                    color=ENDPOINT_COLORS.get(endpoint, None))
        ax.set_xscale("log", base=10)
        ax.set_xticks(SIZES)
        ax.set_xticklabels([str(s) for s in SIZES])
        ax.grid(True, which="both", alpha=0.25)
        ax.set_title(label)
        ax.set_xlabel("Requests issued")
        ax.legend(fontsize=8, loc="upper left")
    axes[0].set_ylabel("Requests/second")
    fig.suptitle("Throughput per endpoint vs request count", fontsize=13)
    fig.tight_layout()
    fig.savefig(out_path, dpi=150)
    plt.close(fig)
    print("wrote", out_path)


def plot_latency(sets, out_path):
    fig, axes = plt.subplots(2, 2, figsize=(12, 8))
    flat = [a for row in axes for a in row]
    for i, endpoint in enumerate(ENDPOINT_LABELS):
        ax = flat[i]
        for label, data in sets.items():
            size_map = data.get(endpoint, {})
            sizes = sorted(size_map)
            if not sizes:
                continue
            p50 = [size_map[s]["latency median"] for s in sizes]
            p95 = [size_map[s]["latency p95"] for s in sizes]
            p99 = [size_map[s]["latency p99"] for s in sizes]
            ax.plot(sizes, p50, marker=".", ms=5, lw=1.4, ls=":",
                    label=f"{label} p50", color=None if len(sets) > 1 else "#1f77b4")
            ax.plot(sizes, p95, marker="o", ms=5, lw=1.8,
                    label=f"{label} p95")
            ax.plot(sizes, p99, marker="^", ms=5, lw=1.4, ls="--",
                    label=f"{label} p99")
        ax.set_xscale("log", base=10)
        ax.set_xticks(SIZES)
        ax.set_xticklabels([str(s) for s in SIZES])
        ax.grid(True, which="both", alpha=0.25)
        ax.set_title(ENDPOINT_LABELS[endpoint], fontsize=10)
        ax.set_xlabel("Requests issued")
        ax.set_ylabel("Latency (ms)")
        ax.legend(fontsize=6.5, ncol=2)
    fig.suptitle("Latency p50 / p95 / p99 per endpoint", fontsize=13)
    fig.tight_layout()
    fig.savefig(out_path, dpi=150)
    plt.close(fig)
    print("wrote", out_path)


def plot_latency_distribution(sets, out_path):
    nrows, ncols = len(sets), len(ENDPOINT_LABELS)
    fig, axes = plt.subplots(nrows, ncols, figsize=(15, 4.2 * nrows),
                             squeeze=False)
    for r, (label, data) in enumerate(sets.items()):
        for c, endpoint in enumerate(ENDPOINT_LABELS):
            ax = axes[r][c]
            if not data.get(endpoint):
                ax.set_title(f"{label} — no data")
                continue
            size = max(data[endpoint])
            lat_path = os.path.join(results_dir(label), endpoint,
                                    f"{endpoint}_{size}.latencies.csv")
            seconds = load_latencies(lat_path)
            if seconds.size:
                x = np.sort(seconds)
                y = np.linspace(0, 100, x.size)
                ax.plot(x, y, lw=1.6,
                        color=ENDPOINT_COLORS.get(endpoint, None))
                ax.set_xlabel("Latency (ms)")
                ax.set_ylabel("Cumulative %")
                ax.set_title(f"{label} · {endpoint} · n={size}", fontsize=9)
            else:
                ax.set_title(f"{label} · {endpoint} · no latencies")
            ax.grid(True, alpha=0.25)
    fig.suptitle("Per-request latency distribution (CDF) at the largest size",
                 fontsize=13)
    fig.tight_layout()
    fig.savefig(out_path, dpi=150)
    plt.close(fig)
    print("wrote", out_path)


def plot_metrics(sets, out_path, max_containers=8):
    nrows = len(sets)
    fig, axes = plt.subplots(nrows, 3, figsize=(17, 4.6 * nrows), squeeze=False)
    for r, (label, data) in enumerate(sets.items()):
        metrics = read_metrics(results_dir(label))
        if not metrics:
            for c in range(3):
                axes[r][c].axis("off")
            axes[r][0].set_title(f"{label} — no metrics captured", fontsize=9)
            continue
        containers = metrics["containers"]
        # Keep only the busiest containers so the legend stays readable.
        ranked = sorted(containers, key=lambda n: max(containers[n]["cpu"]),
                        reverse=True)[:max_containers]
        for c, (metric, unit) in enumerate([
                ("cpu", "CPU %"), ("mem_mib", "Memory (MiB)"), ("pids", "Processes")]):
            ax = axes[r][c]
            for name in ranked:
                row = containers[name]
                ax.plot(row["t"], row[metric], lw=1.3, label=name)
            ax.set_title(f"{label} — {unit}")
            ax.set_xlabel("Time (unix seconds)")
            ax.set_ylabel(unit)
            ax.grid(True, alpha=0.25)
        metrics_threads = metrics.get("threads")
        if metrics_threads:
            ax = axes[r][2]
            for name in ranked:
                row = metrics_threads.get(name)
                if row and row["t"]:
                    ax.plot(row["t"], row["threads"], lw=1.3, label=name)
            ax.set_title(f"{label} — Threads")
            ax.set_ylabel("Threads")
        axes[r][2].legend(fontsize=6, loc="upper right")
    fig.suptitle("Per-container runtime metrics (sampled @1 s)", fontsize=13)
    fig.tight_layout()
    fig.savefig(out_path, dpi=150)
    plt.close(fig)
    print("wrote", out_path)


def main():
    global options
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dirs", nargs="+", default=["compose_scale", "k8s_scale"],
                        help="results sub-directories to compare")
    parser.add_argument("--dir-root", default="loadtest/results",
                        help="parent directory holding the results")
    parser.add_argument("--out", default="loadtest/results/plots",
                        help="output directory for the PNGs")
    parser.add_argument("--max-containers", type=int, default=8)
    parser.add_argument("--show", action="store_true", help="open the figures")
    args = parser.parse_args()
    options = args

    sets = {}
    for label in args.dirs:
        dirpath = os.path.join(args.dir_root, label)
        if not os.path.isdir(dirpath):
            print(f"! skipping {label}: no such directory", file=sys.stderr)
            continue
        sets[label] = collect(dirpath)
        if not sets[label]:
            print(f"! skipping {label}: no *.summary.txt files", file=sys.stderr)
            sets.pop(label, None)

    if not sets:
        sys.exit("nothing to plot")

    os.makedirs(args.out, exist_ok=True)
    if args.show:
        matplotlib.use("TkAgg")

    plot_throughput(sets, os.path.join(args.out, "throughput.png"))
    plot_latency(sets, os.path.join(args.out, "latency.png"))
    plot_latency_distribution(sets, os.path.join(args.out, "latencies_dist.png"))
    plot_metrics(sets, os.path.join(args.out, "metrics.png"), args.max_containers)

    if args.show:
        plt.show()


if __name__ == "__main__":
    main()