defmodule Threadifi.Repo do
  use Ecto.Repo,
    otp_app: :threadifi,
    adapter: Ecto.Adapters.Postgres
end
