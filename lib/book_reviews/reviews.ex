defmodule BookReviews.Reviews do
  @moduledoc """
  Context for managing reviews with all business logic.
  """

  alias BookReviews.MongoRepo

  @collection "reviews"

  def list_reviews do
    MongoRepo.find(@collection, %{}, sort: %{"score" => -1})
  end

  def list_reviews_by_book(book_id) do
    MongoRepo.find(@collection, %{"book_id" => BSON.ObjectId.decode!(book_id)})
  end

  def get_review!(id) do
    case MongoRepo.find_one(@collection, %{"_id" => ensure_object_id(id)}) do
      nil -> raise BookReviews.NotFoundError, queryable: "review"
      review -> review
    end
  rescue
    ArgumentError -> raise BookReviews.NotFoundError, queryable: "review"
  end

  def create_review(attrs) do
    doc = %{
      book_id: BSON.ObjectId.decode!(attrs["book_id"]),
      review: attrs["review"],
      score: String.to_integer(attrs["score"] || "3"),
      upvotes: String.to_integer(attrs["upvotes"] || "0")
    }

    case MongoRepo.insert_one(@collection, doc) do
      {:ok, result} -> {:ok, Map.put(doc, "_id", result.inserted_id)}
      {:error, reason} -> {:error, reason}
    end
  end

  def update_review(%{"_id" => id} = _review, attrs) do
    oid = ensure_object_id(id)
    filter = %{"_id" => oid}
    update = %{"$set" => build_update_fields(attrs)}

    case MongoRepo.update_one(@collection, filter, update) do
      {:ok, _} -> {:ok, get_review!(id)}
      {:error, reason} -> {:error, reason}
    end
  end

  def delete_review(%{"_id" => id}) do
    oid = ensure_object_id(id)
    MongoRepo.delete_one(@collection, %{"_id" => oid})
  end

  def count_reviews do
    MongoRepo.count(@collection)
  end

  defp ensure_object_id(%BSON.ObjectId{} = oid), do: oid
  defp ensure_object_id(id) when is_binary(id), do: BSON.ObjectId.decode!(id)
  defp ensure_object_id(id), do: id

  defp build_update_fields(attrs) do
    %{}
    |> maybe_put("review", attrs["review"])
    |> maybe_put("score", if(attrs["score"], do: String.to_integer(attrs["score"]), else: nil))
    |> maybe_put(
      "upvotes",
      if(attrs["upvotes"], do: String.to_integer(attrs["upvotes"]), else: nil)
    )
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
