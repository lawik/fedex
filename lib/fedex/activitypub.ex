defmodule Fedex.Activitypub do
  alias Fedex.Crypto
  alias Fedex.Crypto.HttpSigning

  def request_by_actor(actor, keypair, verb, host, path, body) do
    full_body = Jason.encode!(body)

    headers =
      HttpSigning.new(host, verb, path, HttpSigning.datetime_now())
      |> HttpSigning.digest(full_body)
      |> HttpSigning.sign(keypair.private)
      |> HttpSigning.verify!(keypair.public)
      |> HttpSigning.to_headers(actor.publicKey.id)

    url = Path.join("https://#{host}", path)

    IO.inspect(headers, label: "headers")
    [method: verb, url: url, headers: headers, body: full_body]
  end

  def request(opts), do: Req.request(opts)
end
