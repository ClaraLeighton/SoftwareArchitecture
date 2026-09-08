defmodule BookReviews.CacheBackend do
  @moduledoc """
  Behaviour implemented by cache backends (`BookReviews.Cache.Null` and
  `BookReviews.Cache.Redis`).

  The interface is intentionally small so an alternative cache (Memcached,
  an in-memory ETS store, …) can be swapped in without touching callers.
  """

  @doc "Reads `key`. Returns `{:ok, value}` on a hit or `:error` on a miss."
  @callback get(prefix :: String.t(), key :: String.t()) :: {:ok, term()} | :error

  @doc "Writes `value` under `key`, expiring after `ttl_seconds`."
  @callback put(prefix :: String.t(), key :: String.t(), value :: term(), ttl_seconds :: integer()) ::
              :ok | {:error, term()}

  @doc "Deletes a single key."
  @callback delete(prefix :: String.t(), key :: String.t()) :: :ok | {:error, term()}

  @doc "Deletes every key matching `pattern` (e.g. `*` for the whole prefix)."
  @callback delete_pattern(prefix :: String.t(), pattern :: String.t()) ::
              :ok | {:error, term()}
end