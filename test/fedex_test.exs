defmodule FedexTest do
  use ExUnit.Case
  doctest Fedex

  alias Fedex.Webfinger
  alias Fedex.Webfinger.Entity
  alias Fedex.Store.ETS, as: Doc
  alias Fedex.Crypto.HttpSigning
  alias Fedex.Activitypub
  alias Fedex.Activitystreams

  test "webfinger server" do
    port = 44444
    host = "localhost"
    proto = "http"
    url = "#{proto}://#{host}:#{port}"

    entity =
      Webfinger.ent("lars@underjord.io", [
        Webfinger.link("self", "application/activity+json", "#{url}/lawik")
      ])

    table_name = :webfinger_test_1
    {:ok, _pid} = Doc.start_link(table_name)

    json_doc = entity |> Entity.as_map() |> Jason.encode!()
    Doc.set(table_name, entity.subject, json_doc)
    assert json_doc == Doc.get(table_name, entity.subject)

    fetcher = fn key ->
      Doc.get(table_name, key)
    end

    {:ok, _pid} = Bandit.start_link(port: port, plug: {Fedex.Plugs.Webfinger, fetch: fetcher})

    assert {:ok,
            %{
              "subject" => "acct:lars@underjord.io",
              "links" => [%{"rel" => "self", "type" => _, "href" => _}]
            }} = Webfinger.fetch(url, "lars@underjord.io")
  end

  test "signed actor" do
    port = 44445
    host = "localhost"
    proto = "http"
    url = "#{proto}://#{host}:#{port}"
    table_name = :signed_actor
    {:ok, _pid} = Doc.start_link(table_name)

    keypair = Fedex.Crypto.generate_keypair()

    headers =
      HttpSigning.new(host, port, :post, "/", HttpSigning.datetime_now())
      |> HttpSigning.digest("mah body")
      |> HttpSigning.sign(keypair.private)
      |> HttpSigning.verify!(keypair.public)
      |> HttpSigning.to_headers("myKeyId")
      # Fedex.Crypto.sign_request(
      #   keypair.private.private_key,
      #   "myKeyId",
      #   :post,
      #   "#{host}:#{port}",
      #   "/",
      #   "mah body"
      # )

    actor =
      Fedex.Activitystreams.actor(
        url,
        "lawik",
        "Person",
        "lawik",
        "inbox",
        "main-key",
        keypair.public.public_key
      )

    Doc.set(table_name, "/lawik", actor |> Jason.encode!())

    fetcher = fn key ->
      Doc.get(table_name, key)
    end

    {:ok, _pid} =
      Bandit.start_link(port: port, plug: {Fedex.Plugs.Activitystreams, fetch: fetcher})

    assert {:ok, %{body: %{"id" => "http://localhost:44445/lawik"}}} = Req.get("#{url}/lawik")
  end

  defmodule DocFetch do
    def set_1(key, value), do: Doc.set(:signed_actor_1, key, value)

    def fetcher_1(key) do
      IO.inspect(key, label: "getting in fetcher_1")
      Doc.get(:signed_actor_1, key)
    end

    def set_2(key, value), do: Doc.set(:signed_actor_2, key, value)

    def fetcher_2(key) do
      IO.inspect(key, label: "getting in fetcher_2")
      Doc.get(:signed_actor_2, key)
    end
  end

  defmodule BasicInbox do
    alias Plug.Conn
    def init(o), do: o

    def call(conn, opts) do
      IO.inspect(conn.method, lable: "basic inbox")

      case conn.method do
        "POST" ->
          conn
          |> Plug.Conn.send_resp(202, "Got it")
          |> Plug.Conn.halt()

        _ ->
          conn
          |> Plug.Conn.send_resp(404, "Not found")
          |> Plug.Conn.halt()
      end
    end
  end

  defmodule MinimalFediPlug1 do
    use Plug.Builder
    plug(Fedex.Plugs.Webfinger, fetch: &DocFetch.fetcher_1/1)
    plug(Fedex.Plugs.Activitystreams, fetch: &DocFetch.fetcher_1/1)
    plug(Fedex.Plugs.HttpSigned)
    plug(BasicInbox)
  end

  defmodule MinimalFediPlug2 do
    use Plug.Builder
    plug(Fedex.Plugs.Webfinger, fetch: &DocFetch.fetcher_2/1)
    plug(Fedex.Plugs.Activitystreams, fetch: &DocFetch.fetcher_2/1)
    plug(Fedex.Plugs.HttpSigned)
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

    IO.inspect(request_1, label: "request 1")
    assert {:ok, %{status: status, body: body}} = Activitypub.request(request_1)
    unless status < 300 do
      IO.puts(body)
    end
    assert status < 300
    assert "Got it" = body
  end
end
