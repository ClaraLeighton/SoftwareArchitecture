defmodule BookReviewsWeb.Static do
  @moduledoc """
  Runtime-switchable `Plug.Static` wrapper.

  Phoenix endpoints compile their plug pipeline, so a flag read *after* boot
  cannot remove a static-serving plug. This module re-implements the decision
  at request time:

    * `:serve_static` is `true` (no proxy, the default) — the application
      serves the compiled assets **and** the `/uploads` tree itself;
    * `:serve_static` is `false` (a reverse proxy is present) — the proxy
      serves and caches those files at the edge, so this plug simply lets the
      request fall through to the router (where it 404s; it is never reached
      in normal operation because the proxy answers it first).

  The compiled `Plug.Static` state is cached in `:persistent_term`, keyed by
  the resolved options, so the per-request overhead is a single lookup.
  """

  @behaviour Plug

  @missing :__static_state_missing__

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, opts) do
    cond do
      not serve_static?() ->
        conn

      Keyword.get(opts, :uploads, false) ->
        go(conn, upload_opts(opts))

      true ->
        go(conn, opts)
    end
  end

  defp serve_static? do
    Application.get_env(:book_reviews, :serve_static, true)
  end

  defp upload_opts(opts) do
    opts
    |> Keyword.delete(:uploads)
    |> Keyword.put(:from, BookReviews.Uploads.root())
  end

  defp go(conn, opts) do
    key = {:book_reviews_web_static, inspect(opts)}

    state =
      case :persistent_term.get(key, @missing) do
        @missing ->
          state = Plug.Static.init(opts)
          :persistent_term.put(key, state)
          state

        state ->
          state
      end

    Plug.Static.call(conn, state)
  end
end
