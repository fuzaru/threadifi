defmodule Threadifi.Chat.MessageReaction do
  use Ecto.Schema
  import Ecto.Changeset

  alias Threadifi.Accounts.User
  alias Threadifi.Chat.Message

  schema "message_reactions" do
    field :emoji, :string

    belongs_to :message, Message
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  def changeset(reaction, attrs) do
    reaction
    |> cast(attrs, [:message_id, :user_id, :emoji])
    |> validate_required([:message_id, :user_id, :emoji])
    |> validate_length(:emoji, min: 1)
    |> unique_constraint(:emoji, name: :message_reactions_message_id_user_id_emoji_index)
  end
end
