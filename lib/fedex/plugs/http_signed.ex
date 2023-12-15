defmodule Fedex.Plugs.HttpSigned do
  alias Plug.Conn

  alias Fedex.Activitypub
  alias Fedex.Crypto

  require Logger

  def init(options), do: options

  @spec call(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def call(%Conn{} = conn, options) do
    with {:ok, sig} <- unpack_signature_header(conn),
         {:ok, signed_header_keys} <- get_signed_header_keys(sig),
         :ok <- verify_digest_for_post(conn, signed_header_keys, options),
         {:ok, headers_with_request_target} <- moar_headers(conn, signed_header_keys),
         {:ok, header_string_to_sign} <-
           build_header_string_to_sign(headers_with_request_target, signed_header_keys),
         {:ok, public_key_pem} <- fetch_public_key(sig["keyId"]),
         :ok <- verify_signature(header_string_to_sign, sig["signature"], public_key_pem) do
      conn
    else
      {:bad_request, reason} ->
        bad(conn, reason)

      {:your_fault, reason} ->
        your_fault(conn, reason)
    end
  end

  defp unpack_signature_header(%Conn{req_headers: headers}) do
    case header(headers, "signature") do
      nil ->
        {:bad_request, "No signature header found"}

      val when is_binary(val) ->
        {:ok, parse_sig_header(val)}
    end
  end

  defp get_signed_header_keys(sig) do
    {:ok, String.split(sig["headers"], " ")}
  end

  def verify_digest_for_post(
        %Conn{method: "POST", req_headers: headers} = conn,
        signed_header_keys,
        opts
      ) do
    conn =
      if is_nil(conn.assigns[:raw_body]) do
        {:ok, _body, conn} = alt_read_body(conn, opts)
        # Raw body should exist now
        conn
      else
        conn
      end

    body = conn.assigns[:raw_body] |> IO.iodata_to_binary()

    if "digest" in signed_header_keys do
      case header(headers, "digest") do
        nil ->
          {:bad_request, "Must send a digest header with the request."}

        "sha-256=" <> digest ->
          new_digest = Crypto.digest(body)
          if new_digest == digest do
            :ok
          else
            {:bad_request, "Digest header and SHA-256 of body did not match.\n#{digest} from header\n#{new_digest} from body"}
          end

        _other ->
          {:bad_request, "Digest header is not tagged as SHA-256."}
      end
    else
      {:bad_request, "Must have digest header in referenced in signature header's headers key."}
    end
  end

  # Not POST, digest not required
  def verify_digest_for_post(%Conn{}, _signed_header_keys), do: :ok

  defp moar_headers(
         %Conn{path_info: path_info, method: method, req_headers: headers},
         signed_header_keys
       ) do
    path =
      case path_info do
        [] -> "/"
        parts -> Path.join(["/" | parts])
      end

    minor_method = String.downcase(method)

    if "(request-target)" in signed_header_keys do
      {:ok, [{"(request-target)", "#{minor_method} #{path}"} | headers]}
    else
      {:bad_request,
       "Synthetic header (request-target) must be in the headers section of the signature header."}
    end
  end

  defp build_header_string_to_sign(headers, signed_key_headers) do
    to_sign =
      signed_key_headers
      |> Enum.map(fn key ->
        "#{key}: #{header(headers, key)}"
      end)
      |> Enum.join("\n")

    {:ok, to_sign}
  end

  defp fetch_public_key(key_id) do
    case Activitypub.get_actor_public_key(key_id) do
      {:ok, pem} ->
        {:ok, pem}

      {:error, err} ->
        Logger.warn("Failed to get actor public key '#{key_id}' because: #{inspect(err)}")
        {:bad_request, "Could not fetch actor public key from #{key_id}."}
    end
  end

  defp verify_signature(header_string_to_sign, signature, public_key_pem) do
    if Crypto.signature_valid?(header_string_to_sign, signature, public_key_pem) do
      :ok
    else
      {:bad_request, "Signature did not validate versus the headers that were supposedly signed."}
    end
  end

  defp bad(conn, reason),
    do:
      conn
      |> Conn.send_resp(400, reason)
      |> Conn.halt()

  defp your_fault(conn, reason),
    do:
      conn
      |> Conn.send_resp(500, reason)
      |> Conn.halt()

  defp header(headers, key) do
    case(Enum.find(headers, &(elem(&1, 0) == key))) do
      nil ->
        nil

      {_k, v} ->
        v
    end
  end

  def parse_sig_header(sig_header) do
    sig_header
    |> String.split(",")
    |> Enum.map(fn kv ->
      kv
      |> String.split("=", parts: 2)
      |> then(fn [k, v] ->
        value = String.trim(v, "\"")
        {k, value}
      end)
    end)
    |> Map.new()
  end

  def alt_read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
    conn = update_in(conn.assigns[:raw_body], &[body | &1 || []])
    {:ok, body, conn}
  end
end
