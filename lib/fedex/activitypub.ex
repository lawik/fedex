defmodule Fedex.Activitypub do
  alias Fedex.Crypto

  def request_by_actor(actor, keypair, verb, host, path, body) do
    full_body = Jason.encode!(body)

    request =
      Crypto.sign_request(
        keypair.private.private_key,
        actor.publicKey.id,
        verb,
        host,
        path,
        full_body
      )

    url = Path.join("https://#{host}", path)

    IO.inspect(request.headers, label: "headers")
    Req.request(method: verb, url: url, headers: request.headers, body: full_body)
  end
end
