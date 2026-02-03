defmodule Threadifi.Repo.Migrations.CreatePinnedMessages do
  use Ecto.Migration

  def change do
    create table(:pinned_messages) do
      add :channel_id, references(:channels, on_delete: :delete_all), null: false
      add :message_id, references(:messages, on_delete: :delete_all), null: false
      add :pinned_by_user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:pinned_messages, [:channel_id, :message_id])
    create index(:pinned_messages, [:channel_id])
  end
end
