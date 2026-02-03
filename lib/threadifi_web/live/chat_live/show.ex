defmodule ThreadifiWeb.ChatLive.Show do
  use ThreadifiWeb, :live_view

  alias Threadifi.Chat
  alias Threadifi.Chat.Message
  alias Threadifi.Chat.Snippet
  alias Threadifi.Workspaces

  @impl true
  def mount(
        %{"workspace_slug" => workspace_slug, "channel_slug" => channel_slug},
        _session,
        socket
      ) do
    current_scope = socket.assigns.current_scope

    with workspace when not is_nil(workspace) <-
           Workspaces.get_workspace_by_slug(current_scope, workspace_slug),
         channels <- Workspaces.list_channels(current_scope, workspace),
         channel when not is_nil(channel) <- Enum.find(channels, &(&1.slug == channel_slug)),
         :ok <- authorize_channel(channel, current_scope) do
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Threadifi.PubSub, channel_topic(channel))
      end

        socket =
          socket
          |> assign(:page_title, channel.name)
          |> assign(:workspace, workspace)
          |> assign(:channels, channels)
          |> assign(:channel, channel)
          |> assign(:form, to_form(Chat.Message.changeset(%Message{}, %{})))
          |> assign(:show_snippet_modal, false)
          |> assign(:snippet_form, to_form(snippet_changeset(%{}), as: :snippet))
          |> stream(:messages, Chat.list_messages(channel.id))

      {:ok, socket}
    else
      :unauthorized ->
        {:ok,
         socket
         |> put_flash(:error, "You do not have access to that private channel.")
         |> push_navigate(to: ~p"/w/#{workspace_slug}")}

      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Workspace or channel not found.")
         |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-screen bg-slate-50 text-slate-900">
        <div class="flex">
          <aside class="w-64 border-r border-slate-200 bg-white px-5 py-6">
            <div class="text-xs uppercase tracking-wide text-slate-500">Channels</div>
            <div class="mt-4 space-y-2">
              <.link
                :for={channel <- @channels}
                navigate={~p"/w/#{@workspace.slug}/c/#{channel.slug}"}
                class={[
                  "flex items-center justify-between rounded-lg px-3 py-2 text-sm transition",
                  channel.id == @channel.id && "bg-slate-900 text-white",
                  channel.id != @channel.id && "text-slate-600 hover:bg-slate-100"
                ]}
              >
                <span class="truncate">#{channel.name}</span>
                <span class="text-[10px] uppercase tracking-wide">
                  {channel.type}
                </span>
              </.link>
            </div>
            <div class="mt-8 space-y-2 text-xs text-slate-400">
              <div class="rounded-lg border border-dashed border-slate-200 px-3 py-2">
                Threads
              </div>
              <div class="rounded-lg border border-dashed border-slate-200 px-3 py-2">
                Files
              </div>
            </div>
          </aside>

          <main class="flex-1 px-10 py-10">
            <div class="mx-auto flex h-[calc(100vh-5rem)] max-w-5xl flex-col rounded-3xl border border-slate-200 bg-white shadow-sm">
              <header class="flex items-center justify-between border-b border-slate-200 px-6 py-4">
                <div>
                  <p class="text-xs uppercase tracking-[0.3em] text-slate-400">Channel</p>
                  <h1 class="text-lg font-semibold text-slate-900">#{@channel.name}</h1>
                </div>
                <span class="rounded-full border border-slate-200 px-3 py-1 text-xs font-semibold uppercase tracking-wide text-slate-500">
                  {@channel.type}
                </span>
              </header>

              <section
                id="messages"
                phx-update="stream"
                phx-hook="ChannelMessages"
                data-channel-id={@channel.id}
                class="relative flex-1 overflow-y-auto px-6 py-6"
              >
                <div
                  :for={{id, message} <- @streams.messages}
                  id={id}
                  class="group flex gap-4 border-b border-slate-100 py-4 last:border-b-0"
                >
                  <div class="mt-1 h-10 w-10 flex-shrink-0 rounded-full bg-slate-200 text-center text-sm font-semibold leading-10 text-slate-600">
                    {String.first(message.user.email) |> String.upcase()}
                  </div>
                  <div class="flex-1">
                    <div class="flex items-center gap-3 text-sm">
                      <span class="font-semibold text-slate-900">{message.user.email}</span>
                      <span class="text-xs text-slate-400">
                        {Calendar.strftime(message.inserted_at, "%b %d · %I:%M%p")}
                      </span>
                    </div>
                    <div class="mt-2 text-sm leading-6 text-slate-700">
                      <%= if message.format == :snippet do %>
                        <div class="rounded-xl border border-slate-200 bg-slate-950/5 px-4 py-3">
                          <div class="flex items-center justify-between">
                            <div class="text-xs font-semibold uppercase tracking-wide text-slate-500">
                              {message.snippet.language}
                            </div>
                            <button
                              id={"snippet-copy-#{message.id}"}
                              type="button"
                              phx-hook="SnippetCopy"
                              data-target={"snippet-code-#{message.id}"}
                              class="inline-flex items-center gap-2 rounded-full border border-slate-200 bg-white px-3 py-1 text-[11px] font-semibold text-slate-600 transition hover:border-slate-300"
                            >
                              <.icon name="hero-clipboard" class="h-4 w-4" />
                              <span class="copy-label">Copy</span>
                            </button>
                          </div>
                          <pre class="mt-3 overflow-x-auto rounded-lg bg-slate-950 p-3 text-xs text-slate-100">
                            <code
                              id={"snippet-code-#{message.id}"}
                              phx-hook="SnippetHighlight"
                              class={"language-#{message.snippet.language}"}
                              phx-no-curly-interpolation
                            ><%= message.snippet.code %></code>
                          </pre>
                        </div>
                      <% else %>
                        <div class="whitespace-pre-wrap">
                          {render_message_body(message)}
                        </div>
                      <% end %>
                    </div>
                  </div>
                </div>

                <button
                  type="button"
                  class="new-message-indicator absolute bottom-4 left-1/2 hidden -translate-x-1/2 items-center gap-2 rounded-full bg-slate-900 px-4 py-2 text-xs font-semibold text-white shadow-lg transition hover:bg-slate-800"
                >
                  New messages <.icon name="hero-arrow-down" class="h-4 w-4" />
                </button>
              </section>

              <footer class="border-t border-slate-200 px-6 py-4">
                <.form for={@form} id="message-form" phx-submit="send_message">
                  <div class="relative">
                    <.input
                      field={@form[:body]}
                      type="textarea"
                      label="Message"
                      placeholder="Write a message…"
                      phx-hook="MessageComposer"
                      id="message-body"
                      rows="4"
                      required
                    />
                    <button
                      type="submit"
                      class="absolute bottom-3 right-3 inline-flex items-center justify-center rounded-full bg-slate-900 px-4 py-2 text-xs font-semibold text-white transition hover:bg-slate-800"
                    >
                      Send
                    </button>
                  </div>
                  <p class="mt-2 text-xs text-slate-400">
                    Enter to send · Shift + Enter for a new line
                  </p>
                </.form>
              </footer>
            </div>
          </main>
        </div>
      </div>

      <%= if @show_snippet_modal do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/40 p-6">
          <div class="w-full max-w-2xl rounded-2xl bg-white shadow-xl">
            <div class="flex items-center justify-between border-b border-slate-200 px-6 py-4">
              <div>
                <h2 class="text-lg font-semibold text-slate-900">Create snippet</h2>
                <p class="text-xs text-slate-500">Share a code snippet with context.</p>
              </div>
              <button
                type="button"
                phx-click="close_snippet_modal"
                class="rounded-full border border-slate-200 px-3 py-1 text-xs font-semibold text-slate-600 transition hover:border-slate-300"
              >
                Close
              </button>
            </div>
            <div class="px-6 py-6">
              <.form
                for={@snippet_form}
                id="snippet-form"
                phx-submit="create_snippet"
                phx-change="validate_snippet"
                class="space-y-4"
              >
                <.input field={@snippet_form[:title]} label="Title (optional)" type="text" />
                <.input
                  field={@snippet_form[:language]}
                  type="select"
                  label="Language"
                  options={snippet_languages()}
                  required
                />
                <.input
                  field={@snippet_form[:code]}
                  type="textarea"
                  label="Code"
                  rows="8"
                  required
                />
                <div class="flex justify-end">
                  <button
                    type="submit"
                    class="inline-flex items-center justify-center rounded-full bg-slate-900 px-6 py-2 text-sm font-semibold text-white transition hover:bg-slate-800"
                  >
                    Create snippet
                  </button>
                </div>
              </.form>
            </div>
          </div>
        </div>
      <% end %>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("send_message", %{"message" => params}, socket) do
    current_scope = socket.assigns.current_scope
    channel = socket.assigns.channel

    case Chat.create_message(current_scope.user, channel, params) do
      {:ok, message} ->
        Phoenix.PubSub.broadcast(
          Threadifi.PubSub,
          channel_topic(channel),
          {:message_created, message}
        )

        {:noreply, assign(socket, :form, to_form(Chat.Message.changeset(%Message{}, %{})))}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("open_snippet_modal", _params, socket) do
    {:noreply, assign(socket, :show_snippet_modal, true)}
  end

  @impl true
  def handle_event("close_snippet_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_snippet_modal, false)
     |> assign(:snippet_form, to_form(snippet_changeset(%{}), as: :snippet))}
  end

  @impl true
  def handle_event("validate_snippet", %{"snippet" => params}, socket) do
    {:noreply, assign(socket, :snippet_form, to_form(snippet_changeset(params), as: :snippet))}
  end

  @impl true
  def handle_event("create_snippet", %{"snippet" => params}, socket) do
    current_scope = socket.assigns.current_scope
    channel = socket.assigns.channel

    title =
      params
      |> Map.get("title", "")
      |> String.trim()

    message_body =
      case title do
        "" -> "Code snippet"
        value -> value
      end

    snippet_params = %{
      title: if(title == "", do: nil, else: title),
      language: Map.get(params, "language", ""),
      code: Map.get(params, "code", "")
    }

    case Chat.create_snippet_message(current_scope.user, channel, %{
           message: %{body: message_body, format: :snippet},
           snippet: snippet_params
         }) do
      {:ok, message} ->
        Phoenix.PubSub.broadcast(
          Threadifi.PubSub,
          channel_topic(channel),
          {:message_created, message}
        )

        {:noreply,
         socket
         |> assign(:show_snippet_modal, false)
         |> assign(:snippet_form, to_form(snippet_changeset(%{}), as: :snippet))}

      {:error, changeset} ->
        {:noreply, assign(socket, :snippet_form, to_form(changeset, as: :snippet))}
    end
  end

  @impl true
  def handle_info({:message_created, message}, socket) do
    {:noreply,
     socket
     |> stream_insert(:messages, message)
     |> push_event("new_message", %{message_id: message.id})}
  end

  defp authorize_channel(%{type: :public}, _scope), do: :ok

  defp authorize_channel(%{type: :private} = channel, %{user: user}) do
    if Workspaces.member?(channel, user) do
      :ok
    else
      :unauthorized
    end
  end

  defp channel_topic(channel), do: "channel:#{channel.id}"

  defp snippet_changeset(attrs) do
    {%Snippet{}, %{title: :string, language: :string, code: :string}}
    |> Ecto.Changeset.cast(attrs, [:title, :language, :code])
    |> Ecto.Changeset.validate_required([:language, :code])
  end

  defp snippet_languages do
    [
      {"Elixir", "elixir"},
      {"JavaScript", "javascript"},
      {"TypeScript", "typescript"},
      {"Python", "python"},
      {"Go", "go"},
      {"Ruby", "ruby"},
      {"Rust", "rust"},
      {"SQL", "sql"},
      {"HTML", "html"},
      {"CSS", "css"},
      {"Bash", "bash"}
    ]
  end

  defp render_message_body(%Message{format: :markdown, body: body}) do
    body
    |> Earmark.as_html!(compact_output: true)
    |> HtmlSanitizeEx.basic_html()
    |> Phoenix.HTML.raw()
  end

  defp render_message_body(%Message{body: body}), do: body
end
