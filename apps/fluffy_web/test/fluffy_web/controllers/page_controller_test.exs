defmodule FluffyWeb.PageControllerTest do
  use FluffyWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Center for Biological Control Data Portal"
  end
end
