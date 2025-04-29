defmodule FluffyWeb.LoginOrProfile do
  use Phoenix.Component

  # If one wishes to, one can pass the relevant data through to the Elm side via flags.
  # I haven't done that but there is no reason why one can't do that.

  attr :oauth_url, :string, required: true
  def login_link(assigns) do
    ~H"""
      <a href={@oauth_url} class="nav-link">LOGIN</a>
    """
  end

  attr :name, :string, required: true
  attr :picture, :string, required: true
  def profile(assigns) do
    title = "Logged in as #{assigns.name}"
    ~H"""
        <a href="/logout" class="nav-link">LOGOUT</a>
        <img width="32px" src={@picture} title={title} class="rounded-[50%] inline align-middle">
      """
  end

end
