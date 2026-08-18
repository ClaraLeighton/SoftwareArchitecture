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
    with {:ok, book_id} <- parse_object_id(attrs["book_id"]),
         {:ok, score} <- parse_integer(attrs["score"] || "3", 1, 5),
         {:ok, upvotes} <- parse_integer(attrs["upvotes"] || "0", 0, nil) do
      doc = %{book_id: book_id, review: attrs["review"], score: score, upvotes: upvotes}

      case MongoRepo.insert_one(@collection, doc) do
        {:ok, result} -> {:ok, Map.put(doc, "_id", result.inserted_id)}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def update_review(%{"_id" => id} = _review, attrs) do
    oid = ensure_object_id(id)
    filter = %{"_id" => oid}

    case build_update_fields(attrs) do
      {:ok, fields} ->
        case MongoRepo.update_one(@collection, filter, %{"$set" => fields}) do
          {:ok, _} -> {:ok, get_review!(id)}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
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
    with {:ok, score_fields} <- optional_integer(attrs, "score", 1, 5),
         {:ok, upvote_fields} <- optional_integer(attrs, "upvotes", 0, nil) do
      {:ok, score_fields |> Map.merge(upvote_fields) |> maybe_put("review", attrs["review"])}
    end
  end

  defp optional_integer(attrs, key, min, max) do
    case attrs[key] do
      nil -> {:ok, %{}}
      "" -> {:ok, %{}}
      value -> with {:ok, number} <- parse_integer(value, min, max), do: {:ok, %{key => number}}
    end
  end

  defp parse_object_id(nil), do: {:error, :invalid_book}

  defp parse_object_id(id) do
    {:ok, BSON.ObjectId.decode!(id)}
  rescue
    ArgumentError -> {:error, :invalid_book}
  end

  defp parse_integer(value, min, max) do
    case Integer.parse(to_string(value)) do
      {number, ""} when number >= min and (is_nil(max) or number <= max) -> {:ok, number}
      _ -> {:error, :invalid_number}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
