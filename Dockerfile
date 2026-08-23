# ---------------------------------------------------------------------------
# Stage 1: builder
# Installs dependencies, compiles the app and produces an OTP release.
# Base image matches the versions pinned in mise.toml (Elixir 1.17 / OTP 26).
# ---------------------------------------------------------------------------
FROM hexpm/elixir:1.17.3-erlang-26.2.5.21-debian-bookworm-20260803-slim AS builder

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends git build-essential nodejs npm ca-certificates && \
    rm -rf /var/lib/apt/lists/*

ENV MIX_ENV=prod
WORKDIR /app

# Install Hex & Rebar, then fetch and compile dependencies first so that
# Docker can cache them independently of application source changes.
RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get && mix deps.compile

# Compile the application.
COPY lib lib
RUN mix compile

# Frontend assets: daisyUI comes from npm, Tailwind/esbuild via Mix tasks.
COPY priv priv
COPY assets assets
RUN cd assets && npm ci --no-audit --no-fund
RUN mix assets.setup && mix assets.deploy

# Produce the self-contained release in _build/prod/rel/book_reviews.
# (No explicit name: Mix then infers a default release named after the app.)
RUN mix release

# ---------------------------------------------------------------------------
# Stage 2: runtime
# Only the compiled release plus the shared libraries Erlang needs.
# ---------------------------------------------------------------------------
FROM debian:bookworm-20260803-slim AS app

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends libssl3 libncurses6 ca-certificates && \
    rm -rf /var/lib/apt/lists/* && \
    useradd --system --create-home appuser

WORKDIR /app
COPY --from=builder --chown=appuser:appuser /app/_build/prod/rel/book_reviews ./

USER appuser
ENV PORT=4000 \
    PHX_SERVER=true \
    RELEASE_TMP=/tmp \
    LANG=C.UTF-8

EXPOSE 4000
CMD ["/app/bin/book_reviews", "start"]
