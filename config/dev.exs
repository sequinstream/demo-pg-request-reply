import Config

config :pg_request_reply, env: :dev

if File.exists?("config/dev.secret.exs"), do: import_config("dev.secret.exs")
