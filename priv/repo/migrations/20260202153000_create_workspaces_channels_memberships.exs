defmodule Threadifi.Repo.Migrations.CreateWorkspacesChannelsMemberships do
  use Ecto.Migration

  def change do
    create table(:workspaces) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :owner_user_id, references(:users, on_delete: :nothing), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:workspaces, [:slug])
    create index(:workspaces, [:owner_user_id])

    create table(:channels) do
      add :workspace_id, references(:workspaces, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :slug, :string, null: false
      add :type, :string, null: false
      add :created_by_user_id, references(:users, on_delete: :nothing), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:channels, [:workspace_id, :slug])
    create index(:channels, [:workspace_id])
    create index(:channels, [:created_by_user_id])

    create table(:channel_memberships) do
      add :channel_id, references(:channels, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :role, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:channel_memberships, [:channel_id, :user_id])
    create index(:channel_memberships, [:user_id])
  end
end
