defmodule BookReviews.StaticPublisher do
  @moduledoc """
  Publishes the compiled `priv/static` directory into a shared location that a
  reverse proxy serves from disk (the "CDN at the edge" idea).

  Runs once at boot on every instance. It is a no-op unless `:static_publish_dir`
  is configured (`STATIC_DIR` environment variable), so single-instance
  deployments without a proxy keep serving their own assets.

  Copying is idempotent: every replica copies the same (image-baked) files over
  the shared volume, so simultaneous boots are safe.
  """

  @doc "Publishes priv/static to the configured shared directory, if any."
  def publish do
    case Application.get_env(:book_reviews, :static_publish_dir) do
      nil ->
        :ok

      target ->
        source = Application.app_dir(:book_reviews, "priv/static")
        File.mkdir_p!(target)
        _ = File.cp_r(source, target, fn src, _dest -> {:ok, src} end)
        :ok
    end
  end

  @doc "Whether this instance is expected to publish its assets."
  def publishing? do
    Application.get_env(:book_reviews, :static_publish_dir) != nil
  end
end
