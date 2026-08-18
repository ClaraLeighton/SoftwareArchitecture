defmodule BookReviewsWeb.SaleController do
  use BookReviewsWeb, :controller

  alias BookReviews.Sales
  alias BookReviews.Books

  def index(conn, _params) do
    sales = Sales.list_sales()
    render(conn, :index, sales: sales)
  end

  def new(conn, _params) do
    books = Books.list_books()
    render(conn, :new, books: books)
  end

  def create(conn, %{"sale" => sale_params}) do
    case Sales.create_sale(sale_params) do
      {:ok, _sale} ->
        conn
        |> put_flash(:info, "Sale created successfully.")
        |> redirect(to: ~p"/sales")

      {:error, _changeset} ->
        books = Books.list_books()
        render(conn, :new, sale: sale_params, books: books)
    end
  end

  def show(conn, %{"id" => id}) do
    sale = Sales.get_sale!(id)
    render(conn, :show, sale: sale)
  end

  def edit(conn, %{"id" => id}) do
    sale = Sales.get_sale!(id)
    books = Books.list_books()
    render(conn, :edit, sale: sale, books: books)
  end

  def update(conn, %{"id" => id, "sale" => sale_params}) do
    sale = Sales.get_sale!(id)

    case Sales.update_sale(sale, sale_params) do
      {:ok, _sale} ->
        conn
        |> put_flash(:info, "Sale updated successfully.")
        |> redirect(to: ~p"/sales/#{id}")

      {:error, _changeset} ->
        books = Books.list_books()
        render(conn, :edit, sale: Map.put(sale_params, "_id", id), books: books)
    end
  end

  def delete(conn, %{"id" => id}) do
    sale = Sales.get_sale!(id)
    Sales.delete_sale(sale)

    conn
    |> put_flash(:info, "Sale deleted successfully.")
    |> redirect(to: ~p"/sales")
  end
end
