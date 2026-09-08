defmodule BookReviews.Search do
  @moduledoc """
  Facade over the full-text search engine.

  The search engine is an optional layer: when `BookReviews.SearchEngine.Null`
  is configured (OpenSearch absent), indexing becomes a no-op and `search/3`
  transparently falls back to the database query (`BookReviews.Books.search_books`).
  """

  alias BookReviews.{Books, SearchEngine}

  def enabled? do
    backend() != SearchEngine.Null
  end

  def backend do
    Application.get_env(:book_reviews, :search_backend, SearchEngine.Null)
  end

  @doc "Best-effort index creation. Never crashes the app."
  def ensure_index do
    if enabled?() do
      case backend().ensure_index() do
        :ok -> :ok
        {:error, _} -> :ok
      end
    else
      :ok
    end
  end

  @doc """
  Best-effort bootstrap used at startup when the engine is enabled: creates
  the index and re-indexes all existing books so search works immediately.
  """
  def bootstrap do
    if enabled?() do
      try do
        ensure_index()
        reindex_all()
      rescue
        _ -> :ok
      end
    end

    :ok
  end

  @doc "Re-indexes every book currently in the database."
  def reindex_all do
    books = Books.list_books()

    Enum.each(books, fn book ->
      _ = backend().index_book(build_doc(book))
    end)

    :ok
  end

  @doc """
  Searches the engine; on absence/failure falls back to the database.
  Returns the same result shape as `Books.search_books/3`.
  """
  def search(query, page \\ 1, per_page \\ 10) do
    case backend().search(query, page, per_page) do
      {:ok, %{books: books, total: total}} ->
        %{
          books: books,
          total: total,
          page: page,
          per_page: per_page,
          total_pages: ceil(total / per_page)
        }

      _ ->
        Books.search_books(query, page, per_page)
    end
  end

  @doc "Indexes (or replaces) a book document, including its author name and review texts."
  def index_book(book) do
    if enabled?() do
      _ = backend().index_book(build_doc(book))
    end

    :ok
  end

  @doc "Removes a book document from the index."
  def delete_book(book_id) do
    if enabled?(), do: _ = backend().delete_book(book_id)
    :ok
  end

  @doc "Reindexes a book after one of its reviews changed."
  def reindex_book(book_id) do
    if enabled?() do
      case fetch_book(book_id) do
        {:ok, book} -> _ = backend().index_book(build_doc(book))
        _ -> :ok
      end
    end

    :ok
  end

  defp fetch_book(id) do
    {:ok, Books.get_book!(id)}
  rescue
    _ -> :error
  end

  defp build_doc(book) do
    reviews_text =
      book["_id"]
      |> Books.list_reviews_for_index()
      |> Enum.map_join("\n", fn review -> review["review"] || "" end)

    Map.put(book, "reviews_text", reviews_text)
  end
end