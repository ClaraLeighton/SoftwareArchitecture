defmodule BookReviewsWeb.BookController do
  use BookReviewsWeb, :controller

  alias BookReviews.Books
  alias BookReviews.Authors
  alias BookReviews.Reviews

  def index(conn, _params) do
    books = Books.list_books()
    render(conn, :index, books: books)
  end

  def new(conn, _params) do
    authors = Authors.list_authors()
    render(conn, :new, authors: authors)
  end

  def create(conn, %{"book" => book_params}) do
    case Books.create_book(book_params) do
      {:ok, _book} ->
        conn
        |> put_flash(:info, "Book created successfully.")
        |> redirect(to: ~p"/books")

      {:error, _changeset} ->
        authors = Authors.list_authors()
        render(conn, :new, book: book_params, authors: authors)
    end
  end

  def show(conn, %{"id" => id}) do
    book = Books.get_book!(id)
    author_id = BSON.ObjectId.encode!(book["author_id"])
    author = Authors.get_author!(author_id)
    reviews = Reviews.list_reviews_by_book(id)

    render(conn, :show, book: book, author: author, reviews: reviews)
  end

  def edit(conn, %{"id" => id}) do
    book = Books.get_book!(id)
    authors = Authors.list_authors()
    render(conn, :edit, book: book, authors: authors)
  end

  def update(conn, %{"id" => id, "book" => book_params}) do
    book = Books.get_book!(id)

    case Books.update_book(book, book_params) do
      {:ok, _book} ->
        conn
        |> put_flash(:info, "Book updated successfully.")
        |> redirect(to: ~p"/books/#{id}")

      {:error, _changeset} ->
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
    results = Books.search_books(query, page)
    render(conn, :search, results: results, query: query)
  end

  def search(conn, _params) do
    render(conn, :search,
      results: %{books: [], total: 0, page: 1, per_page: 10, total_pages: 0},
      query: ""
    )
  end
end
