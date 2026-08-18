defmodule BookReviewsWeb.ErrorJSONTest do
  use BookReviewsWeb.ConnCase, async: true

  test "renders 404" do
    assert BookReviewsWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert BookReviewsWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
