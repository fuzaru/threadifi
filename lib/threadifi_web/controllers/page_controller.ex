defmodule ThreadifiWeb.PageController do
  use ThreadifiWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
