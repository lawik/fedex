defmodule FedexTest do
  use ExUnit.Case
  doctest Fedex

  alias Fedex.Webfinger
  alias Fedex.Webfinger.Entity
  alias Fedex.Doc
  alias Fedex.Crypto.HttpSigning
  alias Fedex.Activitypub

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

    {:ok, _pid} = Bandit.start_link(port: port, plug: {Fedex.Webfinger.Plug, fetch: fetcher})

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
      HttpSigning.new(host, :post, "/", HttpSigning.datetime_now())
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
      |> IO.inspect(label: "signature")

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
      IO.inspect(key, label: "getting")
      Doc.get(table_name, key)
    end

    {:ok, _pid} =
      Bandit.start_link(port: port, plug: {Fedex.Activitystreams.Plug, fetch: fetcher})

    assert {:ok, %{body: %{"id" => "http://localhost:44445/lawik"}}} = Req.get("#{url}/lawik")
  end

  defmodule MinimalFediPlug do
    use Plug.Builder
    plug Fedex.Webfinger.Plug, fetcher: &Fed.fetch_fingers/1
    plug Fedex.Activitystreams.Plug, fetcher: &Fed.fetch_fingers/1
  end
  defp http_signed_plug(%Plug.Conn{} = conn, _opts) do
    conn
    |> Fedex.Activitystreams.Plug.call([])
    |> then(fn conn ->

    end)
  end

  test "two servers fedding" do
    port_1 = 44447
    host_1 = "localhost"
    proto_1 = "http"
    url_1 = "#{proto_1}://#{host_1}:#{port_1}"
    table_name_1 = :signed_actor_1
    {:ok, _pid} = Doc.start_link(table_name_1)

    keypair_1 = Fedex.Crypto.generate_keypair()

    create_headers_1 =
      HttpSigning.new(host_1, :post, "/", HttpSigning.datetime_now())
      |> HttpSigning.digest("mah body")
      |> HttpSigning.sign(keypair_1.private)
      |> HttpSigning.verify!(keypair_1.public)
      |> HttpSigning.to_headers("myKeyId")

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

    Doc.set(table_name_1, "/lawik", actor_1 |> Jason.encode!())

    fetcher_1 = fn key ->
      IO.inspect(key, label: "getting in fetcher_1")
      Doc.get(table_name_1, key)
    end

    {:ok, _pid} =
      Bandit.start_link(port: port_1, plug: {Fedex.Activitystreams.Plug, fetch: fetcher_1})

      port_2 = 44448
      host_2 = "localhost"
      proto_2 = "http"
      url_2 = "#{proto_2}://#{host_2}:#{port_2}"
      table_name_2 = :signed_actor_2
      {:ok, _pid} = Doc.start_link(table_name_2)

      keypair_2 = Fedex.Crypto.generate_keypair()

      actor_2 =
        Fedex.Activitystreams.actor(
          url_2,
          "lawik",
          "Person",
          "lawik",
          "inbox",
          "main-key",
          keypair_2.public.public_key
        )

      Doc.set(table_name_2, "/lawik", actor_2 |> Jason.encode!())

      fetcher_2 = fn key ->
        IO.inspect(key, label: "getting in fetcher_2")
        Doc.get(table_name_2, key)
      end

      {:ok, _pid} =
        Bandit.start_link(port: port_2, plug: {Fedex.Activitystreams.Plug, fetch: fetcher_2})

      assert {:ok, %{status}}Activitypub.request(create_headers_1)
  end
end
