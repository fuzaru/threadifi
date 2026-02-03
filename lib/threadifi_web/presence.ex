defmodule ThreadifiWeb.Presence do
  use Phoenix.Presence,
    otp_app: :threadifi,
    pubsub_server: Threadifi.PubSub
end
