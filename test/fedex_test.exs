defmodule Fedex.FedexTest do
  use ExUnit.Case
  doctest Fedex

  alias Fedex.Store.ETS, as: Doc
  alias Fedex.Activitypub
  alias Fedex.Activitystreams

  defmodule DocFetch do
    def set_1(key, value), do: Doc.set(:signed_actor_1, key, value)

    def fetcher_1(key) do
      Doc.get(:signed_actor_1, key)
    end

    def set_2(key, value), do: Doc.set(:signed_actor_2, key, value)

    def fetcher_2(key) do
      Doc.get(:signed_actor_2, key)
    end
  end

  defmodule BasicInbox do
    alias Plug.Conn
    def init(o), do: o

    def call(conn, _opts) do
      case conn.method do
        "POST" ->
          conn
          |> Conn.send_resp(202, "Got it")
          |> Conn.halt()

        _ ->
          conn
          |> Conn.send_resp(404, "Not found")
          |> Conn.halt()
      end
    end
  end

  defmodule MinimalFediPlug1 do
    use Plug.Builder
    plug(Fedex.Plugs.Webfinger, fetch: &DocFetch.fetcher_1/1)
    plug(Fedex.Plugs.Activitystreams, fetch: &DocFetch.fetcher_1/1)

    plug(Plug.Parsers,
      parsers: [:json],
      json_decoder: Jason,
      body_reader: {Fedex.Plugs.HttpSigned, :alt_read_body, []}
    )

    plug(Fedex.Plugs.HttpSigned)
    plug(Fedex.Plugs.Inbox)
    plug(BasicInbox)
  end

  defmodule MinimalFediPlug2 do
    use Plug.Builder
    plug(Fedex.Plugs.Webfinger, fetch: &DocFetch.fetcher_2/1)
    plug(Fedex.Plugs.Activitystreams, fetch: &DocFetch.fetcher_2/1)

    plug(Plug.Parsers,
      parsers: [:json],
      json_decoder: Jason,
      body_reader: {Fedex.Plugs.HttpSigned, :alt_read_body, []}
    )

    plug(Fedex.Plugs.HttpSigned)
    plug(Fedex.Plugs.Inbox)
    plug(BasicInbox)
  end

  test "two servers fedding" do
    # Server 1
    port_1 = 44447
    host_1 = "localhost"
    proto_1 = "http"
    url_1 = "#{proto_1}://#{host_1}:#{port_1}"
    table_name_1 = :signed_actor_1

    # Server 2
    port_2 = 44448
    host_2 = "localhost"
    proto_2 = "http"
    url_2 = "#{proto_2}://#{host_2}:#{port_2}"
    table_name_2 = :signed_actor_2
    {:ok, _pid} = Doc.start_link(table_name_1)
    {:ok, _pid} = Doc.start_link(table_name_2)

    keypair_1 = Fedex.Crypto.generate_keypair()
    keypair_2 = Fedex.Crypto.generate_keypair()

    actor_1 =
      Fedex.Activitystreams.actor(
        url_1,
        "lawik",
        "Person",
        "lawik",
        "inbox",
        "main-key",
        keypair_1.public.public_key
      )

    actor_2 =
      Fedex.Activitystreams.actor(
        url_2,
        "kiwal",
        "Person",
        "kiwal",
        "inbox",
        "main-key",
        keypair_2.public.public_key
      )

    Doc.set(table_name_1, "/lawik", actor_1 |> Jason.encode!())
    Doc.set(table_name_2, "/kiwal", actor_2 |> Jason.encode!())

    {:ok, _pid} =
      Bandit.start_link(
        port: port_1,
        plug: MinimalFediPlug1
      )

    {:ok, _pid} =
      Bandit.start_link(
        port: port_2,
        plug: MinimalFediPlug2
      )

    obj_id_1 = System.unique_integer([:positive, :monotonic])

    note_object_1 =
      Activitystreams.new_note_object(
        url_1,
        "note-#{obj_id_1}",
        actor_1.id,
        DateTime.utc_now(),
        "bad-reply-reference?",
        "Some great content from an automation.",
        Activitystreams.to_public()
      )

    create_1 =
      Activitystreams.new(url_1, "create-#{obj_id_1}", "Create", actor_1.id, note_object_1)

    request_1 =
      Activitypub.request_by_actor(actor_1, keypair_1, :post, host_2, port_2, "/inbox", create_1)

    assert {:ok, %{status: status, body: body}} = Activitypub.request(request_1)

    assert status < 300
    assert status < 300
    assert "Got it" = body
  end
end
