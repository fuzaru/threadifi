defmodule Threadifi.Workspaces.ChannelMembership do
  use Ecto.Schema
  import Ecto.Changeset

  alias Threadifi.Accounts.User
  alias Threadifi.Workspaces.Channel

  schema "channel_memberships" do
    field :role, Ecto.Enum, values: [:admin, :member]

    belongs_to :channel, Channel
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:channel_id, :user_id, :role])
    |> validate_required([:channel_id, :user_id, :role])
    |> unique_constraint(:channel_id, name: :channel_memberships_channel_id_user_id_index)
  end
end
