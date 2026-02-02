defmodule Threadifi.ChatTest do
  use Threadifi.DataCase, async: true

  alias Threadifi.AccountsFixtures
  alias Threadifi.Chat
  alias Threadifi.Chat.{Message, MessageReaction, Snippet}
  alias Threadifi.Repo
  alias Threadifi.Workspaces.{Channel, Workspace}

  defp workspace_fixture(owner) do
    attrs = %{
      name: "Workspace #{System.unique_integer()}",
      slug: "workspace-#{System.unique_integer()}",
      owner_user_id: owner.id
    }

    %Workspace{}
    |> Workspace.changeset(attrs)
    |> Repo.insert!()
  end

  defp channel_fixture(workspace, owner) do
    attrs = %{
      name: "General",
      slug: "general-#{System.unique_integer()}",
      type: :public,
      workspace_id: workspace.id,
      created_by_user_id: owner.id
    }

    %Channel{}
    |> Channel.changeset(attrs)
    |> Repo.insert!()
  end

  test "message changeset requires body, format, channel, and user" do
    changeset = Message.changeset(%Message{}, %{})
    refute changeset.valid?
    assert %{body: ["can't be blank"], format: ["can't be blank"]} = errors_on(changeset)
  end

  test "snippet changeset requires language and code" do
    changeset = Snippet.changeset(%Snippet{}, %{})
    refute changeset.valid?
    assert %{language: ["can't be blank"], code: ["can't be blank"]} = errors_on(changeset)
  end

  test "message reaction changeset requires emoji" do
    changeset = MessageReaction.changeset(%MessageReaction{}, %{})
    refute changeset.valid?
    assert %{emoji: ["can't be blank"]} = errors_on(changeset)
  end

  test "toggle_reaction inserts and deletes reaction" do
    user = AccountsFixtures.user_fixture()
    workspace = workspace_fixture(user)
    channel = channel_fixture(workspace, user)

    {:ok, message} =
      Chat.create_message(user, channel, %{body: "Hello", format: :text})

    {:ok, reaction} = Chat.toggle_reaction(user, message, "👍")
    assert reaction.message_id == message.id

    {:ok, deleted} = Chat.toggle_reaction(user, message, "👍")
    assert deleted.id == reaction.id
  end
end
