defmodule BookReviewsWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use BookReviewsWeb, :html

  embed_templates "layouts/*"

  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current scope"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="bg-indigo-700 text-white shadow-lg">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between h-16">
          <div class="flex items-center">
            <.link href="/" class="flex-shrink-0 flex items-center">
              <span class="text-xl font-bold">Book Reviews</span>
            </.link>
          </div>
          <nav class="flex items-center space-x-4">
            <.link
              href={~p"/authors"}
              class="text-indigo-100 hover:text-white px-3 py-2 rounded-md text-sm font-medium"
            >
              Authors
            </.link>
            <.link
              href={~p"/books"}
              class="text-indigo-100 hover:text-white px-3 py-2 rounded-md text-sm font-medium"
            >
              Books
            </.link>
            <.link
              href={~p"/reviews"}
              class="text-indigo-100 hover:text-white px-3 py-2 rounded-md text-sm font-medium"
            >
              Reviews
            </.link>
            <.link
              href={~p"/sales"}
              class="text-indigo-100 hover:text-white px-3 py-2 rounded-md text-sm font-medium"
            >
              Sales
            </.link>
            <div class="border-l border-indigo-500 h-6 mx-2"></div>
            <.link
              href={~p"/books/top-rated"}
              class="text-indigo-100 hover:text-white px-3 py-2 rounded-md text-sm font-medium"
            >
              Top Rated
            </.link>
            <.link
              href={~p"/books/top-selling"}
              class="text-indigo-100 hover:text-white px-3 py-2 rounded-md text-sm font-medium"
            >
              Top Selling
            </.link>
            <.link
              href={~p"/books/search"}
              class="text-indigo-100 hover:text-white px-3 py-2 rounded-md text-sm font-medium"
            >
              Search
            </.link>
          </nav>
        </div>
      </div>
    </header>

    <.flash_group flash={@flash} />

    <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      {render_slot(@inner_block)}
    </main>
    """
  end

  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
