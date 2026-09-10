defmodule BookReviews.Cache.RedisTest do
  use ExUnit.Case, async: false

  @moduletag :redis

  alias BookReviews.Cache.Redis

  setup_all do
    url = Application.get_env(:book_reviews, :redis_url, "redis://localhost:6379")

    start_supervised!(%{
      id: :redix,
      start: {Redix, :start_link, [url, [name: :redix, sync_connect: false]]}
    })

    :ok
  end

  test "delete_pattern terminates when the scan completes" do
    prefix = "book_reviews_test"

    for i <- 1..25 do
      assert Redis.put(prefix, "authors_stats_#{i}", %{"a" => i}, 300) == :ok
    end

    assert Redis.put(prefix, "book_avg_1", %{"avg" => 3.0}, 300) == :ok

    assert Redis.delete_pattern(prefix, "authors_stats_*") == :ok

    assert Redis.delete(prefix, "authors_stats_1") == :ok
  end

  test "delete_pattern with no matches terminates" do
    prefix = "book_reviews_test"
    assert Redis.delete_pattern(prefix, "authors_stats_*") == :ok
  end
end