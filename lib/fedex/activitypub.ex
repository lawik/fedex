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
    headers = Map.drop(request.headers, ["(request-target)"])

    IO.inspect(headers, label: "headers")
    Req.request(method: verb, url: url, headers: headers, body: full_body)
  end
end
