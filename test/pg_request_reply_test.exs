defmodule PgRequestReplyTest do
  use ExUnit.Case

  alias PgRequestReply.Repo
  alias PgRequestReply.Server

  @channel "test_channel"
  setup do
    test_pid = self()

    handle_fn = fn request ->
      send(test_pid, :handled)
      {:ok, "Processed: #{request}"}
    end

    # Start the Server (handler) process
    Repo.query("delete from request_reply")
    _pid = start_supervised!({Server, [channel: @channel, test_pid: self(), handle_fn: handle_fn]})
    assert_receive {Server, :started}, 1000

    on_exit(fn ->
      Repo.query("delete from request_reply")
    end)

    :ok
  end

  test "end-to-end request-reply flow" do
    request = "Hello, World!"
    expected_response = "Processed: Hello, World!"

    # Use the request_reply function defined in the migration
    {:ok, %{rows: [[request_id]]}} = Repo.query("SELECT request($1, $2)", [@channel, request])
    {:ok, %{rows: [[result]]}} = Repo.query("SELECT await_reply($1)", [request_id])

    assert_receive :handled, 1000
    assert result == expected_response
  end

  test "raises when no listeners are available" do
    channel = "nonexistent_channel"
    request = "This should fail"

    assert_raise Postgrex.Error, ~r/No listeners on channel/, fn ->
      Repo.query!("SELECT request($1, $2)", [channel, request])
    end
  end
end
