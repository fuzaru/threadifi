defmodule Threadifi.Repo.Migrations.CreateMentions do
  use Ecto.Migration

  def change do
    create table(:mentions) do
      add :message_id, references(:messages, on_delete: :delete_all), null: false
      add :mentioned_user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:mentions, [:message_id, :mentioned_user_id])
    create index(:mentions, [:mentioned_user_id])
  end
end
