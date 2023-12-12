defmodule FedexTest do
  use ExUnit.Case
  doctest Fedex

  alias Fedex.Webfinger
  alias Fedex.Webfinger.Entity
  alias Fedex.Doc

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

    Fedex.Crypto.sign_request(keypair.private.private_key, "myKeyId", :post, host, port, "/")
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
end
