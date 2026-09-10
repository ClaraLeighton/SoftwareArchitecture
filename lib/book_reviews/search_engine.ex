defmodule BookReviews.SearchEngine do
  @moduledoc """
  Behaviour for the dedicated full-text search engine.

  Implementations are swappable: `BookReviews.SearchEngine.OpenSearch` talks
  to a real cluster, `BookReviews.SearchEngine.Null` turns the engine off and
  makes every operation a no-op / miss so the application falls back to the
  database query (book summary `LIKE`).
  """

  @doc "Index name used for documents."
  @callback index_name() :: String.t()

  @doc "Ensures the index and its mapping exist."
  @callback ensure_index() :: :ok | {:error, term()}

  @doc "Indexes (or replaces) the document for a book."
  @callback index_book(book_doc :: map()) :: :ok | {:error, term()}

  @doc "Removes the document for a book."
  @callback delete_book(book_id :: String.t()) :: :ok | {:error, term()}

  @doc """
  Relevance-ranked, paginated search across title / summary / review text.

  Returns `{:ok, %{total: integer(), books: [map()]}}` or `:error`.
  """
  @callback search(query :: String.t(), page :: integer(), per_page :: integer()) ::
              {:ok, map()} | :error
end