import Config

config :book_reviews,
  generators: [timestamp_type: :utc_datetime],
  mongo_url: "mongodb://localhost:27017/book_reviews"

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
