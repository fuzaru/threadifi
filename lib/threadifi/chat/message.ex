defmodule Threadifi.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  alias Threadifi.Accounts.User
  alias Threadifi.Chat.{Mention, Message, MessageReaction, Snippet}
  alias Threadifi.Workspaces.Channel

  schema "messages" do
    field :body, :string
    field :format, Ecto.Enum, values: [:text, :markdown, :snippet]

    belongs_to :channel, Channel
    belongs_to :user, User
    belongs_to :parent_message, Message

    has_one :snippet, Snippet
    has_many :reactions, MessageReaction
    has_many :mentions, Mention

    timestamps(type: :utc_datetime)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:channel_id, :user_id, :body, :format, :parent_message_id])
    |> validate_required([:channel_id, :user_id, :body, :format])
    |> validate_length(:body, min: 1)
  end
end
