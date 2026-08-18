defmodule BookReviewsWeb.ReviewHTML do
  @moduledoc """
  This module contains templates for review views.
  """
  use BookReviewsWeb, :html

  embed_templates "reviews/*"

  def format_number(nil), do: "0"

  def format_number(n) when is_integer(n),
    do:
      Integer.to_string(n)
      |> String.reverse()
      |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
      |> String.reverse()

  def format_number(_), do: "0"

  def id_to_string(nil), do: ""
  def id_to_string(%BSON.ObjectId{} = id), do: BSON.ObjectId.encode!(id)
  def id_to_string(id) when is_binary(id), do: id
  def id_to_string(_), do: ""

  def score_stars(score) do
    full = div(score, 1)
    empty = 5 - full
    String.duplicate("★", full) <> String.duplicate("☆", empty)
  end
end
