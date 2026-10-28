defmodule FluffyWeb.ImplementersAccessTest do
  use FluffyWeb.ConnCase

  test "unauthenticated users cannot open the implementers listing", %{conn: conn} do
    conn = get(conn, "/records/implementers")
    assert redirected_to(conn) == "/"
  end

  test "non-admin API requests cannot read or export implementers", %{conn: conn} do
    paths = [
      "/api/Mongodb/document?collection=Implementers",
      "/api/Mongodb/document/search?collection=Implementers&search=test",
      "/api/Mongodb/document/search/export?collection=Implementers",
      "/api/Mongodb/documents/507f1f77bcf86cd799439011?collection=Implementers"
    ]

    for path <- paths do
      response = get(recycle(conn), path)
      assert json_response(response, 403)["error"] ==
               "You are not authorized to access this collection"
    end
  end
end
