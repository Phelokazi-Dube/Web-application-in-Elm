defmodule FluffyWeb.MigrationJobs do
  @moduledoc "Short-lived server-side progress reports for CBC migration tasks."
  use Agent

  def start_link(_opts), do: Agent.start_link(fn -> %{} end, name: __MODULE__)

  def create(email, filename) do
    id = Base.url_encode64(:crypto.strong_rand_bytes(24), padding: false)
    Agent.update(__MODULE__, &Map.put(&1, id, %{email: email, filename: filename, status: :running}))
    id
  end

  def finish(id, result), do: Agent.update(__MODULE__, &Map.update!(&1, id, fn job -> Map.merge(job, result) end))

  def get(id, email) do
    Agent.get(__MODULE__, fn jobs ->
      case Map.get(jobs, id) do
        %{email: ^email} = job -> {:ok, job}
        _ -> {:error, :not_found}
      end
    end)
  end
end
