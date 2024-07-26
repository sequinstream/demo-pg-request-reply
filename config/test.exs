import Config

config :pg_request_reply, PgRequestReply.Repo,
  database: "pg_request_reply_repo_test",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5432,
  pool_size: 10

config :pg_request_reply, env: :test
