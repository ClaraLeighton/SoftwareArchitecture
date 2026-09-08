defmodule BookReviewsWeb.PageControllerTest do
  use BookReviewsWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "BookReviews"
  end

  test "GET /api/features reports the configured backends", %{conn: conn} do
    conn = get(conn, "/api/features")
    assert json_response(conn, 200)
    assert %{"cache_enabled" => cache, "search_enabled" => search} = json_response(conn, 200)
    assert is_boolean(cache) and is_boolean(search)
  end
end
