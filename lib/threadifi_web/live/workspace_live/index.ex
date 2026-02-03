defmodule ThreadifiWeb.WorkspaceLive.Index do
  use ThreadifiWeb, :live_view

  alias Threadifi.Workspaces
  alias Threadifi.Workspaces.Workspace

  @impl true
  def mount(_params, _session, socket) do
    current_scope = socket.assigns.current_scope

    socket =
      socket
      |> assign(:page_title, "Your Workspaces")
      |> assign(:form, to_form(Workspaces.change_workspace(%Workspace{})))
      |> stream(:workspaces, Workspaces.list_workspaces(current_scope))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-screen bg-slate-50 text-slate-900">
        <div class="flex">
          <aside class="w-64 border-r border-slate-200 bg-white px-5 py-6">
            <div class="text-xs uppercase tracking-wide text-slate-500">Workspace Nav</div>
            <div class="mt-4 space-y-2 text-sm text-slate-600">
              <div class="rounded-lg border border-dashed border-slate-200 px-3 py-2">
                Channels
              </div>
              <div class="rounded-lg border border-dashed border-slate-200 px-3 py-2">
                Direct Messages
              </div>
              <div class="rounded-lg border border-dashed border-slate-200 px-3 py-2">
                Threads
              </div>
            </div>
          </aside>

          <main class="flex-1 px-10 py-10">
            <div class="mx-auto max-w-3xl space-y-10">
              <header class="space-y-2">
                <p class="text-xs uppercase tracking-[0.3em] text-slate-400">Dashboard</p>
                <h1 class="text-3xl font-semibold text-slate-900">Your Workspaces</h1>
                <p class="text-sm text-slate-600">
                  Create a workspace to start organizing channels and conversations.
                </p>
              </header>

              <section class="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
                <h2 class="text-sm font-semibold text-slate-800">Create workspace</h2>
                <.form
                  for={@form}
                  id="workspace-form"
                  phx-submit="create_workspace"
                  class="mt-4 space-y-4"
                >
                  <.input field={@form[:name]} label="Workspace name" type="text" required />
                  <.input field={@form[:slug]} label="Workspace slug" type="text" required />

                  <button
                    type="submit"
                    class="inline-flex items-center justify-center rounded-full bg-slate-900 px-6 py-2 text-sm font-semibold text-white transition hover:bg-slate-800"
                  >
                    Create workspace
                  </button>
                </.form>
              </section>

              <section class="space-y-4">
                <div class="flex items-center justify-between">
                  <h2 class="text-sm font-semibold text-slate-800">Your workspaces</h2>
                  <span class="text-xs text-slate-500">Select a workspace to manage channels</span>
                </div>

                <div id="workspaces" phx-update="stream" class="space-y-3">
                  <div class="hidden rounded-xl border border-dashed border-slate-200 bg-white px-4 py-6 text-sm text-slate-500 only:block">
                    No workspaces yet.
                  </div>
                  <div
                    :for={{id, workspace} <- @streams.workspaces}
                    id={id}
                    class="flex items-center justify-between rounded-xl border border-slate-200 bg-white px-4 py-4 shadow-sm"
                  >
                    <div>
                      <div class="text-sm font-semibold text-slate-900">{workspace.name}</div>
                      <div class="text-xs text-slate-500">/{workspace.slug}</div>
                    </div>
                    <.link
                      navigate={~p"/w/#{workspace.slug}"}
                      class="text-sm font-semibold text-slate-700 transition hover:text-slate-900"
                    >
                      Open workspace →
                    </.link>
                  </div>
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
  def handle_event("create_workspace", %{"workspace" => params}, socket) do
    current_scope = socket.assigns.current_scope

    case Workspaces.create_workspace(current_scope, params) do
      {:ok, workspace} ->
        {:noreply,
         socket
         |> stream_insert(:workspaces, workspace)
         |> assign(:form, to_form(Workspaces.change_workspace(%Workspace{})))}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
