defmodule ThreadifiWeb.MentionLive.Index do
  use ThreadifiWeb, :live_view

  alias Threadifi.Chat

  @impl true
  def mount(_params, _session, socket) do
    current_scope = socket.assigns.current_scope

    socket =
      socket
      |> assign(:page_title, "Mentions")
      |> assign(:mentions, Chat.list_mentions_for_user(current_scope))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-screen bg-slate-50 text-slate-900">
        <div class="mx-auto max-w-4xl px-6 py-10">
          <header class="mb-8">
            <p class="text-xs uppercase tracking-[0.3em] text-slate-400">Notifications</p>
            <h1 class="text-3xl font-semibold text-slate-900">Mentions</h1>
            <p class="text-sm text-slate-600">
              Messages that mentioned you across your channels.
            </p>
          </header>

          <div class="space-y-4">
            <div class="hidden rounded-2xl border border-dashed border-slate-200 bg-white px-6 py-10 text-center text-sm text-slate-500 only:block">
              No mentions yet.
            </div>
            <div
              :for={mention <- @mentions}
              class="rounded-2xl border border-slate-200 bg-white px-6 py-5 shadow-sm"
            >
              <div class="flex items-center justify-between text-xs text-slate-400">
                <span>
                  {@mention.message.channel.workspace.name} · #{@mention.message.channel.name}
                </span>
                <span>{Calendar.strftime(@mention.inserted_at, "%b %d · %I:%M%p")}</span>
              </div>
              <p class="mt-3 text-sm text-slate-700">
                {render_message_body(@mention.message)}
              </p>
              <div class="mt-4">
                <.link
                  navigate={
                    ~p"/w/#{@mention.message.channel.workspace.slug}/c/#{@mention.message.channel.slug}" <>
                      "#message-#{@mention.message.id}"
                  }
                  class="text-sm font-semibold text-slate-700 hover:text-slate-900"
                >
                  Jump to message →
                </.link>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp render_message_body(%Chat.Message{format: :markdown, body: body}) do
    body
    |> Earmark.as_html!(compact_output: true)
    |> HtmlSanitizeEx.basic_html()
    |> Phoenix.HTML.raw()
  end

  defp render_message_body(%Chat.Message{body: body}), do: body
end
