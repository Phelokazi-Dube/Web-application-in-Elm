defmodule FluffyWeb.ContactController do
  use FluffyWeb, :controller

  alias Fluffy.{Mailer, Email}

  def create(conn, params) do
    name = params["name"]
    surname = params["surname"]
    email = params["email"]
    message = params["message"]

    email_struct =
      Email.contact_email(name, surname, email, message)

    case Mailer.deliver(email_struct) do
      {:ok, _} ->
        json(conn, %{status: "sent"})

      {:error, reason} ->
        conn
        |> put_status(500)
        |> json(%{error: inspect(reason)})
    end
  end
end
