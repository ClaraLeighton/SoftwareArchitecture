#!/usr/bin/env python3
"""
Minimal concurrent HTTP load generator for the BookReviews load test.

Measures per-request latency and status codes for a single endpoint, then
writes a summary plus two CSVs (latencies and status-code counts).

Usage:
    python3 load_test.py <url> -n 5000 -c 50 -o results/top_selling

Output (prefix = -o value):
    <prefix>.summary.txt   textual summary incl. percentiles
    <prefix>.latencies.csv uid,status,bytes,seconds
    <prefix>.codes.csv     HTTP status : count
"""
import argparse
import csv
import ssl
import statistics
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

_lock = threading.Lock()
_pending = 0


def build_opener(url, timeout):
    if not url.startswith("https"):
        raise NotImplementedError
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    return urllib.request.build_opener(urllib.request.HTTPSHandler(context=ctx))


def main():
    parser = argparse.ArgumentParser(description="BookReviews load generator")
    parser.add_argument("url")
    parser.add_argument("-n", "--requests", type=int, default=100)
    parser.add_argument("-c", "--concurrency", type=int, default=20)
    parser.add_argument("-o", "--output", default=None)
    parser.add_argument("--timeout", type=float, default=60.0)
    # Works without /etc/hosts: point the request at 127.0.0.1 while keeping
    # the real Host header (used with self-signed TLS against the edge).
    parser.add_argument("--host", default=None)
    args = parser.parse_args()

    url = args.url
    if args.host:
        parts = urllib.parse.urlsplit(args.url)
        port = f":{parts.port}" if parts.port else ""
        url = urllib.parse.urlunsplit(
            (parts.scheme, f"127.0.0.1{port}", parts.path or "/", parts.query, "")
        )

    results = []
    errors = []

    start = time.perf_counter()
    elapsed = lambda: time.perf_counter() - start

    def worker():
        global _pending
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        opener = urllib.request.build_opener(urllib.request.HTTPSHandler(context=ctx)) if url.startswith("https") else urllib.request.build_opener()
        while True:
            with _lock:
                if _pending <= 0:
                    break
                _pending -= 1
            t0 = time.perf_counter()
            try:
                headers = {"Host": args.host} if args.host else {}
                req = urllib.request.Request(url, headers=headers)
                with opener.open(req, timeout=args.timeout) as resp:
                    body = resp.read()
                    dt = time.perf_counter() - t0
                    results.append((t0, resp.status, len(body), dt))
            except urllib.error.HTTPError as e:
                dt = time.perf_counter() - t0
                _ = e.read()
                results.append((t0, e.code, 0, dt))
            except Exception as e:  # noqa: BLE001
                dt = time.perf_counter() - t0
                errors.append((t0, repr(e), dt))

    global _pending
    _pending = args.requests
    threads = [threading.Thread(target=worker, daemon=True) for _ in range(args.concurrency)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()

    total_s = elapsed()
    results.sort()
    latencies = [r[3] for r in results]
    codes = {}
    for r in results:
        codes[r[1]] = codes.get(r[1], 0) + 1
    ok = sum(1 for r in results if r[1] < 400)

    lines = []
    lines.append("== Load test: %s ==" % args.url)
    lines.append("requests:      %d" % args.requests)
    lines.append("concurrency:   %d" % args.concurrency)
    lines.append("elapsed (s):   %.3f" % total_s)
    lines.append("requests/s:    %.2f" % (args.requests / total_s))
    lines.append("completed:     %d" % len(results))
    lines.append("ok (<400):     %d" % ok)
    lines.append("failed/timeout:%d" % len(errors))
    lines.append("bytes total:   %d" % sum(r[2] for r in results))
    if latencies:
        latencies.sort()
        lines.append("latency mean:  %.3f ms" % (statistics.mean(latencies) * 1000))
        lines.append("latency median:%.3f ms" % (statistics.median(latencies) * 1000))
        for label, ndx in [("p90", 90), ("p95", 95), ("p99", 99)]:
            i = min(len(latencies) - 1, len(latencies) * ndx // 100)
            lines.append("latency %s:    %.3f ms" % (label, latencies[i] * 1000))
        lines.append("latency max:   %.3f ms" % (max(latencies) * 1000))
    lines.append("status codes:  %s" % (", ".join("%d=%d" % kv for kv in sorted(codes.items())) or "none"))

    out = args.output
    if out:
        with open(out + ".summary.txt", "w") as f:
            f.write("\n".join(lines) + "\n")
        with open(out + ".latencies.csv", "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["uid", "status", "bytes", "seconds"])
            for i, r in enumerate(results):
                w.writerow([i, r[1], r[2], "%.6f" % r[3]])
        with open(out + ".codes.csv", "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["status", "count"])
            for kv in sorted(codes.items()):
                w.writerow(kv)
    print("\n".join(lines))


if __name__ == "__main__":
    main()