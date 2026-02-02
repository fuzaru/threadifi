defmodule Threadifi.Chat.Snippet do
  use Ecto.Schema
  import Ecto.Changeset

  alias Threadifi.Chat.Message

  schema "snippets" do
    field :title, :string
    field :language, :string
    field :code, :string

    belongs_to :message, Message

    timestamps(type: :utc_datetime)
  end

  def changeset(snippet, attrs) do
    snippet
    |> cast(attrs, [:message_id, :title, :language, :code])
    |> validate_required([:message_id, :language, :code])
    |> validate_length(:language, min: 1)
    |> validate_length(:code, min: 1)
    |> unique_constraint(:message_id)
  end
end
