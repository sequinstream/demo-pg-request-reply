defmodule PgRequestReply.Server do
  @moduledoc """
  A GenServer that handles notifications for the request-reply mechanism using PostgreSQL.
  """

  use GenServer

  alias PgRequestReply.Repo

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    channel = Keyword.fetch!(opts, :channel)
    test_pid = Keyword.get(opts, :test_pid)
    handle_fn = Keyword.get(opts, :handle_fn, &default_fn/1)
    {:ok, %{channel: channel, test_pid: test_pid, handle_fn: handle_fn}, {:continue, :connect}}
  end

  @impl true
  def handle_continue(:connect, state) do
    with {:ok, conn} <- Postgrex.Notifications.start_link(Repo.config()),
         {:ok, _ref} <- Postgrex.Notifications.listen(conn, state.channel) do
      if state.test_pid do
        send(state.test_pid, {__MODULE__, :started})
      end

      {:noreply, state}
    else
      {:error, reason} ->
        Logger.error("Failed to connect to PostgreSQL: #{inspect(reason)}")
        {:stop, :connection_failed, state}
    end
  end

  @impl true
  def handle_info({:notification, _pid, _ref, channel, payload}, state) when channel == state.channel do
    with {:ok, id} <- parse_notification(payload),
         {:ok, _} <- handle_notification(id, state.handle_fn) do
      {:noreply, state}
    end
  end

  defp handle_notification(id, handle_fn) do
    Repo.transaction(fn ->
      with {:ok, request} <- fetch_request(id),
           {:ok, response} <- process_request(request, handle_fn),
           :ok <- update_response(id, response) do
        :ok
      else
        error ->
          Logger.error("Error processing notification: #{inspect(error)}")
      end
    end)
  end

  defp parse_notification(payload) do
    case Integer.parse(payload) do
      {id, ""} -> {:ok, id}
      _ -> {:error, :invalid_payload}
    end
  end

  @fetch_messages """
  with available_message as (
    select id, request
    from request_reply
    where id = $1 and state = 'sending'
    order by id
    for update skip locked
    limit 1
  )
  update request_reply r
  set state = 'processing'
  from available_message am
    where r.id = am.id
    returning r.request, pg_try_advisory_lock(r.id) as lock_acquired;
  """
  defp fetch_request(id) do
    case Repo.query(@fetch_messages, [id]) do
      {:ok, %{rows: [[request, true]]}} -> {:ok, request}
      {:ok, %{rows: []}} -> {:error, :request_not_found}
      {:error, error} -> {:error, error}
    end
  end

  defp process_request(request, handle_fn) do
    Logger.info("Processing request: #{inspect(request)}")
    handle_fn.(request)
  end

  defp default_fn(request) do
    Logger.info("Using default function to process request: #{inspect(request)}")

    case Req.post("https://api.openai.com/v1/embeddings",
           json: %{
             model: "text-embedding-ada-002",
             input: request
           },
           headers: [
             {"Authorization", "Bearer #{Application.get_env(:pg_request_reply, :open_ai_api_key)}"},
             {"Content-Type", "application/json"}
           ]
         ) do
      {:ok, %{body: %{"data" => [%{"embedding" => embedding}]}}} ->
        {:ok, Jason.encode!(embedding)}

      {:error, error} ->
        Logger.error("Error getting embeddings: #{inspect(error)}")
        {:error, "Failed to get embeddings"}
    end
  end

  @update_response """
  with updated as (
    update request_reply
    set state = 'replied', response = $2
    where id = $1
    returning id
  )
  select pg_advisory_unlock(id) from updated;
  """
  defp update_response(id, response) do
    case Repo.query(@update_response, [id, response]) do
      {:ok, %{num_rows: 1}} -> :ok
      {:ok, %{num_rows: 0}} -> {:error, :request_not_found}
      {:error, error} -> {:error, error}
    end
  end
end
