defmodule Threadifi.Workspaces.Workspace do
  use Ecto.Schema
  import Ecto.Changeset

  alias Threadifi.Accounts.User
  alias Threadifi.Workspaces.Channel

  schema "workspaces" do
    field :name, :string
    field :slug, :string

    belongs_to :owner_user, User
    has_many :channels, Channel

    timestamps(type: :utc_datetime)
  end

  def changeset(workspace, attrs) do
    workspace
    |> cast(attrs, [:name, :slug])
    |> validate_required([:name, :slug])
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/,
      message: "must be lowercase letters, numbers, or dashes"
    )
    |> unique_constraint(:slug)
  end
end
