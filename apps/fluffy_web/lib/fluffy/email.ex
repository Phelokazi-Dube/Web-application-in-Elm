defmodule Fluffy.Email do
  import Swoosh.Email

  def contact_email(name, surname, sender_email, message_body) do
    new()
    |> to("phelokazidube@gmail.com")
    |> from({"FluffyWeb Contact", System.get_env("FROM_EMAIL")})
    |> reply_to(sender_email)
    |> subject("New Contact Message")
    |> html_body("""
    <h3>New message from #{name} #{surname}</h3>
    <p><strong>Email:</strong> #{sender_email}</p>
    <p><strong>Message:</strong></p>
    <p>#{message_body}</p>
    """)
    |> text_body("""
    New message from #{name} #{surname}

    Email: #{sender_email}

    Message:
    #{message_body}
    """)
  end
end
