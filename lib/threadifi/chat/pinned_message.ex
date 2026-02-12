defmodule Threadifi.Chat.PinnedMessage do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Threadifi.Accounts.User
  alias Threadifi.Chat.Message
  alias Threadifi.Workspaces.Channel

  schema "pinned_messages" do
    belongs_to :channel, Channel
    belongs_to :message, Message
    belongs_to :pinned_by_user, User

    timestamps(type: :utc_datetime)
  end

  def changeset(pinned_message, attrs) do
    pinned_message
    |> cast(attrs, [])
    |> validate_required([])
    |> unique_constraint(:message_id, name: :pinned_messages_channel_id_message_id_index)
  end
end
