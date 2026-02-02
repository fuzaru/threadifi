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
    |> cast(attrs, [:name, :slug, :owner_user_id])
    |> validate_required([:name, :slug, :owner_user_id])
    |> unique_constraint(:slug)
  end
end
