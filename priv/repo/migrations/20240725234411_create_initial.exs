defmodule PgRequestReply.Repo.Migrations.CreateInitial do
  use Ecto.Migration

  def up do
    # Migrations as strings to make it easier for non-Ecto/Elixir devs
    execute("""
    create type request_reply_state as enum ('sending', 'processing', 'replied');
    """)

    execute("""
    create unlogged table request_reply (
      id serial primary key,
      channel text not null,
      request text not null,
      response text,
      state request_reply_state not null default 'sending'
    );
    """)
    execute("""
    create or replace function request(p_channel text, p_request text)
    returns int as $$
    declare
      v_id int;
    begin
      -- Check if anyone is listening on the channel
      if not exists (select 1 from pg_stat_activity where wait_event_type = 'Client' and wait_event = 'ClientRead' and lower(query) like '%listen%' || lower(p_channel) || '%') then
        raise exception 'No listeners on channel `%`', p_channel;
      end if;

      -- Insert the request and get the ID
      insert into request_reply (channel, request) values (p_channel, p_request) returning id into v_id;

      -- Notify listeners
      perform pg_notify(p_channel, v_id::text);

      return v_id;
    end;
    $$ language plpgsql;
    """)

    execute("""
    create or replace function await_reply(v_id int)
    returns text as $$
    declare
      v_response text;
    begin
      -- Wait for the response
      loop
        -- Check if the state has changed from 'sending'
        if exists (select 1 from request_reply where id = v_id and state != 'sending') then
          -- Try to acquire the advisory lock
          if pg_try_advisory_lock(v_id) then
            -- Lock acquired, fetch the response and delete the row
            delete from request_reply where id = v_id returning response into v_response;
            -- Release the lock
            perform pg_advisory_unlock(v_id);
            return v_response;
          end if;
        end if;
        -- Wait a bit before trying again
        perform pg_sleep(0.1);
      end loop;
    end;
    $$ language plpgsql;
    """)
  end

  def down do
    execute("drop function request(text, text)")
    execute("drop function await_reply(int)")
    execute("drop table request_reply")
    execute("drop type request_reply_state")
  end
end
