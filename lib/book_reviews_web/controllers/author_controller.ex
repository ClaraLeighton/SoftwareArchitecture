defmodule BookReviewsWeb.AuthorController do
  use BookReviewsWeb, :controller

  alias BookReviews.Authors

  def index(conn, params) do
    sort_field = Map.get(params, "sort", "totalSales")

    sort_field =
      if sort_field in ~w(name country books avgScore totalSales),
        do: sort_field,
        else: "totalSales"

    sort_dir = if Map.get(params, "dir", "desc") == "asc", do: 1, else: -1

    filters = %{
      "name" => Map.get(params, "name", ""),
      "country" => Map.get(params, "country", ""),
      "books" => Map.get(params, "books", ""),
      "avgScore" => Map.get(params, "avgScore", ""),
      "totalSales" => Map.get(params, "totalSales", "")
    }

    authors = Authors.list_authors_with_stats(sort_field, sort_dir, filters)

    render(conn, :index,
      authors: authors,
      sort_field: sort_field,
      sort_dir: sort_dir,
      filters: filters
    )
  end

  def new(conn, _params) do
    render(conn, :new)
  end

  def create(conn, %{"author" => author_params}) do
    case Authors.create_author(author_params) do
      {:ok, _author} ->
        conn
        |> put_flash(:info, "Author created successfully.")
        |> redirect(to: ~p"/authors")

      {:error, _changeset} ->
        render(conn, :new, author: author_params)
    end
  end

  def show(conn, %{"id" => id}) do
    author = Authors.get_author!(id)
    render(conn, :show, author: author)
  end

  def edit(conn, %{"id" => id}) do
    author = Authors.get_author!(id)
    render(conn, :edit, author: author)
  end

  def update(conn, %{"id" => id, "author" => author_params}) do
    author = Authors.get_author!(id)

    case Authors.update_author(author, author_params) do
      {:ok, _author} ->
        conn
        |> put_flash(:info, "Author updated successfully.")
        |> redirect(to: ~p"/authors/#{id}")

      {:error, _changeset} ->
        render(conn, :edit, author: Map.put(author_params, "_id", id))
    end
  end

  def delete(conn, %{"id" => id}) do
    author = Authors.get_author!(id)
    Authors.delete_author(author)

    conn
    |> put_flash(:info, "Author deleted successfully.")
    |> redirect(to: ~p"/authors")
  end
end
