defmodule BookReviews.Sales do
  @moduledoc """
  Context for managing sales by year with all business logic.
  """

  alias BookReviews.MongoRepo

  @collection "sales_by_year"

  def list_sales do
    MongoRepo.find(@collection, %{}, sort: %{"year" => -1})
  end

  def list_sales_by_book(book_id) do
    MongoRepo.find(@collection, %{"book_id" => BSON.ObjectId.decode!(book_id)},
      sort: %{"year" => 1}
    )
  end

  def get_sale!(id) do
    case MongoRepo.find_one(@collection, %{"_id" => ensure_object_id(id)}) do
      nil -> raise BookReviews.NotFoundError, queryable: "sale"
      sale -> sale
    end
  rescue
    ArgumentError -> raise BookReviews.NotFoundError, queryable: "sale"
  end

  def create_sale(attrs) do
    with {:ok, book_id} <- parse_object_id(attrs["book_id"]),
         {:ok, year} <- parse_integer(attrs["year"] || "2024", 1),
         {:ok, sales} <- parse_integer(attrs["sales"] || "0", 0) do
      doc = %{book_id: book_id, year: year, sales: sales}

      case MongoRepo.insert_one(@collection, doc) do
        {:ok, result} -> {:ok, Map.put(doc, "_id", result.inserted_id)}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def update_sale(%{"_id" => id} = _sale, attrs) do
    oid = ensure_object_id(id)
    filter = %{"_id" => oid}

    case build_update_fields(attrs) do
      {:ok, fields} ->
        case MongoRepo.update_one(@collection, filter, %{"$set" => fields}) do
          {:ok, _} -> {:ok, get_sale!(id)}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def delete_sale(%{"_id" => id}) do
    oid = ensure_object_id(id)
    MongoRepo.delete_one(@collection, %{"_id" => oid})
  end

  def count_sales do
    MongoRepo.count(@collection)
  end

  defp ensure_object_id(%BSON.ObjectId{} = oid), do: oid
  defp ensure_object_id(id) when is_binary(id), do: BSON.ObjectId.decode!(id)
  defp ensure_object_id(id), do: id

  defp build_update_fields(attrs) do
    with {:ok, year_fields} <- optional_integer(attrs, "year", 1),
         {:ok, sales_fields} <- optional_integer(attrs, "sales", 0) do
      {:ok, Map.merge(year_fields, sales_fields)}
    end
  end

  defp optional_integer(attrs, key, min) do
    case attrs[key] do
      nil -> {:ok, %{}}
      "" -> {:ok, %{}}
      value -> with {:ok, number} <- parse_integer(value, min), do: {:ok, %{key => number}}
    end
  end

  defp parse_object_id(nil), do: {:error, :invalid_book}

  defp parse_object_id(id) do
    {:ok, BSON.ObjectId.decode!(id)}
  rescue
    ArgumentError -> {:error, :invalid_book}
  end

  defp parse_integer(value, min) do
    case Integer.parse(to_string(value)) do
      {number, ""} when number >= min -> {:ok, number}
      _ -> {:error, :invalid_number}
    end
  end
end
