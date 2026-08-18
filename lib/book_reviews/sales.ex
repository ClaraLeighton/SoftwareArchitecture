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
    doc = %{
      book_id: BSON.ObjectId.decode!(attrs["book_id"]),
      year: String.to_integer(attrs["year"] || "2024"),
      sales: String.to_integer(attrs["sales"] || "0")
    }

    case MongoRepo.insert_one(@collection, doc) do
      {:ok, result} -> {:ok, Map.put(doc, "_id", result.inserted_id)}
      {:error, reason} -> {:error, reason}
    end
  end

  def update_sale(%{"_id" => id} = _sale, attrs) do
    oid = ensure_object_id(id)
    filter = %{"_id" => oid}
    update = %{"$set" => build_update_fields(attrs)}

    case MongoRepo.update_one(@collection, filter, update) do
      {:ok, _} -> {:ok, get_sale!(id)}
      {:error, reason} -> {:error, reason}
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
    %{}
    |> maybe_put("year", if(attrs["year"], do: String.to_integer(attrs["year"]), else: nil))
    |> maybe_put("sales", if(attrs["sales"], do: String.to_integer(attrs["sales"]), else: nil))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
