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
alias Threadifi.Workspaces

defmodule Threadifi.Seeds do
  def ensure_demo_workspace do
    case Repo.one(from u in User, order_by: [asc: u.id], limit: 1) do
      nil ->
        :noop

      user ->
        workspace =
          case Workspaces.get_workspace_by_slug("demo") do
            nil ->
              {:ok, workspace} =
                Workspaces.create_workspace(%{
                  name: "Demo Workspace",
                  slug: "demo",
                  owner_user_id: user.id
                })

              workspace

            workspace ->
              workspace
          end

        ensure_channel(workspace, user, "General", "general")
        ensure_channel(workspace, user, "Snippets", "snippets")
    end
  end

  defp ensure_channel(workspace, user, name, slug) do
    existing =
      Threadifi.Workspaces.list_channels(workspace)
      |> Enum.find(fn channel -> channel.slug == slug end)

    if is_nil(existing) do
      Workspaces.create_channel(workspace, %{
        name: name,
        slug: slug,
        type: :public,
        created_by_user_id: user.id
      })
    end
  end
end

Threadifi.Seeds.ensure_demo_workspace()
