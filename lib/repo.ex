defmodule PgRequestReply.Repo do
  use Ecto.Repo,
    otp_app: :pg_request_reply,
    adapter: Ecto.Adapters.Postgres
end
