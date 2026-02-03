# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Threadifi.Repo.insert!(%Threadifi.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

import Ecto.Query, warn: false

alias Threadifi.Accounts.User
alias Threadifi.Repo
alias Threadifi.Chat
alias Threadifi.Workspaces
alias Threadifi.Accounts.Scope

defmodule Threadifi.Seeds do
  def ensure_demo_workspace do
    case Repo.one(from u in User, order_by: [asc: u.id], limit: 1) do
      nil ->
        :noop

      user ->
        scope = Scope.for_user(user)

        workspace =
          case Workspaces.get_workspace_by_slug(scope, "threadifi-demo") do
            nil ->
              {:ok, workspace} =
                Workspaces.create_workspace(scope, %{
                  name: "Threadifi Demo",
                  slug: "threadifi-demo"
                })

              workspace

            workspace ->
              workspace
          end

        {:ok, general} = ensure_channel(workspace, scope, "General", "general")
        {:ok, snippets} = ensure_channel(workspace, scope, "Snippets", "snippets")

        seed_messages(user, general, snippets)
    end
  end

  defp ensure_channel(workspace, scope, name, slug) do
    existing =
      Threadifi.Workspaces.list_channels(workspace)
      |> Enum.find(fn channel -> channel.slug == slug end)

    if is_nil(existing) do
      Workspaces.create_channel(scope, workspace, %{
        name: name,
        slug: slug,
        type: :public
      })
    else
      {:ok, existing}
    end
  end

  defp seed_messages(user, general, snippets) do
    existing =
      from(m in Chat.Message,
        where: m.channel_id in [^general.id, ^snippets.id],
        select: count(m.id)
      )
      |> Repo.one()

    if existing == 0 do
      Chat.create_message(user, general, %{
        body: "Welcome to Threadifi! Drop a note or open a thread."
      })

      Chat.create_message(user, general, %{
        body: "Try /standup or /review to get started.",
        format: :markdown
      })

      Chat.create_snippet_message(user, snippets, %{
        message: %{body: "Snippet: hello world", format: :snippet},
        snippet: %{
          title: "Hello World (Elixir)",
          language: "elixir",
          code: "IO.puts(\"Hello, Threadifi!\")"
        }
      })
    end
  end
end

Threadifi.Seeds.ensure_demo_workspace()
