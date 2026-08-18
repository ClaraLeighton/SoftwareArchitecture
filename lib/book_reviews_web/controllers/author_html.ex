defmodule BookReviewsWeb.AuthorHTML do
  @moduledoc """
  This module contains templates for author views.
  """
  use BookReviewsWeb, :html

  embed_templates "authors/*"

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

  def sort_link(field, current_field, current_dir, filters) do
    new_dir =
      if field == current_field,
        do: if(current_dir == "desc", do: "asc", else: "desc"),
        else: "desc"

    params = Map.merge(filters, %{"sort" => field, "dir" => new_dir})
    URI.encode_query(params)
  end
end
