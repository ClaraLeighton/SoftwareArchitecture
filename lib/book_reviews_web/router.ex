defmodule BookReviewsWeb.Router do
  use BookReviewsWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BookReviewsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", BookReviewsWeb do
    pipe_through :browser

    get "/", PageController, :home

    resources "/authors", AuthorController

    get "/books/top-rated", BookController, :top_rated
    get "/books/top-selling", BookController, :top_selling
    get "/books/search", BookController, :search
    resources "/books", BookController

    resources "/reviews", ReviewController
    resources "/sales", SaleController
  end

  if Application.compile_env(:book_reviews, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: BookReviewsWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
