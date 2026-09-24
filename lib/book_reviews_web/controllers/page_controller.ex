defmodule BookReviewsWeb.PageController do
  use BookReviewsWeb, :controller

  alias BookReviews.{Cache, Search}

  def home(conn, _params) do
    render(conn, :home)
  end

  @doc """
  Reports which optional layers are active in this running instance.
  Used to verify the cache/search toggles are applied as expected.
  """
  def features(conn, _params) do
    json(conn, %{
      cache_enabled: Cache.enabled?(),
      cache_backend: Module.split(Cache.backend()) |> List.last(),
      search_enabled: Search.enabled?(),
      search_backend: Module.split(Search.backend()) |> List.last(),
      serve_static: Application.get_env(:book_reviews, :serve_static, true),
      uploads_path: BookReviews.Uploads.root(),
      static_publish_dir: Application.get_env(:book_reviews, :static_publish_dir)
    })
  end
end
