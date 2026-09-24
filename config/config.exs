import Config

config :book_reviews,
  generators: [timestamp_type: :utc_datetime],
  mongo_url: "mongodb://localhost:27017/book_reviews",
  cache_enabled: false,
  redis_url: "redis://localhost:6379",
  search_enabled: false,
  opensearch_url: "http://localhost:9200",
  search_username: "",
  search_password: "",
  # Whether the application itself serves static assets and user uploads. Set
  # to false when a reverse proxy is present: the proxy then serves (and caches)
  # them at the edge instead. Selected at runtime by SERVE_STATIC_ASSETS.
  serve_static: true,
  # Root directory for uploaded book covers / author images. Configurable via
  # UPLOADS_PATH. nil = the release's priv/static/uploads (single instance).
  uploads_path: nil,
  # Where the compiled priv/static directory is copied at boot so the reverse
  # proxy can serve it from a shared volume (CDN-style). nil = not published.
  static_publish_dir: nil

config :book_reviews, BookReviewsWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: BookReviewsWeb.ErrorHTML, json: BookReviewsWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: BookReviews.PubSub,
  live_view: [signing_salt: "1f3z2gSM"]

config :phoenix_live_view,
  root_tag_attribute: "phx-r"

config :book_reviews, BookReviews.Mailer, adapter: Swoosh.Adapters.Local

config :esbuild,
  version: "0.25.4",
  book_reviews: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

config :tailwind,
  version: "4.3.0",
  book_reviews: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
