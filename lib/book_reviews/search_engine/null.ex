defmodule BookReviews.SearchEngine.Null do
  @moduledoc """
  No-op search engine used when OpenSearch is not configured.

  Indexing calls are absorbed and `search/3` always returns `:error`, which
  makes the caller fall back to the database query. This is what keeps the
  search engine optional.
  """

  @behaviour BookReviews.SearchEngine

  @impl true
  def index_name, do: "books"

  @impl true
  def ensure_index, do: :ok

  @impl true
  def index_book(_book_doc), do: :ok

  @impl true
  def delete_book(_book_id), do: :ok

  @impl true
  def search(_query, _page, _per_page), do: :error
end