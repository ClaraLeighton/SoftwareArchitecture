defmodule BookReviewsWeb.ReviewController do
  use BookReviewsWeb, :controller

  alias BookReviews.Reviews
  alias BookReviews.Books

  def index(conn, _params) do
    reviews = Reviews.list_reviews()
    render(conn, :index, reviews: reviews)
  end

  def new(conn, _params) do
    books = Books.list_books()
    render(conn, :new, books: books)
  end

  def create(conn, %{"review" => review_params}) do
    case Reviews.create_review(review_params) do
      {:ok, _review} ->
        conn
        |> put_flash(:info, "Review created successfully.")
        |> redirect(to: ~p"/reviews")

      {:error, _changeset} ->
        books = Books.list_books()
        render(conn, :new, review: review_params, books: books)
    end
  end

  def show(conn, %{"id" => id}) do
    review = Reviews.get_review!(id)
    render(conn, :show, review: review)
  end

  def edit(conn, %{"id" => id}) do
    review = Reviews.get_review!(id)
    books = Books.list_books()
    render(conn, :edit, review: review, books: books)
  end

  def update(conn, %{"id" => id, "review" => review_params}) do
    review = Reviews.get_review!(id)

    case Reviews.update_review(review, review_params) do
      {:ok, _review} ->
        conn
        |> put_flash(:info, "Review updated successfully.")
        |> redirect(to: ~p"/reviews/#{id}")

      {:error, _changeset} ->
        books = Books.list_books()
        render(conn, :edit, review: Map.put(review_params, "_id", id), books: books)
    end
  end

  def delete(conn, %{"id" => id}) do
    review = Reviews.get_review!(id)
    Reviews.delete_review(review)

    conn
    |> put_flash(:info, "Review deleted successfully.")
    |> redirect(to: ~p"/reviews")
  end
end
