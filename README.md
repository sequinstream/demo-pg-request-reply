> [!IMPORTANT]
> This proof-of-concept does **not** demo [Sequin](github.com/sequinstream/sequin), just some fun Postgres features.

# `demo-pg-request-reply`

`demo-pg-request-reply` is a proof-of-concept implementation of a request-reply mechanism using Postgres. It's an implementation of the method described in [this blog post](#).

If you've ever wanted to see all the Postgres goodies come together in one use case, you've come to the right place!

It demonstrates how to use Postgres for synchronous communication between services, leveraging LISTEN/NOTIFY, advisory locks, and unlogged tables.

## How to run

1. Ensure you have Elixir and Postgres installed on your system.

2. Clone the repository.

3. Set up the database:

```
mix ecto.create
mix ecto.migrate
```

4. Start the application:

```
iex -S mix
```

5. You can send messages like so:

```elixir
{:ok, %{rows: [[request_id]]}} = Repo.query("SELECT request($1, $2)", ["some_channel", "my_request"])
{:ok, %{rows: [[result]]}} = Repo.query("SELECT await_reply($1)", [request_id])

IO.inspect(result)
```

You can modify the handler in the `lib/pg_request_reply/server.ex` file to see how requests are processed.

## Key files

The implementation consists of several important files:

- [Server implementation](lib/pg_request_reply/server.ex): Contains the GenServer that handles notifications and processes requests.
- [Database migrations](priv/repo/migrations/20240725234411_create_initial.exs): Sets up the necessary database structure and functions.
- [Tests](test/pg_request_reply_test.exs): Demonstrates the usage and provides an end-to-end test of the request-reply mechanism.

## How It Works

[Read more in the corresponding blog post](#).

1. A client sends a request using a `request` function.
2. The request is stored in the `request_reply` table and a notification is sent.
3. The server listening for notifications processes the request. It responds by writing back to the `request_reply` table.
4. The client awaits the response using the `await_reply` function.

This approach overcomes limitations of Postgres's NOTIFY/LISTEN, such as payload size restrictions and the inability to block on replies.
