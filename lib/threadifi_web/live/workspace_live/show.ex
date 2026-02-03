defmodule ThreadifiWeb.WorkspaceLive.Show do
  use ThreadifiWeb, :live_view

  alias Threadifi.Workspaces
  alias Threadifi.Workspaces.Channel

  @impl true
  def mount(%{"workspace_slug" => slug}, _session, socket) do
    current_scope = socket.assigns.current_scope

    case Workspaces.get_workspace_by_slug(current_scope, slug) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Workspace not found.")
         |> push_navigate(to: ~p"/")}

      workspace ->
        socket =
          socket
          |> assign(:page_title, workspace.name)
          |> assign(:workspace, workspace)
          |> assign(:form, to_form(Workspaces.change_channel(%Channel{})))
          |> stream(:channels, Workspaces.list_channels(current_scope, workspace))

        {:ok, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-screen bg-slate-50 text-slate-900">
        <div class="flex">
          <aside class="w-64 border-r border-slate-200 bg-white px-5 py-6">
            <div class="text-xs uppercase tracking-wide text-slate-500">Workspace</div>
            <div class="mt-4 space-y-3">
              <div class="rounded-lg border border-slate-200 bg-slate-50 px-3 py-2 text-sm font-semibold text-slate-800">
                {@workspace.name}
              </div>
              <div class="rounded-lg border border-dashed border-slate-200 px-3 py-2 text-sm text-slate-500">
                Search
              </div>
              <div class="rounded-lg border border-dashed border-slate-200 px-3 py-2 text-sm text-slate-500">
                People
              </div>
            </div>
          </aside>

          <main class="flex-1 px-10 py-10">
            <div class="mx-auto max-w-4xl space-y-10">
              <header class="space-y-2">
                <p class="text-xs uppercase tracking-[0.3em] text-slate-400">Workspace</p>
                <h1 class="text-3xl font-semibold text-slate-900">{@workspace.name}</h1>
                <p class="text-sm text-slate-600">
                  Channels stay organized by purpose, privacy, or workflow.
                </p>
              </header>

              <section class="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
                <h2 class="text-sm font-semibold text-slate-800">Create channel</h2>
                <.form
                  for={@form}
                  id="channel-form"
                  phx-submit="create_channel"
                  class="mt-4 space-y-4"
                >
                  <div class="grid gap-4 md:grid-cols-2">
                    <.input field={@form[:name]} label="Channel name" type="text" required />
                    <.input field={@form[:slug]} label="Channel slug" type="text" required />
                  </div>
                  <.input
                    field={@form[:type]}
                    type="select"
                    label="Channel type"
                    options={[Public: :public, Private: :private]}
                    required
                  />

                  <button
                    type="submit"
                    class="inline-flex items-center justify-center rounded-full bg-slate-900 px-6 py-2 text-sm font-semibold text-white transition hover:bg-slate-800"
                  >
                    Create channel
                  </button>
                </.form>
              </section>

              <section class="space-y-4">
                <div class="flex items-center justify-between">
                  <h2 class="text-sm font-semibold text-slate-800">Channels</h2>
                  <span class="text-xs text-slate-500">
                    Public channels are visible to everyone in the workspace.
                  </span>
                </div>

                <div id="channels" phx-update="stream" class="space-y-3">
                  <div class="hidden rounded-xl border border-dashed border-slate-200 bg-white px-4 py-6 text-sm text-slate-500 only:block">
                    No channels yet.
                  </div>
                  <.link
                    :for={{id, channel} <- @streams.channels}
                    id={id}
                    navigate={~p"/w/#{@workspace.slug}/c/#{channel.slug}"}
                    class="flex items-center justify-between rounded-xl border border-slate-200 bg-white px-4 py-4 shadow-sm transition hover:border-slate-300"
                  >
                    <div>
                      <div class="text-sm font-semibold text-slate-900">#{channel.name}</div>
                      <div class="text-xs text-slate-500">/{channel.slug}</div>
                    </div>
                    <div class="text-xs font-semibold uppercase tracking-wide text-slate-500">
                      {channel.type}
                    </div>
                  </.link>
                </div>
              </section>
            </div>
          </main>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("create_channel", %{"channel" => params}, socket) do
    current_scope = socket.assigns.current_scope
    workspace = socket.assigns.workspace

    case Workspaces.create_channel(current_scope, workspace, params) do
      {:ok, channel} ->
        {:noreply,
         socket
         |> stream_insert(:channels, channel)
         |> assign(:form, to_form(Workspaces.change_channel(%Channel{})))}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
