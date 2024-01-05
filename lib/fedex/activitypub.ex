defmodule Fedex.Activitypub do
  alias Fedex.Crypto.HttpSigning
  alias Fedex.Activitypub.Actor

  @env_proto (if Mix.env() == :test do
                "http"
              else
                "https"
              end)

  def request_by_actor(actor, keypair, verb, host, port, path, body) do
    full_body = Jason.encode!(body)

    headers =
      HttpSigning.new(host, port, verb, path, HttpSigning.datetime_now())
      |> HttpSigning.digest(full_body)
      |> HttpSigning.sign(keypair.private)
      |> HttpSigning.verify!(keypair.public)
      |> HttpSigning.to_headers(actor.publicKey.id)

    {protocol, port_part} =
      case port do
        443 ->
          {"https", ""}

        # Plain http is not actually allowed
        _other ->
          {@env_proto, ":#{port}"}
      end

    url = Path.join("#{protocol}://#{host}#{port_part}", path)

    other_headers = [
      {"content-type", "application/activity+json"}
    ]

    headers = headers ++ other_headers

    [method: verb, url: url, headers: headers, body: full_body]
  end

  def get_actor(id) do
    case Req.get(id) do
      {:ok, %{status: 200, body: body}} ->
        Actor.from_response_body(body)
      {:ok, %{status: status, body: body}} ->
        {:error, {:request_failed, %{status: status, body: body}}}
      {:error, reason} ->
        {:error, {:request_error, reason}}
      end
  end

  def get_actor_public_key(key_id) do
    # Remove fragment if it matters
    [url | _] = String.split(key_id, "#")

    with {:ok, %{body: body}} <- Req.get(url),
         %{"publicKey" => %{"id" => ^key_id, "publicKeyPem" => public_key_pem}} <- body do
      {:ok, public_key_pem}
    end
  end

  def request(opts), do: Req.request(opts)
end
