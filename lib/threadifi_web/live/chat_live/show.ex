defmodule ThreadifiWeb.ChatLive.Show do
  use ThreadifiWeb, :live_view

  alias Threadifi.Chat
  alias Threadifi.Chat.Message
  alias Threadifi.Chat.Snippet
  alias Threadifi.Workspaces
  alias ThreadifiWeb.Presence

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
      members = Workspaces.list_channel_members(channel)

      if connected?(socket) do
        Phoenix.PubSub.subscribe(Threadifi.PubSub, channel_topic(channel))

        Presence.track(self(), channel_presence_topic(channel), current_scope.user.id, %{
          email: current_scope.user.email,
          joined_at: DateTime.utc_now(:second)
        })
      end

      socket =
        socket
        |> assign(:page_title, channel.name)
        |> assign(:workspace, workspace)
        |> assign(:channels, channels)
        |> assign(:channel, channel)
        |> assign(:channel_members, members)
        |> assign(:mention_query, nil)
        |> assign(:mention_suggestions, [])
        |> assign(:form, to_form(Chat.Message.changeset(%Message{}, %{})))
        |> assign(:show_snippet_modal, false)
        |> assign(:snippet_target, :main)
        |> assign(:snippet_form, to_form(snippet_changeset(%{}), as: :snippet))
        |> assign(:thread_parent, nil)
        |> assign(:thread_form, to_form(Chat.Message.changeset(%Message{}, %{}), as: :thread))
        |> assign(:typing_users, %{})
        |> assign(:online_users, online_users(channel))
        |> assign(:search_query, "")
        |> assign(:search_results, [])
        |> stream(:thread_messages, [])
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
            <div class="mt-8">
              <div class="text-xs uppercase tracking-wide text-slate-500">Online</div>
              <div class="mt-3 space-y-2 text-sm text-slate-600">
                <div
                  :for={user <- @online_users}
                  class="flex items-center justify-between rounded-lg border border-slate-100 px-3 py-2"
                >
                  <span class="truncate">{user.email}</span>
                  <span class="h-2 w-2 rounded-full bg-emerald-400"></span>
                </div>
              </div>
            </div>
          </aside>

          <main class="flex-1 px-10 py-10">
            <div class="mx-auto flex h-[calc(100vh-5rem)] max-w-6xl gap-6">
              <div class="flex h-full flex-1 flex-col rounded-3xl border border-slate-200 bg-white shadow-sm">
                <header class="flex items-center justify-between border-b border-slate-200 px-6 py-4">
                  <div>
                    <p class="text-xs uppercase tracking-[0.3em] text-slate-400">Channel</p>
                    <h1 class="text-lg font-semibold text-slate-900">#{@channel.name}</h1>
                  </div>
                  <div class="flex items-center gap-4">
                    <.form
                      for={to_form(%{"query" => @search_query}, as: :search)}
                      id="search-form"
                      phx-change="search"
                      phx-submit="search_submit"
                      class="relative"
                    >
                      <input
                        type="text"
                        name="search[query]"
                        value={@search_query}
                        placeholder="Search this workspace…"
                        phx-debounce="250"
                        class="w-64 rounded-full border border-slate-200 bg-white px-4 py-2 text-xs text-slate-700 shadow-sm focus:border-slate-300 focus:outline-none"
                      />
                      <%= if @search_results != [] do %>
                        <div class="absolute right-0 mt-2 w-96 rounded-2xl border border-slate-200 bg-white p-3 shadow-xl">
                          <div class="text-xs font-semibold uppercase tracking-wide text-slate-400">
                            Results
                          </div>
                          <div class="mt-3 space-y-3">
                            <div
                              :for={group <- @search_results}
                              class="rounded-xl border border-slate-100 bg-slate-50 px-3 py-2"
                            >
                              <div class="text-xs font-semibold text-slate-600">
                                #{group.channel.name}
                              </div>
                              <div class="mt-2 space-y-2">
                                <.link
                                  :for={message <- group.messages}
                                  navigate={
                                  ~p"/w/#{@workspace.slug}/c/#{group.channel.slug}" <>
                                    "#message-#{message.id}"
                                }
                                  class="block rounded-lg bg-white px-3 py-2 text-xs text-slate-600 transition hover:bg-slate-100"
                                >
                                  <span class="font-semibold text-slate-800">
                                    {message.user.email}
                                  </span>
                                  <span class="ml-2 text-slate-400">
                                    {Calendar.strftime(message.inserted_at, "%b %d · %I:%M%p")}
                                  </span>
                                  <div class="mt-1 line-clamp-2 text-[11px] text-slate-500">
                                    {message_preview(message)}
                                  </div>
                                </.link>
                              </div>
                            </div>
                          </div>
                        </div>
                      <% end %>
                    </.form>
                    <span class="rounded-full border border-slate-200 px-3 py-1 text-xs font-semibold uppercase tracking-wide text-slate-500">
                      {@channel.type}
                    </span>
                  </div>
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
                    <span id={"message-#{message.id}"} class="sr-only"></span>
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
                          <.snippet_card message={message} />
                        <% else %>
                          <div class="whitespace-pre-wrap">
                            {render_message_body(message)}
                          </div>
                        <% end %>
                      </div>
                      <div class="mt-3 flex items-center gap-4 text-xs font-semibold text-slate-500">
                        <button
                          type="button"
                          phx-click="open_thread"
                          phx-value-message-id={message.id}
                          class="transition hover:text-slate-900"
                        >
                          Reply
                        </button>
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
                  <%= if typing_indicator(@typing_users) do %>
                    <div class="mb-2 text-xs text-slate-500">
                      {typing_indicator(@typing_users)}
                    </div>
                  <% end %>
                  <.form
                    for={@form}
                    id="message-form"
                    phx-submit="send_message"
                    phx-change="change_message"
                  >
                    <div class="relative">
                      <.input
                        field={@form[:body]}
                        type="textarea"
                        label="Message"
                        placeholder="Write a message…"
                        phx-hook="MessageComposer"
                        data-snippet-target="main"
                        id="message-body"
                        rows="4"
                        required
                      />
                      <%= if @mention_query && @mention_suggestions != [] do %>
                        <div class="absolute bottom-16 left-3 z-10 w-64 rounded-xl border border-slate-200 bg-white shadow-lg">
                          <ul class="max-h-44 overflow-y-auto p-2 text-sm text-slate-700">
                            <li
                              :for={user <- @mention_suggestions}
                              class="flex items-center justify-between rounded-lg px-2 py-2 transition hover:bg-slate-100"
                            >
                              <button
                                type="button"
                                phx-click="select_mention"
                                phx-value-username={username_for_user(user)}
                                class="flex w-full items-center justify-between text-left"
                              >
                                <span class="font-semibold">@{username_for_user(user)}</span>
                                <span class="text-xs text-slate-400">{user.email}</span>
                              </button>
                            </li>
                          </ul>
                        </div>
                      <% end %>
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

              <aside class="w-full max-w-sm rounded-3xl border border-slate-200 bg-white shadow-sm">
                <%= if @thread_parent do %>
                  <div class="flex h-full flex-col">
                    <header class="flex items-center justify-between border-b border-slate-200 px-5 py-4">
                      <div>
                        <p class="text-xs uppercase tracking-[0.3em] text-slate-400">Thread</p>
                        <h2 class="text-sm font-semibold text-slate-900">
                          Reply to {@thread_parent.user.email}
                        </h2>
                      </div>
                      <button
                        type="button"
                        phx-click="close_thread"
                        class="rounded-full border border-slate-200 px-3 py-1 text-xs font-semibold text-slate-600 transition hover:border-slate-300"
                      >
                        Close
                      </button>
                    </header>

                    <div class="border-b border-slate-100 px-5 py-4">
                      <p class="text-xs text-slate-500">
                        {Calendar.strftime(@thread_parent.inserted_at, "%b %d · %I:%M%p")}
                      </p>
                      <p class="mt-2 text-sm text-slate-700">
                        {render_message_body(@thread_parent)}
                      </p>
                    </div>

                    <section
                      id="thread-messages"
                      phx-update="stream"
                      class="flex-1 overflow-y-auto px-5 py-4"
                    >
                      <div class="hidden text-xs text-slate-400 only:block">
                        No replies yet.
                      </div>
                      <div
                        :for={{id, message} <- @streams.thread_messages}
                        id={id}
                        class="border-b border-slate-100 py-3 last:border-b-0"
                      >
                        <div class="text-xs font-semibold text-slate-600">
                          {message.user.email}
                        </div>
                        <div class="text-[11px] text-slate-400">
                          {Calendar.strftime(message.inserted_at, "%b %d · %I:%M%p")}
                        </div>
                        <div class="mt-2 text-sm text-slate-700">
                          <%= if message.format == :snippet do %>
                            <.snippet_card message={message} compact />
                          <% else %>
                            {render_message_body(message)}
                          <% end %>
                        </div>
                      </div>
                    </section>

                    <footer class="border-t border-slate-200 px-5 py-4">
                      <.form
                        for={@thread_form}
                        id="thread-form"
                        phx-submit="send_thread_message"
                      >
                        <div class="relative">
                          <.input
                            field={@thread_form[:body]}
                            type="textarea"
                            label="Reply"
                            placeholder="Write a reply…"
                            phx-hook="MessageComposer"
                            data-snippet-target="thread"
                            id="thread-body"
                            rows="3"
                            required
                          />
                          <button
                            type="submit"
                            class="absolute bottom-3 right-3 inline-flex items-center justify-center rounded-full bg-slate-900 px-4 py-2 text-xs font-semibold text-white transition hover:bg-slate-800"
                          >
                            Reply
                          </button>
                        </div>
                      </.form>
                    </footer>
                  </div>
                <% else %>
                  <div class="flex h-full flex-col items-center justify-center gap-2 px-6 py-10 text-center">
                    <div class="rounded-full bg-slate-100 px-4 py-2 text-xs font-semibold uppercase tracking-wide text-slate-500">
                      Thread
                    </div>
                    <p class="text-sm text-slate-500">
                      Select a message to view replies.
                    </p>
                  </div>
                <% end %>
              </aside>
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

        {:noreply,
         socket
         |> assign(:mention_query, nil)
         |> assign(:mention_suggestions, [])
         |> assign(:form, to_form(Chat.Message.changeset(%Message{}, %{})))}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("typing", _params, socket) do
    user = socket.assigns.current_scope.user
    channel = socket.assigns.channel

    Phoenix.PubSub.broadcast(
      Threadifi.PubSub,
      channel_topic(channel),
      {:typing, %{user_id: user.id, email: user.email}}
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    results =
      Chat.search_workspace(
        socket.assigns.current_scope,
        socket.assigns.workspace.id,
        query
      )

    {:noreply, assign(socket, :search_query, query) |> assign(:search_results, results)}
  end

  @impl true
  def handle_event("search_submit", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("open_thread", %{"message-id" => message_id}, socket) do
    message_id = String.to_integer(message_id)
    parent = Chat.get_message!(message_id)
    replies = Chat.list_thread_messages(message_id)

    {:noreply,
     socket
     |> assign(:thread_parent, parent)
     |> assign(:thread_form, to_form(Chat.Message.changeset(%Message{}, %{}), as: :thread))
     |> stream(:thread_messages, replies, reset: true)}
  end

  @impl true
  def handle_event("close_thread", _params, socket) do
    {:noreply,
     socket
     |> assign(:thread_parent, nil)
     |> assign(:thread_form, to_form(Chat.Message.changeset(%Message{}, %{}), as: :thread))
     |> stream(:thread_messages, [], reset: true)}
  end

  @impl true
  def handle_event("send_thread_message", %{"thread" => params}, socket) do
    current_scope = socket.assigns.current_scope
    channel = socket.assigns.channel
    parent = socket.assigns.thread_parent

    case parent do
      nil ->
        {:noreply, socket}

      _ ->
        case Chat.create_message(
               current_scope.user,
               channel,
               Map.put(params, "parent_message_id", parent.id)
             ) do
          {:ok, message} ->
            Phoenix.PubSub.broadcast(
              Threadifi.PubSub,
              channel_topic(channel),
              {:message_created, message}
            )

            {:noreply,
             socket
             |> assign(
               :thread_form,
               to_form(Chat.Message.changeset(%Message{}, %{}), as: :thread)
             )}

          {:error, changeset} ->
            {:noreply, assign(socket, :thread_form, to_form(changeset, as: :thread))}
        end
    end
  end

  @impl true
  def handle_event("change_message", %{"message" => params}, socket) do
    body = Map.get(params, "body", "")

    {mention_query, mention_suggestions} =
      mention_suggestions(body, socket.assigns.channel_members)

    changeset = Ecto.Changeset.change(%Message{}, %{body: body})

    {:noreply,
     socket
     |> assign(:mention_query, mention_query)
     |> assign(:mention_suggestions, mention_suggestions)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("select_mention", %{"username" => username}, socket) do
    body = Ecto.Changeset.get_field(socket.assigns.form.source, :body) || ""
    updated_body = replace_trailing_mention(body, username)
    changeset = Ecto.Changeset.change(%Message{}, %{body: updated_body})

    {:noreply,
     socket
     |> assign(:mention_query, nil)
     |> assign(:mention_suggestions, [])
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("open_snippet_modal", params, socket) do
    target =
      case Map.get(params, "target") do
        "thread" -> :thread
        _ -> :main
      end

    {:noreply,
     socket
     |> assign(:snippet_target, target)
     |> assign(:show_snippet_modal, true)}
  end

  @impl true
  def handle_event("close_snippet_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_snippet_modal, false)
     |> assign(:snippet_target, :main)
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

    message_payload =
      case socket.assigns.snippet_target do
        :thread when socket.assigns.thread_parent ->
          %{
            body: message_body,
            format: :snippet,
            parent_message_id: socket.assigns.thread_parent.id
          }

        _ ->
          %{body: message_body, format: :snippet}
      end

    target = socket.assigns.snippet_target

    case Chat.create_snippet_message(current_scope.user, channel, %{
           message: message_payload,
           snippet: snippet_params
         }) do
      {:ok, message} ->
        Phoenix.PubSub.broadcast(
          Threadifi.PubSub,
          channel_topic(channel),
          {:message_created, message}
        )

        socket =
          socket
          |> assign(:show_snippet_modal, false)
          |> assign(:snippet_form, to_form(snippet_changeset(%{}), as: :snippet))
          |> assign(:snippet_target, :main)

        socket =
          if target == :thread do
            assign(
              socket,
              :thread_form,
              to_form(Chat.Message.changeset(%Message{}, %{}), as: :thread)
            )
          else
            assign(socket, :form, to_form(Chat.Message.changeset(%Message{}, %{})))
          end

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :snippet_form, to_form(changeset, as: :snippet))}
    end
  end

  @impl true
  def handle_info({:message_created, message}, socket) do
    socket =
      socket
      |> maybe_insert_thread_message(message)
      |> maybe_insert_main_message(message)
      |> push_event("new_message", %{message_id: message.id})

    {:noreply, socket}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    {:noreply, assign(socket, :online_users, online_users(socket.assigns.channel))}
  end

  @impl true
  def handle_info({:typing, payload}, socket) do
    typing_users =
      socket.assigns.typing_users
      |> Map.put(payload.user_id, %{email: payload.email, at: System.monotonic_time(:millisecond)})

    Process.send_after(self(), :clear_typing, 2_500)

    {:noreply, assign(socket, :typing_users, typing_users)}
  end

  @impl true
  def handle_info(:clear_typing, socket) do
    cutoff = System.monotonic_time(:millisecond) - 2_000

    typing_users =
      socket.assigns.typing_users
      |> Enum.filter(fn {_id, meta} -> meta.at > cutoff end)
      |> Map.new()

    {:noreply, assign(socket, :typing_users, typing_users)}
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

  defp channel_presence_topic(channel), do: "channel:#{channel.id}:presence"

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

  defp online_users(channel) do
    Presence.list(channel_presence_topic(channel))
    |> Enum.map(fn {_user_id, metas} ->
      metas
      |> Map.get(:metas, [])
      |> List.first()
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp typing_indicator(typing_users) do
    emails =
      typing_users
      |> Map.values()
      |> Enum.map(& &1.email)
      |> Enum.take(3)

    case emails do
      [] -> nil
      [one] -> "#{one} is typing…"
      [one, two] -> "#{one} and #{two} are typing…"
      [one, two, three] -> "#{one}, #{two}, and #{three} are typing…"
    end
  end

  defp message_preview(%Message{format: :snippet, snippet: snippet}) do
    snippet.title || String.slice(snippet.code, 0, 120)
  end

  defp message_preview(%Message{body: body}) do
    String.slice(body, 0, 120)
  end

  defp snippet_card(assigns) do
    assigns = assign_new(assigns, :compact, fn -> false end)

    ~H"""
    <div class={[
      "rounded-xl border border-slate-200 bg-slate-950/5 px-4 py-3",
      @compact && "text-xs"
    ]}>
      <div class="flex items-center justify-between">
        <div class="text-xs font-semibold uppercase tracking-wide text-slate-500">
          {@message.snippet.language}
        </div>
        <button
          id={"snippet-copy-#{@message.id}"}
          type="button"
          phx-hook="SnippetCopy"
          data-target={"snippet-code-#{@message.id}"}
          class="inline-flex items-center gap-2 rounded-full border border-slate-200 bg-white px-3 py-1 text-[11px] font-semibold text-slate-600 transition hover:border-slate-300"
        >
          <.icon name="hero-clipboard" class="h-4 w-4" />
          <span class="copy-label">Copy</span>
        </button>
      </div>
      <pre class="mt-3 overflow-x-auto rounded-lg bg-slate-950 p-3 text-xs text-slate-100">
        <code
          id={"snippet-code-#{@message.id}"}
          phx-hook="SnippetHighlight"
          class={"language-#{@message.snippet.language}"}
          phx-no-curly-interpolation
        ><%= @message.snippet.code %></code>
      </pre>
    </div>
    """
  end

  defp maybe_insert_thread_message(socket, message) do
    case socket.assigns.thread_parent do
      %{id: parent_id} when message.parent_message_id == parent_id ->
        stream_insert(socket, :thread_messages, message)

      _ ->
        socket
    end
  end

  defp maybe_insert_main_message(socket, message) do
    if is_nil(message.parent_message_id) do
      stream_insert(socket, :messages, message)
    else
      socket
    end
  end

  defp mention_suggestions(body, members) do
    case extract_mention_query(body) do
      nil ->
        {nil, []}

      query ->
        suggestions =
          members
          |> Enum.filter(fn user ->
            String.starts_with?(username_for_user(user), query)
          end)
          |> Enum.take(6)

        {query, suggestions}
    end
  end

  defp extract_mention_query(body) do
    case Regex.run(~r/(?:^|\s)@([\w\.-]{0,32})$/, body) do
      [_, query] -> String.downcase(query)
      _ -> nil
    end
  end

  defp replace_trailing_mention(body, username) do
    Regex.replace(~r/(?:^|\s)@[\w\.-]{0,32}$/, body, " @#{username}")
    |> String.trim_leading()
  end

  defp username_for_user(user) do
    user.email
    |> String.split("@")
    |> List.first()
    |> String.downcase()
  end
end
