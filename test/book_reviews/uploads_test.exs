defmodule BookReviews.UploadsTest do
  use ExUnit.Case, async: false

  alias BookReviews.Uploads

  setup do
    tmp =
      Path.join(
        System.tmp_dir!(),
        "book_reviews_uploads_test_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(tmp)
    Application.put_env(:book_reviews, :uploads_path, tmp)

    on_exit(fn ->
      File.rm_rf!(tmp)
      Application.put_env(:book_reviews, :uploads_path, nil)
    end)

    %{tmp: tmp}
  end

  test "stores an image under a kind folder and returns a public URL", %{tmp: tmp} do
    assert {:ok, url} = Uploads.store(:book_cover, "summer_cover.jpg", "filedata")
    assert url =~ ~r{^/uploads/covers/[A-Za-z0-9_-]+\.jpg$}

    relative = Uploads.url_path_to_relative(url)
    assert File.read!(Path.join(tmp, relative)) == "filedata"
  end

  test "author images go to the authors folder" do
    assert {:ok, url} = Uploads.store(:author_image, "photo.png", "x")
    assert url =~ ~r{^/uploads/authors/.*\.png$}
  end

  test "non-image extensions are stored with a .bin extension" do
    assert {:ok, url} = Uploads.store(:book_cover, "evil.sh", "#!/bin/sh")
    assert String.ends_with?(url, ".bin")
  end

  test "delete removes the stored file", %{tmp: tmp} do
    {:ok, url} = Uploads.store(:author_image, "photo.jpeg", "content")
    path = Uploads.url_path_to_relative(url) |> then(&Path.join(tmp, &1))
    assert File.exists?(path)

    assert Uploads.delete(url) == :ok
    refute File.exists?(path)
  end

  test "delete is a safe no-op for out-of-tree paths" do
    assert Uploads.delete("/uploads/../../etc/passwd") == :ok
    assert Uploads.delete("../../etc/passwd") == :ok

    # The file referenced must always resolve inside the uploads root.
    refute Uploads.safe_relative?("/uploads/../..")
  end
end
