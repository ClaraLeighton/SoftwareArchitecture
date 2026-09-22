# Assignment 4: Edge & Scale

**Universidad de los Andes**  
*FACULTAD DE INGENIERÍA Y CIENCIAS APLICADAS*

---

So far your application is a single instance. In this assignment we put a reverse proxy in front of it, and then scale it horizontally behind a load balancer.

This is the typical shape of a production web system.

---

## Concept Review

### Reverse Proxy

A reverse proxy sits between clients and your application servers, and forwards requests on their behalf. It is a single, controlled entry point (the "edge").

- TLS termination, request routing, static asset serving.
- Caching, compression, rate limiting, access control.
- It hides how many application instances exist behind it.

### Load Balancer

A load balancer distributes incoming requests across multiple identical instances of your application.

- Lets you scale horizontally (see the Quality Attributes class: scalability/elasticity).
- Improves availability: if one instance dies, traffic routes to the others.
- Most reverse proxies can act as a load balancer.

### Statelessness

For a load balancer to send a request to any instance, all instances must behave identically. This means the application must be **stateless**:

- No user session stored in the instance's memory.
- No uploaded files stored on the instance's local disk.
- Any per-user or per-request state must live in shared storage (database, cache, object store) that all instances reach.

If you stored state locally in earlier assignments, you will have to change it now.

### TLS & the CDN

Two more edge responsibilities:

- **TLS termination:** the reverse proxy holds the certificate and decrypts HTTPS, so your application only speaks plain HTTP internally.
- **CDN (Content Delivery Network):** a geographically distributed cache for static assets, close to the user. We cannot deploy a real CDN locally, but the reverse proxy serving and caching your static assets applies the same idea at the edge.

---

## Assignment Requirements

- Same groups as previous assignments.
- Same application as previous assignments.
- Due in 2 weeks.
- A reverse proxy will be assigned to your team (see assigned list below).

### 1. Reverse Proxy & Static Assets
- Implement your assigned reverse proxy, and have it serve your application under a custom local domain (ex: `app.localhost`).
- Terminate TLS at the reverse proxy (a self-signed certificate is fine), so the application is reached over HTTPS.
- Modify your application and models to allow the upload of book cover and author images.
- The storage path of these image files should be configurable.
- If a reverse proxy is not present, your application serves the static assets.
- If a reverse proxy is present, the static assets must be served (and cached) by the reverse proxy, not the application. (*Tip: a flag/environment variable selects this.*)

### 2. Horizontal Scaling
- Configure your reverse proxy as a load balancer across **at least 3 instances** of your application.
- Make your application stateless so any instance can serve any request:
  - Move session state to shared storage (e.g., your cache from Assignment 3).
  - Move uploaded images to shared storage reachable by all instances (a shared volume or object store), not an instance's local disk.
- Verify that stopping one instance does not break the application.

---

## Reflection

In Assignment 1 you predicted which decisions would be expensive to change later.

- Did making the application stateless require changes you did not anticipate back then?
- How far through your codebase did those changes reach?
- You will revisit this prediction again in the final assignment.

---

## Deliverables

### 1. Docker Compose
You must implement multiple docker compose files that account for the following deployments:
1. Application + Database (single instance, no proxy)
2. Application + Database + Reverse Proxy (single instance)
3. Application + Database + Reverse Proxy + Cache + Search Engine
4. Application (x3) + Database + Reverse Proxy as load balancer + Cache + Search Engine

*(Carry over the cache and search engine from Assignment 3.)*

### 2. Kubernetes
Carrying forward your Kubernetes deployment, also run the full configuration on your local cluster (`minikube` / `k3d`), now horizontally scaled:

- Scale the application Deployment to 3 replicas; the Service balances requests across them (this is the load balancing the cluster does for you).
- Keep your assigned reverse proxy at the edge (Ingress / TLS termination, static assets), in front of the Service.
- The same statelessness requirement applies: any replica must serve any request.
- The compose deployments remain the working default; only the full deployment is required on Kubernetes.

### 3. Load Test
You will do a local load test on the single-instance and the load-balanced (x3) deployments:

- **Workload:** 1, 10, 100, 1000, 5000 requests in 5 minutes.
- **Metrics to capture (per container and its processes):** CPU usage (%), memory usage, number of threads; alongside your application response times and status codes.
- **Tools:** Use Gatling ([https://gatling.io/](https://gatling.io/)), JMeter ([https://jmeter.apache.org/](https://jmeter.apache.org/)), or any load testing tool you know.

#### Endpoints to Test
Test four endpoints, each chosen to stress a different tier, so that the results show where the bottleneck is:

1. **Static asset** (a book cover / author image) $\rightarrow$ the reverse proxy / edge.
2. **Expensive aggregation** (top 50 selling, or the authors overview) $\rightarrow$ application CPU + database + cache.
3. **Search window** $\rightarrow$ search engine.
4. **Cheap dynamic read** (a single book's detail page) $\rightarrow$ application + database baseline.

*Report each endpoint separately. A single combined number hides which tier scaled and which did not.*

### 4. Report (max. 15 pages)
Write a report describing:

- The architecture of each deployment and how the components interact.
- Advantages/disadvantages of a reverse proxy, TLS termination at the edge, and serving static assets at the edge (the CDN idea).
- Strengths and weaknesses of your assigned reverse proxy.
- What you had to change to make the application stateless, and how expensive that change was.
- The load-test results for single-instance vs. load-balanced, per endpoint, and your interpretation: which tier was the bottleneck, and which endpoints benefited from the extra instances (and which did not).
- A conclusion.

---

## Reverse Proxies Assignment

- **Nginx:** Group 1
