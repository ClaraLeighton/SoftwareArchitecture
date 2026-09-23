# Kubernetes Deployment — Step-by-Step Testing

Applies the **Assignment 4** topology: 3 stateless app replicas behind an Nginx
edge (TLS + static assets) with a shared uploads PVC, plus MongoDB, Redis and
OpenSearch.

## Prerequisites

- [k3d](https://k3d.io/) (or minikube) installed
- `kubectl` configured to talk to your cluster
- Docker running

## 1. Create a local cluster with a registry

On k3s 1.35 / containerd v2, `k3d image import` can leave images invisible to
the CRI bottleneck (`ctr` lists them but `kubelet` still tries `docker.io`).
The reliable path is a k3d-managed registry:

```bash
k3d cluster delete sa-a4
k3d registry create a4-registry --port 5111
k3d cluster create sa-a4 --agents 1 --servers 1 \
  --registry-use k3d-a4-registry:5111 \
  -p "30080:30080@server:0" -p "30443:30443@server:0" --wait
```

## 2. Build the Docker images

```bash
docker build -t book_reviews/app:4.0.0 .
docker build -t book_reviews/nginx:4.0.0 ./nginx
```

## 3. Push the images into the local registry

```bash
for img in book_reviews/app:4.0.0 book_reviews/nginx:4.0.0 mongo:7 \
           redis:7-alpine opensearchproject/opensearch:2 busybox:1.36; do
  docker tag "$img" "localhost:5111/$img"
  docker push "localhost:5111/$img"
done
```

The k3d-managed registry is pre-wired as a mirror for the `k3d-a4-registry:5000`
hostname on every node, so the cluster can pull the same image names.

## 4. Apply all manifests

```bash
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/11-secret.yaml -f k8s/10-configmap.yaml -f k8s/12-mongo-seed-configmap.yaml
./k8s/generate-edge-tls.sh   # creates the nginx-edge-tls Secret (idempotent)
kubectl apply -f k8s/20-mongodb.yaml -f k8s/21-app.yaml \
  -f k8s/22-cache.yaml -f k8s/23-search.yaml \
  -f k8s/24-uploads-pvc.yaml -f k8s/30-edge.yaml -f k8s/31-edge-configmap.yaml

# Point the committed image refs at the local registry
kubectl -n book-reviews set image deployment/book-reviews-app \
  app=k3d-a4-registry:5000/book_reviews/app:4.0.0
kubectl -n book-reviews set image deployment/book-reviews-edge \
  nginx=k3d-a4-registry:5000/book_reviews/nginx:4.0.0
```

This creates:
- Namespace `book-reviews`
- ConfigMap and Secret (no hard-coded credentials in the image)
- MongoDB PersistentVolumeClaim + Deployment + Service
- App Deployment (**3 replicas**) + ClusterIP Service — the Nginx edge is the
  entry point, so the app Service is internal
- **Uploads PVC** (`k8s/24-uploads-pvc.yaml`) mounted by every app replica
  *and* the edge pod (`UPLOADS_PATH=/data/uploads`, `STATIC_DIR=/data/static`,
  `SERVE_STATIC_ASSETS=false`)
- **Cache (Redis)** `k8s/22-cache.yaml`
- **Search engine (OpenSearch)** `k8s/23-search.yaml`
- **Nginx edge** (`k8s/30-edge.yaml`): NodePort Service `30080` (HTTP) /
  `30443` (HTTPS), TLS from the Secret, full config in `k8s/31-edge-configmap.yaml`

`k8s/10-configmap.yaml` enables the optional layers and points the app at the
in-cluster Redis / OpenSearch services plus the edge settings.

## 5. Wait for pods to be ready

```bash
kubectl -n book-reviews get pods -w
```

Wait until all pods show `1/1` — app (×3), edge, mongodb, cache, search — then
press `Ctrl+C`. (The OpenSearch image is ~1 GB; the app's search bootstrap can
race the search pod, in which case `kubectl rollout restart
deploy/book-reviews-app` once `search` is ready repopulates the index.)

## 6. Verify the deployment

```bash
# All resources exist
kubectl -n book-reviews get deploy,svc,pvc

# Show runtime labels so the LB has a target
kubectl -n book-reviews get pods -o wide

# ConfigMap/Secret are injected (not hard-coded)
kubectl -n book-reviews exec deploy/book-reviews-app -c app -- \
  env | grep -E "PORT|MONGODB_URL|UPLOADS_PATH|STATIC_DIR|SERVE_STATIC_ASSETS"

# PVCs bound
kubectl -n book-reviews get pvc mongodb-data uploads-data
```

## 7. Access the app (through the edge)

```bash
# Edge health (plain HTTP, NodePort 30080)
curl -s http://localhost:30080/healthz                     # ok

# TLS via the edge (NodePort 30443); self-signed cert, hence -k
curl -sk --resolve app.localhost:30443:127.0.0.1 -o /dev/null -w '%{http_code}\n' \
  https://app.localhost:30443/                             # 200

# Feature flags prove the edge/scale wiring
curl -sk --resolve app.localhost:30443:127.0.0.1 \
  https://app.localhost:30443/api/features

# Static assets are served by Nginx from the shared volume
curl -sk --resolve app.localhost:30443:127.0.0.1 -o /dev/null -w '%{http_code}\n' \
  https://app.localhost:30443/assets/css/app.css           # 200
```

Or port-forward to the app Service directly:

```bash
kubectl port-forward -n book-reviews svc/book-reviews 4000:80
curl http://localhost:4000
```

## 8. Data persistence & shared uploads

```bash
# Seed data loaded (should return 300 books)
kubectl -n book-reviews exec deploy/mongodb -c mongodb -- \
  mongosh --quiet --eval "use book_reviews; db.books.countDocuments()"

# Uploads survive across replicas and pod restarts
POD=$(kubectl -n book-reviews get pod -l component=web -o jsonpath='{.items[0].metadata.name}')
kubectl -n book-reviews exec "$POD" -- sh -c \
  'mkdir -p /data/uploads/covers && echo k8s > /data/uploads/covers/k.jpg'
curl -sk --resolve app.localhost:30443:127.0.0.1 -w ' -> %{http_code}\n' \
  https://app.localhost:30443/uploads/covers/k.jpg          # 200
kubectl -n book-reviews delete pod "$POD" && sleep 20
curl -sk --resolve app.localhost:30443:127.0.0.1 -w ' -> %{http_code}\n' \
  https://app.localhost:30443/uploads/covers/k.jpg          # 200 (still there)
```

## 8b. Assignment 3: cache & search in the cluster

```bash
# Feature flags
curl -s http://localhost:30080/api/features   # "Redis" / "OpenSearch" when on

# Engine-driven search (matches review text, DB fallback would return 0):
curl -sk --resolve app.localhost:30443:127.0.0.1 \
  'https://app.localhost:30443/books/search?q=transformative'

# Cache is populated: browsed book pages appear as Redis keys
kubectl -n book-reviews exec deploy/cache -- redis-cli --scan --pattern 'book_reviews:*'

# Search-engine fallback: engine absent → DB query still serves summaries
kubectl -n book-reviews scale deploy/search --replicas=0
curl -sk --resolve app.localhost:30443:127.0.0.1 \
  'https://app.localhost:30443/books/search?q=bustling'   # still results
kubectl -n book-reviews scale deploy/search --replicas=1

# MongoDB data survives pod deletion
kubectl -n book-reviews delete pod -l component=database
kubectl -n book-reviews get pods -w
kubectl -n book-reviews exec deploy/mongodb -c mongodb -- \
  mongosh --quiet --eval "use book_reviews; db.books.countDocuments()"
```

## 9. Horizontal scaling & failover

```bash
# The app runs 3 replicas today; change the count and watch it converge
kubectl -n book-reviews scale deploy/book-reviews-app --replicas=5
kubectl -n book-reviews get pods -l component=web
kubectl -n book-reviews scale deploy/book-reviews-app --replicas=3

# Kill one replica while the edge keeps serving (terminates behind LB)
kubectl -n book-reviews delete pod -l component=web --field-selector=status.phase=Running --max-count=1   # or pick one by name
curl -sk --resolve app.localhost:30443:127.0.0.1 -o /dev/null -w '%{http_code}\n' \
  https://app.localhost:30443/                             # 200
```

## 10. Load test against the k8s edge

```bash
HOST_ROUTE=app.localhost:30443:127.0.0.1 bash loadtest/run.sh https://app.localhost:30443 k8s_scale
```

See `REPORT4.md` for the captured matrix (24,444 requests, 4 endpoints).

## 11. Check app logs

```bash
kubectl -n book-reviews logs deploy/book-reviews-app --tail=20
```

## 12. Tear down

```bash
kubectl delete namespace book-reviews
k3d cluster delete sa-a4
k3d registry delete a4-registry
```