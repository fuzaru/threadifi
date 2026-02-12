defmodule ThreadifiWeb.Presence do
  @moduledoc false
  use Phoenix.Presence,
    otp_app: :threadifi,
    pubsub_server: Threadifi.PubSub
end
