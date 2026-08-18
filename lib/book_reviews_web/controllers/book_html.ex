defmodule BookReviewsWeb.BookHTML do
  @moduledoc """
  This module contains templates for book views.
  """
  use BookReviewsWeb, :html

  embed_templates "books/*"

  def format_date(nil), do: "N/A"
  def format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d")
  def format_date(%Date{} = d), do: Calendar.strftime(d, "%Y-%m-%d")
  def format_date(date) when is_binary(date), do: String.slice(date, 0, 10)
  def format_date(_), do: "N/A"

  def format_number(nil), do: "0"

  def format_number(n) when is_integer(n),
    do:
      Integer.to_string(n)
      |> String.reverse()
      |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
      |> String.reverse()

  def format_number(n) when is_float(n),
    do:
      :erlang.float_to_binary(n * 1.0, decimals: 2)
      |> String.reverse()
      |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
      |> String.reverse()

  def format_number(_), do: "0"

  def id_to_string(nil), do: ""
  def id_to_string(%BSON.ObjectId{} = id), do: BSON.ObjectId.encode!(id)
  def id_to_string(id) when is_binary(id), do: id
  def id_to_string(_), do: ""

  def score_stars(score) do
    score = max(0, min(5, score || 0))
    String.duplicate("★", score) <> String.duplicate("☆", 5 - score)
  end
end
