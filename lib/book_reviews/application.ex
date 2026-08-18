defmodule BookReviews.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BookReviewsWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:book_reviews, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: BookReviews.PubSub},
      BookReviews.MongoRepo,
      BookReviewsWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: BookReviews.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    BookReviewsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
