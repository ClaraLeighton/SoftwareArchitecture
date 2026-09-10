defmodule BookReviews.Books do
  @moduledoc """
  Context for managing books with all business logic.
  """

  alias BookReviews.MongoRepo
  alias BookReviews.{Cache, Search}

  @collection "books"

  def list_books do
    MongoRepo.find(@collection, %{}, sort: %{"title" => 1})
  end

  def get_book!(id) do
    case MongoRepo.find_one(@collection, %{"_id" => ensure_object_id(id)}) do
      nil -> raise BookReviews.NotFoundError, queryable: "book"
      book -> book
    end
  rescue
    ArgumentError -> raise BookReviews.NotFoundError, queryable: "book"
  end

  def create_book(attrs) do
    with {:ok, sales} <- parse_integer(attrs["sales"] || "0", 0),
         {:ok, author_id} <- parse_object_id(attrs["author_id"]) do
      doc = %{
        title: attrs["title"],
        summary: attrs["summary"],
        published_date: parse_date(attrs["published_date"]),
        sales: sales,
        author_id: author_id
      }

      case MongoRepo.insert_one(@collection, doc) do
        {:ok, result} ->
          book = Map.put(doc, "_id", result.inserted_id)
          Search.index_book(book)
          invalidate_host_views()
          {:ok, book}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def update_book(%{"_id" => id} = _book, attrs) do
    oid = ensure_object_id(id)
    filter = %{"_id" => oid}

    case build_update_fields(attrs) do
      {:ok, fields} ->
        case MongoRepo.update_one(@collection, filter, %{"$set" => fields}) do
          {:ok, _} ->
            book = get_book!(id)
            Search.index_book(book)
            Cache.delete(avg_score_key(id))
            invalidate_host_views()
            {:ok, book}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def delete_book(%{"_id" => id}) do
    oid = ensure_object_id(id)

    case MongoRepo.delete_one(@collection, %{"_id" => oid}) do
      {:ok, _} ->
        Search.delete_book(id)
        Cache.delete(avg_score_key(id))
        invalidate_host_views()

      error ->
        error
    end
  end

  @doc """
  Average review score of a single book (1–5), cached and reused across the
  derived views. Returns `nil` for books without reviews.
  """
  def average_book_score(book_id) do
    Cache.get_or_compute(avg_score_key(book_id), fn -> compute_average_score(book_id) end)
  end

  defp compute_average_score(book_id) do
    pipeline = [
      %{"$match" => %{"book_id" => ensure_object_id(book_id)}},
      %{"$group" => %{"_id" => nil, "avg" => %{"$avg" => "$score"}}}
    ]

    case MongoRepo.aggregate("reviews", pipeline) do
      [%{"avg" => avg}] -> avg
      [] -> nil
    end
  end

  defp avg_score_key(book_id) do
    "book_avg_" <> id_string(book_id)
  end

  defp id_string(%BSON.ObjectId{} = oid), do: BSON.ObjectId.encode!(oid)
  defp id_string(id) when is_binary(id), do: id

  @doc """
  Purges every cached entry that could be affected by a change to a book:
  the books it appears in (top rated / top selling) and the authors overview.
  """
  def invalidate_host_views do
    Cache.delete(top_rated_key(10))
    Cache.delete(top_selling_key(50))
    Cache.delete_pattern("authors_stats_*")
    :ok
  end

  def top_rated_books(limit \\ 10) do
    Cache.get_or_compute(top_rated_key(limit), fn -> db_top_rated_books(limit) end)
  end

  def top_selling_books(limit \\ 50) do
    Cache.get_or_compute(top_selling_key(limit), fn -> db_top_selling_books(limit) end)
  end

  defp top_rated_key(limit), do: "top_rated_#{limit}"
  defp top_selling_key(limit), do: "top_selling_#{limit}"

  defp db_top_rated_books(limit) do
    pipeline = [
      %{
        "$lookup" => %{
          "from" => "reviews",
          "localField" => "_id",
          "foreignField" => "book_id",
          "as" => "rs"
        }
      },
      %{"$unwind" => "$rs"},
      %{
        "$group" => %{
          "_id" => "$_id",
          "title" => %{"$first" => "$title"},
          "avg" => %{"$avg" => "$rs.score"},
          "reviews" => %{"$sum" => 1},
          "highest" => %{"$max" => "$rs.score"},
          "lowest" => %{"$min" => "$rs.score"}
        }
      },
      %{"$match" => %{"reviews" => %{"$gte" => 3}}},
      %{"$sort" => %{"avg" => -1, "reviews" => -1}},
      %{"$limit" => limit}
    ]

    MongoRepo.aggregate(@collection, pipeline)
  end

  defp db_top_selling_books(limit) do
    pipeline = [
      %{"$sort" => %{"sales" => -1}},
      %{"$limit" => limit},
      %{"$group" => %{"_id" => nil, "books" => %{"$push" => "$$ROOT"}}},
      %{"$unwind" => "$books"},
      %{
        "$lookup" => %{
          "from" => "books",
          "localField" => "books.author_id",
          "foreignField" => "author_id",
          "as" => "authBooks"
        }
      },
      %{
        "$project" => %{
          "_id" => 0,
          "bookId" => "$books._id",
          "title" => "$books.title",
          "totalSales" => "$books.sales",
          "authorId" => "$books.author_id",
          "authorTotalSales" => %{"$sum" => "$authBooks.sales"}
        }
      },
      %{"$sort" => %{"totalSales" => -1}}
    ]

    books = MongoRepo.aggregate(@collection, pipeline)
    top5_by_year = get_top5_by_year()

    Enum.map(books, fn book ->
      pub_year = get_publication_year(book["bookId"])

      in_top5 =
        if pub_year,
          do: Map.get(top5_by_year, pub_year, []) |> Enum.member?(book["bookId"]),
          else: false

      Map.put(book, "inTop5Year", in_top5)
    end)
  end

  def search_books(query, page \\ 1, per_page \\ 10) do
    terms = String.split(query, " ") |> Enum.reject(&(&1 == ""))

    filters =
      Enum.map(terms, fn term -> %{"summary" => %{"$regex" => term, "$options" => "i"}} end)

    filter = if length(filters) > 0, do: %{"$or" => filters}, else: %{}

    offset = (page - 1) * per_page

    pipeline = [
      %{"$match" => filter},
      %{"$sort" => %{"title" => 1}},
      %{"$skip" => offset},
      %{"$limit" => per_page}
    ]

    books = MongoRepo.aggregate(@collection, pipeline)
    total = MongoRepo.count(@collection, filter)

    %{
      books: books,
      total: total,
      page: page,
      per_page: per_page,
      total_pages: ceil(total / per_page)
    }
  end

  def count_books do
    MongoRepo.count(@collection)
  end

  @doc "All reviews for a book (used to build the searchable text of a book)."
  def list_reviews_for_index(book_id) do
    MongoRepo.find("reviews", %{"book_id" => ensure_object_id(book_id)})
  end

  defp get_top5_by_year do
    pipeline = [
      %{"$sort" => %{"sales" => -1}},
      %{
        "$group" => %{
          "_id" => %{"year" => "$year", "book" => "$book_id"},
          "sales" => %{"$max" => "$sales"}
        }
      },
      %{"$sort" => %{"_id.year" => 1, "sales" => -1}},
      %{
        "$group" => %{
          "_id" => "$_id.year",
          "top" => %{"$push" => "$_id.book"},
          "count" => %{"$sum" => 1}
        }
      },
      %{
        "$project" => %{
          "_id" => 1,
          "top" => %{"$slice" => ["$top", 5]}
        }
      }
    ]

    MongoRepo.aggregate("sales_by_year", pipeline)
    |> Enum.reduce(%{}, fn doc, acc ->
      Map.put(acc, doc["_id"], doc["top"])
    end)
  end

  defp get_publication_year(book_id) do
    case MongoRepo.find_one(@collection, %{"_id" => book_id},
           projection: %{"published_date" => 1}
         ) do
      nil -> nil
      %{"published_date" => %DateTime{} = dt} -> dt.year
      %{"published_date" => %Date{} = d} -> d.year
      _ -> nil
    end
  end

  defp ensure_object_id(%BSON.ObjectId{} = oid), do: oid
  defp ensure_object_id(id) when is_binary(id), do: BSON.ObjectId.decode!(id)
  defp ensure_object_id(id), do: id

  defp build_update_fields(attrs) do
    with {:ok, sales_fields} <- optional_integer(attrs, "sales", 0),
         {:ok, author_fields} <- optional_object_id(attrs, "author_id") do
      fields =
        sales_fields
        |> Map.merge(author_fields)
        |> maybe_put("title", attrs["title"])
        |> maybe_put("summary", attrs["summary"])

      {:ok, maybe_put(fields, "published_date", parse_date(attrs["published_date"]))}
    end
  end

  defp optional_integer(attrs, key, min) do
    case attrs[key] do
      nil -> {:ok, %{}}
      "" -> {:ok, %{}}
      value -> with {:ok, number} <- parse_integer(value, min), do: {:ok, %{key => number}}
    end
  end

  defp optional_object_id(attrs, key) do
    case attrs[key] do
      nil -> {:ok, %{}}
      "" -> {:ok, %{}}
      value -> with {:ok, id} <- parse_object_id(value), do: {:ok, %{key => id}}
    end
  end

  defp parse_object_id(nil), do: {:error, :invalid_author}
  defp parse_object_id(""), do: {:error, :invalid_author}

  defp parse_object_id(id) do
    {:ok, BSON.ObjectId.decode!(id)}
  rescue
    ArgumentError -> {:error, :invalid_author}
    FunctionClauseError -> {:error, :invalid_author}
  end

  defp parse_integer(value, min) do
    case Integer.parse(to_string(value)) do
      {number, ""} when number >= min -> {:ok, number}
      _ -> {:error, :invalid_number}
    end
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
