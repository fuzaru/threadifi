defmodule Threadifi.Repo.Migrations.AddMessageSearchIndexes do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")

    execute(
      "CREATE INDEX IF NOT EXISTS messages_body_trgm_idx ON messages USING gin (body gin_trgm_ops)"
    )

    execute(
      "CREATE INDEX IF NOT EXISTS snippets_title_trgm_idx ON snippets USING gin (title gin_trgm_ops)"
    )

    execute(
      "CREATE INDEX IF NOT EXISTS snippets_code_trgm_idx ON snippets USING gin (code gin_trgm_ops)"
    )
  end
end
