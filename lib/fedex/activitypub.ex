defmodule Fedex.Activitypub do
  alias Fedex.Crypto

  def request_by_actor(actor, keypair, verb, host, path, body) do
    request =
      Crypto.sign_request(keypair.private.private_key, actor.publicKey.id, verb, host, path)

    url = Path.join("https://#{host}", path)
    Req.request(method: verb, url: url, headers: request.headers, body: Jason.encode!(body))
  end
end
