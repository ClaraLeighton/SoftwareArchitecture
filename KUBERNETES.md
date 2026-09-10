# Kubernetes Deployment — Step-by-Step Testing

## Prerequisites

- [k3d](https://k3d.io/) (or minikube) installed
- `kubectl` configured to talk to your cluster
- Docker running

## 1. Create a local cluster

```bash
k3d cluster create sa --agents 2
```

## 2. Build the Docker image

```bash
docker build -t book-reviews/app:3.0.0 .
```

## 3. Import the image into the cluster

k3d nodes can't pull from your local Docker daemon, so you must import:

```bash
k3d image import book-reviews/app:3.0.0 -c $CLUSTER
```

## 4. Apply all manifests

```bash
kubectl apply -f k8s/
```

This creates:
- Namespace `book-reviews`
- ConfigMap and Secret (no hard-coded credentials in the image)
- MongoDB PersistentVolumeClaim, Deployment, and Service
- App Deployment and NodePort Service
- **Cache (Redis) Deployment and Service** (`k8s/22-cache.yaml`)
- **Search engine (OpenSearch) Deployment and Service** (`k8s/23-search.yaml`)

`k8s/10-configmap.yaml` enables the optional layers and points the app at the
in-cluster Redis / OpenSearch services.

## 5. Wait for pods to be ready

```bash
kubectl -n book-reviews get pods -w
```

Wait until all four pods — app, mongodb, cache, search — show `1/1` under READY,
then press `Ctrl+C`. (The OpenSearch image is ~1 GB; the first pull takes a few
minutes. The app’s search bootstrap runs at startup and can race the search pod,
in which case simply `kubectl rollout restart deploy/book-reviews-app` once
`search` is ready to repopulate the index.)

## 6. Verify the deployment

```bash
# All resources exist
kubectl -n book-reviews get all,configmap,secret,pvc

# ConfigMap/Secret are injected (not hard-coded)
kubectl -n book-reviews exec deploy/book-reviews-app -c app -- \
  env | grep -E "PORT|MONGODB_URL|SECRET_KEY_BASE|FORCE_SSL|REDIS_URL|OPENSEARCH_URL"

# PVC is bound to a volume
kubectl -n book-reviews get pvc mongodb-data

# Cache is reachable and the app uses it (populate a value by browsing a book)
kubectl -n book-reviews exec deploy/cache -- redis-cli --scan --pattern 'book_reviews:*'

# Search index was populated by the app's bootstrap
kubectl -n book-reviews exec deploy/search -- \
  curl -s localhost:9200/books/_count
```

## 7. Access the app

The Service is exposed on NodePort **30000**:

```bash
curl http://localhost:30000
```

Or use port-forward:

```bash
kubectl port-forward -n book-reviews svc/book-reviews 4000:80
curl http://localhost:4000
```

## 8. Verify data persists across restarts

```bash
# Confirm seed data loaded (should return 300 books)
kubectl -n book-reviews exec deploy/mongodb -c mongodb -- \
  mongosh --quiet --eval "use book_reviews; db.books.countDocuments()"
```

## 8b. Assignment 3: cache & search in the cluster

> First check what's actually running — the cluster app also exposes
> `/api/features` on the NodePort:
> `curl -s localhost:30000/api/features` → `"Redis"` / `"OpenSearch"` when on.

```bash
# Engine-driven search (matches review text, DB fallback would return 0):
curl 'http://localhost:30000/books/search?q=transformative'

# Cache is populated: browse a book first, then list the cached keys
kubectl -n book-reviews exec deploy/cache -- redis-cli --scan --pattern 'book_reviews:*'

# Search-engine fallback: engine absent → DB query still serves summaries
kubectl -n book-reviews scale deploy/search --replicas=0
curl 'http://localhost:30000/books/search?q=bustling'      # still returns results
kubectl -n book-reviews scale deploy/search --replicas=1

# Delete the MongoDB pod
kubectl -n book-reviews delete pod -l component=database

# Wait for the new pod to come up
kubectl -n book-reviews get pods -w

# Data is still there
kubectl -n book-reviews exec deploy/mongodb -c mongodb -- \
  mongosh --quiet --eval "use book_reviews; db.books.countDocuments()"
```

## 9. Check app logs

```bash
kubectl -n book-reviews logs deploy/book-reviews-app --tail=20
```

## 10. Tear down

```bash
kubectl delete namespace book-reviews
k3d cluster delete sa
```
