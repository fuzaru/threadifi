defmodule Threadifi.Workspaces.Channel do
  use Ecto.Schema
  import Ecto.Changeset

  alias Threadifi.Accounts.User
  alias Threadifi.Workspaces.{ChannelMembership, Workspace}

  schema "channels" do
    field :name, :string
    field :slug, :string
    field :type, Ecto.Enum, values: [:public, :private]

    belongs_to :workspace, Workspace
    belongs_to :created_by_user, User
    has_many :memberships, ChannelMembership

    timestamps(type: :utc_datetime)
  end

  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [:workspace_id, :name, :slug, :type, :created_by_user_id])
    |> validate_required([:workspace_id, :name, :slug, :type, :created_by_user_id])
    |> unique_constraint(:slug, name: :channels_workspace_id_slug_index)
  end
end
