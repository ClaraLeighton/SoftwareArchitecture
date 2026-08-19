defmodule BookReviews.Authors do
  @moduledoc """
  Context for managing authors with all business logic.
  """

  alias BookReviews.MongoRepo

  @collection "authors"

  def list_authors do
    MongoRepo.find(@collection, %{}, sort: %{"name" => 1})
  end

  def get_author!(id) do
    case MongoRepo.find_one(@collection, %{"_id" => ensure_object_id(id)}) do
      nil -> raise BookReviews.NotFoundError, queryable: "author"
      author -> author
    end
  rescue
    ArgumentError -> raise BookReviews.NotFoundError, queryable: "author"
  end

  def create_author(attrs) do
    doc = %{
      name: attrs["name"],
      date_of_birth: parse_date(attrs["date_of_birth"]),
      country: attrs["country"],
      bio: attrs["bio"]
    }

    case MongoRepo.insert_one(@collection, doc) do
      {:ok, result} -> {:ok, Map.put(doc, "_id", result.inserted_id)}
      {:error, reason} -> {:error, reason}
    end
  end

  def update_author(%{"_id" => id} = _author, attrs) do
    oid = ensure_object_id(id)
    filter = %{"_id" => oid}
    update = %{"$set" => build_update_fields(attrs)}

    case MongoRepo.update_one(@collection, filter, update) do
      {:ok, _} -> {:ok, get_author!(id)}
      {:error, reason} -> {:error, reason}
    end
  end

  def delete_author(%{"_id" => id}) do
    oid = ensure_object_id(id)
    MongoRepo.delete_one(@collection, %{"_id" => oid})
  end

  def list_authors_with_stats(sort_field \\ "totalSales", sort_dir \\ -1, filters \\ %{}) do
    name_filter =
      if filters["name"] != "" and filters["name"] != nil, do: filters["name"], else: nil

    country_filter =
      if filters["country"] != "" and filters["country"] != nil, do: filters["country"], else: nil

    books_filter = numeric_filter(filters["books"])
    avg_score_filter = numeric_filter(filters["avgScore"])
    total_sales_filter = numeric_filter(filters["totalSales"])

    match_stage =
      cond do
        name_filter && country_filter ->
          %{
            "$match" => %{
              "name" => %{"$regex" => name_filter, "$options" => "i"},
              "country" => %{"$regex" => country_filter, "$options" => "i"}
            }
          }

        name_filter ->
          %{"$match" => %{"name" => %{"$regex" => name_filter, "$options" => "i"}}}

        country_filter ->
          %{"$match" => %{"country" => %{"$regex" => country_filter, "$options" => "i"}}}

        true ->
          nil
      end

    pipeline =
      [
        %{
          "$lookup" => %{
            "from" => "books",
            "localField" => "_id",
            "foreignField" => "author_id",
            "as" => "bs"
          }
        },
        %{"$unwind" => "$bs"},
        %{
          "$group" => %{
            "_id" => "$_id",
            "name" => %{"$first" => "$name"},
            "country" => %{"$first" => "$country"},
            "books" => %{"$sum" => 1},
            "totalSales" => %{"$sum" => "$bs.sales"},
            "bookIds" => %{"$push" => "$bs._id"}
          }
        },
        %{
          "$lookup" => %{
            "from" => "reviews",
            "localField" => "bookIds",
            "foreignField" => "book_id",
            "as" => "rs"
          }
        },
        %{
          "$project" => %{
            "_id" => 1,
            "name" => 1,
            "country" => 1,
            "books" => 1,
            "totalSales" => 1,
            "avgScore" => %{"$round" => [%{"$avg" => "$rs.score"}, 2]}
          }
        },
        %{"$sort" => %{sort_field => sort_dir}}
      ]
      |> Enum.reject(&is_nil/1)

    stats_filters =
      %{}
      |> maybe_filter("books", books_filter)
      |> maybe_filter("avgScore", avg_score_filter)
      |> maybe_filter("totalSales", total_sales_filter)

    pipeline =
      pipeline
      |> then(fn stages ->
        if match_stage, do: List.insert_at(stages, 0, match_stage), else: stages
      end)
      |> then(fn stages ->
        if stats_filters == %{},
          do: stages,
          else: List.insert_at(stages, -1, %{"$match" => stats_filters})
      end)

    MongoRepo.aggregate(@collection, pipeline)
  end

  def count_authors do
    MongoRepo.count(@collection)
  end

  defp numeric_filter(value) when value in [nil, ""], do: nil

  defp numeric_filter(value) do
    case Integer.parse(value) do
      {number, ""} -> number
      _ -> nil
    end
  end

  defp maybe_filter(filters, _field, nil), do: filters
  defp maybe_filter(filters, field, value), do: Map.put(filters, field, value)

  defp ensure_object_id(%BSON.ObjectId{} = oid), do: oid
  defp ensure_object_id(id) when is_binary(id), do: BSON.ObjectId.decode!(id)
  defp ensure_object_id(id), do: id

  defp build_update_fields(attrs) do
    %{}
    |> maybe_put("name", attrs["name"])
    |> maybe_put("date_of_birth", parse_date(attrs["date_of_birth"]))
    |> maybe_put("country", attrs["country"])
    |> maybe_put("bio", attrs["bio"])
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil

  defp parse_date(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      _ -> nil
    end
  end
end
