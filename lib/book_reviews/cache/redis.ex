defmodule BookReviews.Cache.Redis do
  @moduledoc """
  Redis-backed cache using a pooled Redix connection.

  Values are JSON-encoded so they remain plaintext and portable; keys are
  namespaced under the configured prefix. All functions degrade to a miss /
  no-op on connection errors (bounded by short command timeouts) so a Redis
  outage never breaks the application.
  """

  @behaviour BookReviews.CacheBackend

  alias BookReviews.Json

  @spec child_spec(term()) :: Supervisor.child_spec()
  def child_spec(_opts) do
    url = Application.get_env(:book_reviews, :redis_url, "redis://localhost:6379")

    %{
      id: __MODULE__,
      start: {Redix, :start_link, [url, [name: :redix, sync_connect: false]]},
      type: :worker
    }
  end

  @impl true
  def get(prefix, key) do
    case Redix.command(:redix, ["GET", full_key(prefix, key)], timeout: 500) do
      {:ok, nil} -> :error
      {:ok, value} -> {:ok, decode(value)}
      _ -> :error
    end
  rescue
    _ -> :error
  end

  @impl true
  def put(prefix, key, value, ttl_seconds) do
    case Redix.command(
           :redix,
           ["SET", full_key(prefix, key), encode(value), "EX", to_string(ttl_seconds)],
           timeout: 500
         ) do
      {:ok, _} -> :ok
      error -> error
    end
  rescue
    _ -> {:error, :redis_unavailable}
  end

  @impl true
  def delete(prefix, key) do
    case Redix.command(:redix, ["DEL", full_key(prefix, key)], timeout: 500) do
      {:ok, _} -> :ok
      error -> error
    end
  rescue
    _ -> {:error, :redis_unavailable}
  end

  @impl true
  def delete_pattern(prefix, pattern) do
    match = full_key(prefix, pattern)

    case scan_and_delete(match, "0") do
      :ok -> :ok
      error -> error
    end
  rescue
    _ -> {:error, :redis_unavailable}
  end

  defp scan_and_delete(_match, nil), do: :ok

  defp scan_and_delete(match, cursor) do
    case Redix.command(:redix, ["SCAN", cursor, "MATCH", match, "COUNT", "100"], timeout: 500) do
      {:ok, [next_cursor, keys]} ->
        if keys != [] do
          case Redix.command(:redix, ["DEL" | keys], timeout: 500) do
            {:ok, _} -> :ok
            error -> error
          end
        end

        if next_cursor == "0", do: :ok, else: scan_and_delete(match, next_cursor)

      _ ->
        :ok
    end
  end

  defp full_key(prefix, key), do: "#{prefix}:#{key}"

  defp encode(value), do: Json.encode!(value)
  defp decode(value), do: Json.decode(value)
end