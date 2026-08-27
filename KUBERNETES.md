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
docker build -t book-reviews/app:1.0.0 .
```

## 3. Import the image into the cluster

k3d nodes can't pull from your local Docker daemon, so you must import:

```bash
k3d image import book-reviews/app:1.0.0 -c sa
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

## 5. Wait for pods to be ready

```bash
kubectl -n book-reviews get pods -w
```

Wait until both pods show `1/1` under READY, then press `Ctrl+C`.

## 6. Verify the deployment

```bash
# All resources exist
kubectl -n book-reviews get all,configmap,secret,pvc

# ConfigMap/Secret are injected (not hard-coded)
kubectl -n book-reviews exec deploy/book-reviews-app -c app -- \
  env | grep -E "PORT|MONGODB_URL|SECRET_KEY_BASE|FORCE_SSL"

# PVC is bound to a volume
kubectl -n book-reviews get pvc mongodb-data
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
