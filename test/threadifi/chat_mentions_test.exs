defmodule Threadifi.ChatMentionsTest do
  use Threadifi.DataCase, async: true

  import Ecto.Query

  alias Threadifi.AccountsFixtures
  alias Threadifi.Chat
  alias Threadifi.Chat.Mention
  alias Threadifi.Repo
  alias Threadifi.Workspaces

  test "extract_mentions returns unique usernames" do
    assert Chat.extract_mentions("hello @alice and @bob and @alice") == ["alice", "bob"]
  end

  test "create_message inserts unique mentions" do
    author = AccountsFixtures.user_fixture(%{email: "author@example.com"})
    mentioned = AccountsFixtures.user_fixture(%{email: "bob@example.com"})

    scope = AccountsFixtures.user_scope_fixture(author)

    {:ok, workspace} =
      Workspaces.create_workspace(scope, %{
        name: "Workspace",
        slug: "workspace-#{System.unique_integer()}"
      })

    {:ok, channel} =
      Workspaces.create_channel(scope, workspace, %{
        name: "General",
        slug: "general-#{System.unique_integer()}",
        type: :public
      })

    {:ok, message} =
      Chat.create_message(author, channel, %{
        body: "hi @bob and again @bob"
      })

    count =
      Mention
      |> where([m], m.message_id == ^message.id and m.mentioned_user_id == ^mentioned.id)
      |> Repo.aggregate(:count)

    assert count == 1
  end
end
