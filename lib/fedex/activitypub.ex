defmodule Fedex.Activitypub do
  alias Fedex.Crypto

  def request_by_actor(actor, keypair, verb, host, path, body) do
    request =
      Crypto.sign_request(keypair.private.private_key, actor.publicKey.id, verb, host, path)

    url = Path.join("https://#{host}", path)
    headers = Map.drop(request.headers, ["(request-target)"])

    IO.inspect(headers, label: "headers")
    Req.request(method: verb, url: url, headers: headers, body: Jason.encode!(body))
  end
end
