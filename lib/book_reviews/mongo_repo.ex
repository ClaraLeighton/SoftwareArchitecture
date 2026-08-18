defmodule BookReviews.MongoRepo do
  @moduledoc """
  Thin wrapper around the MongoDB driver providing a consistent API
  for all context modules. Keeps all MongoDB-specific calls in one place
  so contexts remain database-agnostic in spirit.
  """

  @pool_size Application.compile_env(:book_reviews, :mongo_pool_size, 10)

  def child_spec(_opts) do
    url = Application.get_env(:book_reviews, :mongo_url, "mongodb://localhost:27017/book_reviews")

    %{
      id: __MODULE__,
      start: {Mongo, :start_link, [[url: url, name: :mongo, pool_size: @pool_size]]},
      type: :supervisor
    }
  end

  def insert_one(collection, doc) do
    Mongo.insert_one(:mongo, collection, doc)
  end

  def insert_many(collection, docs) do
    Mongo.insert_many(:mongo, collection, docs)
  end

  def find(collection, filter \\ %{}, opts \\ []) do
    :mongo
    |> Mongo.find(collection, filter, opts)
    |> Enum.to_list()
  end

  def find_one(collection, filter \\ %{}, opts \\ []) do
    Mongo.find_one(:mongo, collection, filter, opts)
  end

  def update_one(collection, filter, update, opts \\ []) do
    Mongo.update_one(:mongo, collection, filter, update, opts)
  end

  def delete_one(collection, filter) do
    Mongo.delete_one(:mongo, collection, filter)
  end

  def delete_many(collection, filter) do
    Mongo.delete_many(:mongo, collection, filter)
  end

  def aggregate(collection, pipeline) do
    :mongo
    |> Mongo.aggregate(collection, pipeline)
    |> Enum.to_list()
  end

  def count(collection, filter \\ %{}) do
    case Mongo.count_documents(:mongo, collection, filter) do
      {:ok, count} -> count
      _ -> 0
    end
  end
end
