defmodule Threadifi.Chat.Mention do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Threadifi.Accounts.User
  alias Threadifi.Chat.Message

  schema "mentions" do
    belongs_to :message, Message
    belongs_to :mentioned_user, User

    timestamps(type: :utc_datetime)
  end

  def changeset(mention, attrs) do
    mention
    |> cast(attrs, [])
    |> validate_required([])
    |> unique_constraint(:message_id, name: :mentions_message_id_mentioned_user_id_index)
  end
end
