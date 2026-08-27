# BookReviews

## Prerequisites

Install everything below before running the project.

### Languages and runtimes

| Tool | Version | Install |
|------|---------|---------|
| **Erlang/OTP** | 26.x | [erlang.org/downloads](https://www.erlang.org/downloads) or via mise/asdf |
| **Elixir** | 1.17+ | [elixir-lang.org/install](https://elixir-lang.org/install.html) or via mise/asdf |
| **Node.js** | 22+ | [nodejs.org](https://nodejs.org/) or via nvm |
| **MongoDB** | 7.x | [mongodb.com/docs/manual/installation](https://www.mongodb.com/docs/manual/installation/) (only needed for local dev without Docker) |

Versions are pinned in `mise.toml`. If you use [mise](https://mise.jdx.dev/) or [asdf](https://asdf-vm.com/), run:

```bash
mise install        # installs the correct Elixir + Erlang versions
```

### Docker and Kubernetes (for container deployment)

| Tool | Purpose | Install |
|------|---------|---------|
| **Docker Desktop** | Build container images | [docs.docker.com/get-docker](https://docs.docker.com/get-docker/) |
| **k3d** | Lightweight Kubernetes cluster running inside Docker | `curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh \| bash` |
| **kubectl** | Talks to the Kubernetes cluster | [kubernetes.io/docs/tasks/tools](https://kubernetes.io/docs/tasks/tools/) |

Verify everything is installed:

```bash
docker --version
k3d version
kubectl version --client
```

## Local development

```bash
# 1. Install Elixir/Node dependencies
mix setup

# 2. Start the Phoenix server
mix phx.server
```

Visit [localhost:4000](http://localhost:4000).

## Deploy to Kubernetes (k3d)

Full step-by-step instructions are in [KUBERNETES.md](KUBERNETES.md). Quick version:

```bash
# 1. Create a cluster
k3d cluster create sa --agents 2

# 2. Build and import the Docker image
docker build -t book-reviews/app:1.0.0 .
k3d image import book-reviews/app:1.0.0 -c sa

# 3. Apply all manifests
kubectl apply -f k8s/

# 4. Wait for pods, then access the app
kubectl -n book-reviews get pods -w        # wait for 1/1 READY
curl http://localhost:30000                 # NodePort
```

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://phoenix.hexdocs.pm/overview.html
* Docs: https://phoenix.hexdocs.pm
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
