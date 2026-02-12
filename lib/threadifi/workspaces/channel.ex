defmodule Threadifi.Workspaces.Channel do
  @moduledoc false
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
    |> cast(attrs, [:name, :slug, :type])
    |> validate_required([:name, :slug, :type])
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/,
      message: "must be lowercase letters, numbers, or dashes"
    )
    |> unique_constraint(:slug, name: :channels_workspace_id_slug_index)
  end
end
