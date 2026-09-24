defmodule BookReviewsWeb.BookController do
  use BookReviewsWeb, :controller

  alias BookReviews.Books
  alias BookReviews.Authors
  alias BookReviews.Reviews
  alias BookReviews.Search
  alias BookReviews.Uploads

  @upload_field "cover_image"
  @upload_kind :book_cover

  def index(conn, _params) do
    books = Books.list_books()
    render(conn, :index, books: books)
  end

  def new(conn, _params) do
    authors = Authors.list_authors()
    render(conn, :new, authors: authors)
  end

  def create(conn, %{"book" => book_params}) do
    with {:ok, params, _replaced} <- handle_upload(book_params) do
      case Books.create_book(params) do
        {:ok, _book} ->
          conn
          |> put_flash(:info, "Book created successfully.")
          |> redirect(to: ~p"/books")

        {:error, _changeset} ->
          authors = Authors.list_authors()
          render(conn, :new, book: params, authors: authors)
      end
    else
      {:error, _reason} ->
        authors = Authors.list_authors()
        render(conn, :new, book: book_params, authors: authors)
    end
  end

  def show(conn, %{"id" => id}) do
    book = Books.get_book!(id)
    author_id = BSON.ObjectId.encode!(book["author_id"])
    author = Authors.get_author!(author_id)
    reviews = Reviews.list_reviews_by_book(id)
    avg_score = Books.average_book_score(id)

    render(conn, :show, book: book, author: author, reviews: reviews, avg_score: avg_score)
  end

  def edit(conn, %{"id" => id}) do
    book = Books.get_book!(id)
    authors = Authors.list_authors()
    render(conn, :edit, book: book, authors: authors)
  end

  def update(conn, %{"id" => id, "book" => book_params}) do
    book = Books.get_book!(id)
    previous_cover = book["cover_image"]

    with {:ok, params, replaced?} <- handle_upload(book_params) do
      case Books.update_book(book, params) do
        {:ok, _book} ->
          if replaced?, do: Uploads.delete(previous_cover)

          conn
          |> put_flash(:info, "Book updated successfully.")
          |> redirect(to: ~p"/books/#{id}")

        {:error, _changeset} ->
          authors = Authors.list_authors()
          render(conn, :edit, book: Map.put(params, "_id", id), authors: authors)
      end
    else
      {:error, _reason} ->
        authors = Authors.list_authors()
        render(conn, :edit, book: Map.put(book_params, "_id", id), authors: authors)
    end
  end

  def delete(conn, %{"id" => id}) do
    book = Books.get_book!(id)
    Books.delete_book(book)

    conn
    |> put_flash(:info, "Book deleted successfully.")
    |> redirect(to: ~p"/books")
  end

  def top_rated(conn, _params) do
    books = Books.top_rated_books(10)
    render(conn, :top_rated, books: books)
  end

  def top_selling(conn, _params) do
    books = Books.top_selling_books(50)
    render(conn, :top_selling, books: books)
  end

  def search(conn, %{"q" => query} = params) when query != "" do
    page = String.to_integer(Map.get(params, "page", "1"))
    results = Search.search(query, page)
    render(conn, :search, results: results, query: query)
  end

  def search(conn, _params) do
    render(conn, :search,
      results: %{books: [], total: 0, page: 1, per_page: 10, total_pages: 0},
      query: ""
    )
  end

  defp handle_upload(params) do
    case params[@upload_field] do
      %Plug.Upload{filename: filename, path: local_path} ->
        content = File.read!(local_path)

        case Uploads.store(@upload_kind, filename, content) do
          {:ok, url} -> {:ok, Map.put(params, @upload_field, url), true}
          {:error, _reason} -> {:error, :upload_failed}
        end

      _ ->
        {:ok, Map.delete(params, @upload_field), false}
    end
  end
end
