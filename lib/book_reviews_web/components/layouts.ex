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
    <header class="border-b border-[#e4dfd8] bg-[#fbfaf8]/90 backdrop-blur-md">
      <div class="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-3 px-4 py-4 sm:px-6 lg:px-8">
        <.link href="/" class="group flex items-center gap-3">
          <span class="grid size-10 place-items-center rounded-xl bg-[#24211f] text-lg text-[#f7e8b1] shadow-sm transition-transform group-hover:-rotate-3">B</span>
          <span>
            <span class="block font-serif text-xl font-bold leading-none text-[#24211f]">Book Reviews</span>
            <span class="mt-1 block text-[10px] font-bold uppercase tracking-[.22em] text-[#e86f51]">The reading room</span>
          </span>
        </.link>
        <nav class="flex max-w-full items-center gap-1 overflow-x-auto text-sm font-semibold text-[#756f69]">
          <.link
            href={~p"/authors"}
            class="whitespace-nowrap rounded-lg px-3 py-2 transition-colors hover:bg-[#f1eee9] hover:text-[#24211f]"
          >Authors</.link>
          <.link
            href={~p"/books"}
            class="whitespace-nowrap rounded-lg px-3 py-2 transition-colors hover:bg-[#f1eee9] hover:text-[#24211f]"
          >Books</.link>
          <.link
            href={~p"/reviews"}
            class="whitespace-nowrap rounded-lg px-3 py-2 transition-colors hover:bg-[#f1eee9] hover:text-[#24211f]"
          >Reviews</.link>
          <.link
            href={~p"/sales"}
            class="whitespace-nowrap rounded-lg px-3 py-2 transition-colors hover:bg-[#f1eee9] hover:text-[#24211f]"
          >Sales</.link>
          <span class="mx-1 hidden h-5 border-l border-[#e4dfd8] sm:block"></span>
          <.link
            href={~p"/books/top-rated"}
            class="whitespace-nowrap rounded-lg px-3 py-2 transition-colors hover:bg-[#f7e8b1] hover:text-[#24211f]"
          >Top rated</.link>
          <.link
            href={~p"/books/top-selling"}
            class="whitespace-nowrap rounded-lg px-3 py-2 transition-colors hover:bg-[#dce8df] hover:text-[#24211f]"
          >Top selling</.link>
          <.link
            href={~p"/books/search"}
            class="whitespace-nowrap rounded-lg px-3 py-2 transition-colors hover:bg-[#e6e0f0] hover:text-[#24211f]"
          >Search</.link>
        </nav>
      </div>
    </header>

    <.flash_group flash={@flash} />

    <main class="mx-auto max-w-7xl px-4 py-10 sm:px-6 lg:px-8">
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
