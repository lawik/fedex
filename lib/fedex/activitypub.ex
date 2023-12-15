defmodule Fedex.Activitypub do
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

  def get_actor_public_key("https://" <> key_id) do
    # Remove fragment if it matters
    [url | []] = String.split(key_id, "#")

    with {:ok, %{body: body}} <- Req.get(url),
         %{"publicKey" => %{"id" => ^key_id, "publicKeyPem" => public_key_pem}} <- body do
      {:ok, public_key_pem}
    end
  end

  def request(opts), do: Req.request(opts)
end
