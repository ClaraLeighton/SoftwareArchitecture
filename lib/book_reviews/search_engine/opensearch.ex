defmodule BookReviews.SearchEngine.OpenSearch do
  @moduledoc """
  Search engine backed by OpenSearch, accessed through its REST API.

  Uses the already-present `Req` HTTP client, so no extra dependency is
  needed. Every call degrades gracefully: connection/HTTP errors are turned
  into `:error` / `{:error, _}` so the application keeps working with the
  database fallback if the engine is down.
  """

  @behaviour BookReviews.SearchEngine

  alias BookReviews.Json

  @index_name "books"

  @impl true
  def index_name, do: "books"

  @impl true
  def ensure_index do
    case put(@index_name, %{"mappings" => mapping_body()["mappings"]}) do
      {:ok, %{status: 200}} -> :ok
      {:ok, %{status: 400}} -> :ok
      {:ok, %{status: status}} -> {:error, {:open_search, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def index_book(book_doc) do
    id = id_string(book_doc)

    body =
      book_doc
      |> Map.delete("_id")
      |> Json.normalize()
      |> Map.put("id", id)

    case put(@index_name <> "/_doc/" <> id, body) do
      {:ok, %{status: status}} when status in [200, 201] -> :ok
      {:ok, %{status: status}} -> {:error, {:open_search, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def delete_book(book_id) do
    case delete(@index_name <> "/_doc/" <> to_string(book_id)) do
      {:ok, %{status: status}} when status in [200, 404] -> :ok
      {:ok, %{status: status}} -> {:error, {:open_search, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def search(query, page, per_page) do
    offset = (page - 1) * per_page

    body = %{
      "query" => %{
        "multi_match" => %{
          "query" => query,
          "fields" => ["title^3", "summary", "reviews_text"]
        }
      },
      "from" => offset,
      "size" => per_page
    }

    case post(@index_name <> "/_search", body) do
      {:ok, %{status: 200, body: %{"hits" => hits}}} ->
        total = get_in(hits, ["total", "value"]) || 0

        books =
          Enum.map(hits["hits"] || [], fn hit ->
            source = hit["_source"] || %{}
            Map.put(source, "_id", source["id"])
          end)

        {:ok, %{books: books, total: total}}

      {:ok, %{status: status}} ->
        {:error, {:open_search, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp mapping_body do
    %{
      "mappings" => %{
        "properties" => %{
          "id" => %{"type" => "keyword"},
          "title" => %{"type" => "text"},
          "summary" => %{"type" => "text"},
          "reviews_text" => %{"type" => "text"},
          "author_id" => %{"type" => "keyword"},
          "author_name" => %{"type" => "text"},
          "published_date" => %{"type" => "date"},
          "sales" => %{"type" => "integer"}
        }
      }
    }
  end

  defp id_string(%{"_id" => id}), do: to_string(id)
  defp id_string(%{"id" => id}), do: to_string(id)

  defp put(path, body) do
    request(:put, path, body)
  end

  defp post(path, body) do
    request(:post, path, body)
  end

  defp delete(path) do
    request(:delete, path, nil)
  end

  defp request(method, path, body) do
    url = Application.get_env(:book_reviews, :opensearch_url, "http://localhost:9200")

    req =
      Req.new(
        base_url: url,
        headers: auth_headers(),
        receive_timeout: 5_000,
        connect_options: [timeout: 2_000]
      )

    opts = if body, do: [json: body], else: []
    opts = Keyword.merge([method: method, url: path], opts)

    case Req.request(req, opts) do
      {:ok, %{status: status} = response} when status >= 200 and status < 300 ->
        {:ok, response}

      {:ok, response} ->
        {:ok, response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp auth_headers do
    username = Application.get_env(:book_reviews, :search_username, "")

    if username != "" do
      password = Application.get_env(:book_reviews, :search_password, "")
      token = Base.encode64(username <> ":" <> password)
      %{"authorization" => "Basic " <> token}
    else
      %{}
    end
  end
end