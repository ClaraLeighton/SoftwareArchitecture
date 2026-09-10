defmodule BookReviews.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    cache_enabled = Application.get_env(:book_reviews, :cache_enabled, false)
    search_enabled = Application.get_env(:book_reviews, :search_enabled, false)

    Application.put_env(
      :book_reviews,
      :cache_backend,
      if(cache_enabled, do: BookReviews.Cache.Redis, else: BookReviews.Cache.Null)
    )

    Application.put_env(
      :book_reviews,
      :search_backend,
      if(search_enabled, do: BookReviews.SearchEngine.OpenSearch, else: BookReviews.SearchEngine.Null)
    )

    children = [
      BookReviewsWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:book_reviews, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: BookReviews.PubSub},
      BookReviews.MongoRepo,
      BookReviewsWeb.Endpoint
    ]

    # The cache is an optional layer: Redis is only started when a URL is
    # configured, otherwise a Null backend keeps the app running untouched.
    children =
      if cache_enabled, do: [BookReviews.Cache.Redis | children], else: children

    # The search engine is optional too. When enabled, create the index and
    # backfill it with existing books in the background, best-effort.
    children =
      if search_enabled do
        [{Task, fn -> BookReviews.Search.bootstrap() end} | children]
      else
        children
      end

    opts = [strategy: :one_for_one, name: BookReviews.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    BookReviewsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end