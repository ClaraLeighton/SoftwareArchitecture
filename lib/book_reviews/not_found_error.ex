defmodule BookReviews.NotFoundError do
  @moduledoc """
  Raised when a record is not found in the database.
  """
  defexception [:message, :queryable]

  @impl true
  def exception(opts) do
    queryable = Keyword.get(opts, :queryable, "record")
    message = "no #{queryable} found"
    %__MODULE__{message: message, queryable: queryable}
  end
end
