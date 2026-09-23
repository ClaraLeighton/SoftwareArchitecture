# Assignment 4 — Edge & Scale: Step-by-Step Testing Guide

This guide walks through every deliverable of Assignment 4 for the BookReviews
app **as actually verified on this machine**:

1. Reverse proxy (Nginx, assigned: **Group 1**) with TLS termination + static
   asset serving at the edge.
2. Configurable image uploads (book covers / author photos) and a
   `SERVE_STATIC_ASSETS` flag.
3. Stateless scaling: 3 app instances behind an Nginx load balancer, sharing
   MongoDB / Redis / OpenSearch / a shared uploads volume.
4. Four Docker Compose topologies, one Kubernetes deployment, and a load test
   with metrics capture across {1, 10, 100, 1000, 5000} requests on 4 endpoints.

---

## 0. Prerequisites

- Docker with Compose v2 (`docker compose`; `docker buildx` NOT required).
- `mise` with Elixir 1.17.3 / OTP 26 (the pinned toolchain in `mise.toml`).
  System-wide `mix` (1.12.2) is too old:
  ```bash
  mise x -- mix test            # always run tests through mise
  ```
- **k3d** + `kubectl` (for the Kubernetes section).
- Python 3 (stdlib only — no `ab` needed for the load test).

### 0.1 Point `app.localhost` at localhost

```bash
echo "127.0.0.1 app.localhost" | sudo tee -a /etc/hosts
```

All proxy deployments are reachable at `https://app.localhost` with a
self-signed certificate (accept the warning in the browser, or use
`curl -k`).

### 0.2 Build the application and edge images

```bash
docker build -t book_reviews/app:4.0.0 .
docker build -t book_reviews/nginx:4.0.0 ./nginx
```

### 0.3 Port layout

| Port   | Owner                                             |
|--------|---------------------------------------------------|
| 4000   | app (deployment 1 only)                           |
| 80/443 | Nginx edge (deployments 2–4)                      |
| 27017  | MongoDB (all deployments)                         |
| 6379   | Redis cache (full & scale)                        |
| 9200   | OpenSearch (full & scale)                         |

Each deployment owns a distinct Compose project + named volumes, so switching
is just `down` + `up`; the only constraint is the shared host ports above.

---

## 1. Deployment 1 — Application + Database (no proxy)

```bash
docker compose -f docker-compose.yml up -d --build
```

Checks:

```bash
# App serves everything, including its own static assets
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:4000/            # 200
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:4000/assets/css/app.css   # 200
curl -s http://localhost:4000/api/features
# {"serve_static":true,"uploads_path":".../priv/static/uploads",...}  (STATIC_DIR null)
```

Uploads live in the app's own `priv/static/uploads` by default (no shared
volume) — write a file and fetch it back:

```bash
docker exec book_reviews_app sh -c \
  'mkdir -p /app/lib/book_reviews-0.1.0/priv/static/uploads/covers \
   && echo coverbytes > /app/lib/book_reviews-0.1.0/priv/static/uploads/covers/test.jpg'
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:4000/uploads/covers/test.jpg   # 200
```

Tear down: `docker compose -f docker-compose.yml down`

---

## 2. Deployment 2 — Reverse Proxy (TLS + static at the edge)

```bash
docker compose -f docker-compose.proxy.yml up -d --build
```

Verifies that the **Nginx edge** terminates TLS and serves the compiled
static assets + uploads directly from the shared volume (`/data`), while the
app stays HTTP-only behind it.

```bash
# Edge: TLS termination + health check + redirect
curl -sk --resolve app.localhost:443:127.0.0.1 -o /dev/null -w '%{http_code}\n' \
  https://app.localhost/                                    # 200
curl -s  http://localhost/healthz                           # ok  (plain HTTP allowed)
curl -sI http://localhost/ | grep -i location               # 301 https://app.localhost

# Static assets served by nginx from /data/static (immutable caching)
curl -skI https://app.localhost/assets/css/app.css | grep -i 'cache-control'
# cache-control: public, max-age=31536000, immutable

# App no longer serves static: SERVE_STATIC_ASSETS=false and the plug is off
curl -sk https://app.localhost/api/features
# {"serve_static":false,"uploads_path":"/data/uploads","static_publish_dir":"/data/static",...}

# Uploads written to the shared volume are served by the edge
docker exec book_reviews_app_proxy sh -c \
  'mkdir -p /data/uploads/covers && echo edge > /data/uploads/covers/e.jpg'
curl -sk -w ' -> %{http_code}\n' https://app.localhost/uploads/covers/e.jpg   # 200
```

Tear down: `docker compose -f docker-compose.proxy.yml down`

---

## 3. Deployment 3 — Proxy + Cache + Search (full single instance)

```bash
docker compose -f docker-compose.proxy-full.yml up -d --build
```

Adds Redis and OpenSearch behind the same edge (carried over from Assignment 3).

```bash
curl -sk https://app.localhost/api/features
# {"cache_enabled":true,"cache_backend":"Redis","search_enabled":true,
#  "search_backend":"OpenSearch","serve_static":false,
#  "uploads_path":"/data/uploads","static_publish_dir":"/data/static"}

curl -sk -o /dev/null -w '%{http_code}\n' 'https://app.localhost/books/top-selling'   # 200
curl -sk -o /dev/null -w '%{http_code}\n' 'https://app.localhost/books/search?q=novel' # 200
```

Tear down: `docker compose -f docker-compose.proxy-full.yml down`

---

## 4. Deployment 4 — Scaled (3 app instances + load balancer + cache + search)

```bash
docker compose -f docker-compose.scale.yml up -d --build
```

Three identical, stateless instances (`app1`, `app2`, `app3`) behind an Nginx
`least_conn` load balancer, all sharing MongoDB / Redis / OpenSearch and the
`/data` volume. Requests are spread across the instances by the `book-reviews`
upstream and every instance can serve any request.

```bash
docker compose -f docker-compose.scale.yml ps
# 3 app instances + nginx + mongodb + cache + search, all "Up"

# Features identical on every instance
curl -sk https://app.localhost/api/features

# Failover: take instance 1 down — the site keeps working
docker stop book_reviews_app1_scale
curl -sk -o /dev/null -w '%{http_code}\n' https://app.localhost/           # 200
curl -sk -o /dev/null -w '%{http_code}\n' https://app.localhost/books/top-selling  # 200
docker start book_reviews_app1_scale

# Shared uploads: write on instance 1, read through the edge (any instance)
docker exec book_reviews_app1_scale sh -c \
  'mkdir -p /data/uploads/covers && echo shared > /data/uploads/covers/s.txt'
curl -sk -w ' -> %{http_code}\n' https://app.localhost/uploads/covers/s.txt  # 200
```

Leave this stack running for Section 6 (load test) and the Kubernetes comparison.

Tear down: `docker compose -f docker-compose.scale.yml down`

---

## 5. Kubernetes deployment (k3d)

These manifests are applied and verified against a local k3d cluster:

| Manifest                    | Purpose                                        |
|-----------------------------|------------------------------------------------|
| `k8s/00-namespace.yaml`     | `book-reviews` namespace                       |
| `k8s/10-configmap.yaml`     | env incl. `SERVE_STATIC_ASSETS=false`, uploads |
| `k8s/11-secret.yaml`        | `SECRET_KEY_BASE`                              |
| `k8s/12-mongo-seed-configmap.yaml` | MongoDB seed                              |
| `k8s/20-mongodb.yaml`       | MongoDB + PVC                                  |
| `k8s/21-app.yaml`           | app **replicas: 3**, `/data` PVC mount         |
| `k8s/22-cache.yaml`, `23-search.yaml` | Redis / OpenSearch                 |
| `k8s/24-uploads-pvc.yaml`   | shared uploads/static PVC (RWO — single-node)  |
| `k8s/30-edge.yaml`          | Nginx edge Deployment + **NodePort** Service   |
| `k8s/31-edge-configmap.yaml`| full nginx.conf for the cluster                |
| `k8s/generate-edge-tls.sh`  | creates the `nginx-edge-tls` Secret            |

### 5.1 Create the cluster with a local registry

On k3s 1.35 / containerd v2, `k3d image import` can leave images invisible to
the CRI (`ctr` lists them, `kubelet` still tries `docker.io`). The robust path
is a k3d-managed registry:

```bash
k3d cluster delete sa-a4
k3d registry create a4-registry --port 5111
k3d cluster create sa-a4 --agents 1 --servers 1 \
  --registry-use k3d-a4-registry:5111 \
  -p "30080:30080@server:0" -p "30443:30443@server:0" --wait
```

### 5.2 Push the images

```bash
for img in book_reviews/app:4.0.0 book_reviews/nginx:4.0.0 mongo:7 \
           redis:7-alpine opensearchproject/opensearch:2 busybox:1.36; do
  docker tag "$img" "localhost:5111/$img"
  docker push "localhost:5111/$img"
done
```

(The k3d-managed registry is already wired into every node as a mirror for the
`k3d-a4-registry:5000` hostname — no extra registries.yaml needed.)

### 5.3 Apply everything

```bash
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/11-secret.yaml -f k8s/10-configmap.yaml -f k8s/12-mongo-seed-configmap.yaml
./k8s/generate-edge-tls.sh                     # idempotent Secret creation
kubectl apply -f k8s/20-mongodb.yaml -f k8s/21-app.yaml \
  -f k8s/22-cache.yaml -f k8s/23-search.yaml \
  -f k8s/24-uploads-pvc.yaml -f k8s/30-edge.yaml -f k8s/31-edge-configmap.yaml

# Pull the committed image refs from the local registry
kubectl -n book-reviews set image deployment/book-reviews-app \
  app=k3d-a4-registry:5000/book_reviews/app:4.0.0
kubectl -n book-reviews set image deployment/book-reviews-edge \
  nginx=k3d-a4-registry:5000/book_reviews/nginx:4.0.0

kubectl -n book-reviews rollout status deploy/book-reviews-app deploy/book-reviews-edge
```

### 5.4 Verify

```bash
kubectl -n book-reviews get pods            # 3 app replicas, edge, db, cache, search Running

# Edge health + TLS (NodePort 30080/30443)
curl -s http://localhost:30080/healthz                          # ok
curl -sk --resolve app.localhost:30443:127.0.0.1 -o /dev/null -w '%{http_code}\n' \
  https://app.localhost:30443/                                  # 200
curl -sk --resolve app.localhost:30443:127.0.0.1 https://app.localhost:30443/api/features
curl -sk --resolve app.localhost:30443:127.0.0.1 -o /dev/null -w '%{http_code}\n' \
  https://app.localhost:30443/assets/css/app.css                # 200 (edge disk)

# Shared PVC uploads work through the edge
POD=$(kubectl -n book-reviews get pod -l component=web -o jsonpath='{.items[0].metadata.name}')
kubectl -n book-reviews exec "$POD" -- sh -c \
  'mkdir -p /data/uploads/covers && echo k8s > /data/uploads/covers/k.jpg'
curl -sk --resolve app.localhost:30443:127.0.0.1 -w ' -> %{http_code}\n' \
  https://app.localhost:30443/uploads/covers/k.jpg

# Persistence across a pod restart
kubectl -n book-reviews delete pod "$POD" && sleep 20
curl -sk --resolve app.localhost:30443:127.0.0.1 -w ' -> %{http_code}\n' \
  https://app.localhost:30443/uploads/covers/k.jpg              # still 200
```

---

## 6. Load test (1 / 10 / 100 / 1000 / 5000 requests × 4 endpoints)

The tools in `loadtest/` are stdlib-only (no `ab`), capture per-container
CPU % / memory / thread counts once per second, and run the full matrix inside
a 5-minute budget:

| Tool                        | Role                                           |
|-----------------------------|------------------------------------------------|
| `loadtest/load_test.py`     | concurrent HTTP generator (percentiles, CSV)   |
| `loadtest/capture_metrics.sh` | `docker stats` + thread counts, sampled @1s  |
| `loadtest/run.sh`           | orchestrates endpoints × N and metrics        |

```bash
# Scaled Compose deployment (uses port 443):
HOST_ROUTE=app.localhost:443:127.0.0.1 bash loadtest/run.sh https://app.localhost compose_scale

# Kubernetes edge (NodePort 30443):
HOST_ROUTE=app.localhost:30443:127.0.0.1 bash loadtest/run.sh https://app.localhost:30443 k8s_scale
```

Each run issues 24,444 requests across
`/assets/css/app.css`, `/books/top-selling`, `/books/search?q=novel` and a real
book-detail URL (auto-resolved from `/books`). Results land in
`loadtest/results/<label>/<endpoint>/*.summary.txt` (+ latencies/codes CSV) and
metrics in `loadtest/results/<label>/metrics/`.

A shortcut with no `/etc/hosts` entry is the `HOST_ROUTE` env var; it makes
the loader rewrite to `127.0.0.1:PORT` while keeping the `app.localhost` Host
header and cert validation disabled (self-signed).

---

## 7. Unit tests & formatting

```bash
mise x -- mix format --check-formatted
mise x -- mix compile --warnings-as-errors
mise x -- mix test
# 13 tests, 0 failures (incl. BookReviews.UploadsTest)
```

---

## 8. Tear down

```bash
docker compose -f docker-compose.scale.yml down
kubectl delete namespace book-reviews
k3d cluster delete sa-a4
```