defmodule Threadifi.Repo.Migrations.CreateChatModels do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add :channel_id, references(:channels, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :body, :text, null: false
      add :format, :string, null: false
      add :parent_message_id, references(:messages, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:messages, [:channel_id, :inserted_at])
    create index(:messages, [:parent_message_id])

    create table(:snippets) do
      add :message_id, references(:messages, on_delete: :delete_all), null: false
      add :title, :string
      add :language, :string, null: false
      add :code, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:snippets, [:message_id])

    create table(:message_reactions) do
      add :message_id, references(:messages, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :emoji, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:message_reactions, [:message_id, :user_id, :emoji])
    create index(:message_reactions, [:message_id])
  end
end
