import Config

config :pg_request_reply, PgRequestReply.Repo,
  database: "pg_request_reply_repo",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5432,
  pool_size: 10

config :pg_request_reply,
  ecto_repos: [PgRequestReply.Repo]

import_config "#{config_env()}.exs"
