defmodule FluffyWeb.LoginOrProfile do
  use Phoenix.Component

  # If one wishes to, one can pass the relevant data through to the Elm side via flags.
  # I haven't done that but there is no reason why one can't do that.

  attr :oauth_url, :string, required: true
  def login_link(assigns) do
    ~H"""
      <a href={@oauth_url}>Login</a>
    """
  end

  attr :name, :string, required: true
  attr :picture, :string, required: true
  def profile(assigns) do
    ~H"""
        Logged in as <%= @given_name %> <img width="32px" src={@picture} class="rounded-[50%] inline align-middle">
      """
  end

end
