defmodule PgRequestReply.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      if Application.get_env(:pg_request_reply, :env) == :test do
        [
          PgRequestReply.Repo
        ]
      else
        [
          PgRequestReply.Repo,
          {PgRequestReply.Server, [channel: "embeddings"]}
        ]
      end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PgRequestReply.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
