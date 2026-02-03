defmodule ThreadifiWeb.PageControllerTest do
  use ThreadifiWeb.ConnCase

  test "GET / redirects unauthenticated users", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/users/log-in"
  end
end
