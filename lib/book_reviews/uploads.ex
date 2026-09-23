defmodule BookReviews.Uploads do
  @moduledoc """
  Shared storage for uploaded book covers and author photos.

  Files are written under a configurable root directory (`:uploads_path`,
  selected by the `UPLOADS_PATH` environment variable):

    * **single instance, no proxy** — defaults to the release's own
      `priv/static/uploads`; the application serves the files itself at
      `/uploads/*`;
    * **proxy / horizontally scaled** — an absolute path pointing at a volume
      shared by every application instance and the reverse proxy, which serves
      the files at the edge. This is what makes the application *stateless*:
      no uploaded file lives on any single instance's local disk.

  Filenames are always generated server-side and restricted to image
  extensions, so the stored path is safe to embed in HTML and to serve
  statically from disk.
  """

  @allowed_extensions ~w(.jpg .jpeg .png .gif .webp .svg .avif)
  @kind_map %{book_cover: "covers", author_image: "authors"}

  @doc "Configured uploads root directory."
  def root do
    Application.get_env(:book_reviews, :uploads_path) || default_root()
  end

  @doc "Default root: priv/static/uploads inside this OTP application."
  def default_root do
    Path.join(Application.app_dir(:book_reviews, "priv/static"), "uploads")
  end

  @doc "Creates the uploads tree (called on boot)."
  def ensure_root do
    File.mkdir_p!(root())
    :ok
  end

  @doc """
  Stores image `content` and returns `{:ok, url}` where `url` is the public
  path served under `/uploads/...`. `kind` selects a sub-folder
  (`:book_cover` or `:author_image`).
  """
  def store(kind, original_filename, content) when is_binary(content) do
    dir = subdir(kind)
    filename = "#{random_id()}#{extension(original_filename)}"
    path = Path.join([root(), dir, filename])

    with :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- File.write(path, content, [:binary]) do
      {:ok, "/uploads/#{dir}/#{filename}"}
    end
  end

  @doc """
  Removes a file previously returned by `store/3`. Returns `:ok` regardless:
  a missing file or a path that escapes the uploads root are both no-ops.
  """
  def delete("/uploads/" <> _ = url) do
    relative = url_path_to_relative(url)

    if relative && safe_relative?(relative) do
      _ = File.rm(Path.join(root(), relative))
    end

    :ok
  end

  def delete(_), do: :ok

  @doc "Maps a public `/uploads/...` URL onto a path relative to `root/0`."
  def url_path_to_relative("/uploads/" <> rest) when rest != "", do: rest
  def url_path_to_relative(_url), do: nil

  @doc "Whether `relative` resolves inside `root/0` (guards against traversal)."
  def safe_relative?(relative) do
    root = Path.expand(root())
    expanded = Path.expand(Path.join(root, relative))
    String.starts_with?(expanded, root <> "/")
  end

  defp subdir(kind), do: Map.get(@kind_map, kind, "misc")

  defp extension(filename) do
    ext = Path.extname(filename || "") |> String.downcase()

    if ext in @allowed_extensions, do: ext, else: ".bin"
  end

  defp random_id do
    :crypto.strong_rand_bytes(12) |> Base.url_encode64(padding: false)
  end
end
