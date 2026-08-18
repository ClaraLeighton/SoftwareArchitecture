defmodule BookReviewsWeb.PageController do
  use BookReviewsWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
