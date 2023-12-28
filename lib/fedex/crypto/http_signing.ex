defmodule Fedex.Crypto.HttpSigning do
  defstruct host: nil,
            port: nil,
            http_verb: nil,
            path: nil,
            date: nil,
            body: nil,
            digest: nil,
            to_sign: nil,
            sig_header: nil,
            signature: nil,
            verified?: false

  alias Fedex.Crypto
  alias Fedex.Crypto.{HttpSigning, PublicKey, PrivateKey}

  def datetime_now, do: DateTime.utc_now() |> HTTPDate.format()

  def new(host, port, http_verb, path, date) do
    %HttpSigning{
      host: host,
      port: port,
      http_verb: http_verb,
      path: path,
      date: date
    }
  end

  def digest(
        %HttpSigning{http_verb: http_verb, path: path, host: host, port: port, date: date} = hs,
        body
      ) do
    digest = Crypto.digest(body)

    to_sign = Crypto.build_to_sign(http_verb, path, host, port, date, digest)

    %HttpSigning{hs | digest: digest, to_sign: to_sign}
  end

  def sign(%HttpSigning{to_sign: to_sign} = hs, %PrivateKey{private_key: private_key_pem}) do
    [pem_entry] = :public_key.pem_decode(private_key_pem)

    # {:RSAPrivateKey, _, _modulus, _public_exponent, _private_exponent, _, _, _exponent1, _, _,
    # _otherPrimeInfos} =
    private_key = :public_key.pem_entry_decode(pem_entry)

    signed = :public_key.sign(to_sign, :sha256, private_key, [{:rsa_padding, :rsa_pkcs1_padding}])

    signature = Base.encode64(signed)
    %HttpSigning{hs | signature: signature}
  end

  def verify!(%HttpSigning{to_sign: to_sign, signature: signature} = hs, %PublicKey{
        public_key: public_key_pem
      }) do
    [pem_entry] = :public_key.pem_decode(public_key_pem)
    public_key = :public_key.pem_entry_decode(pem_entry)

    signed = Base.decode64!(signature)
    true = :public_key.verify(to_sign, :sha256, signed, public_key)
    %HttpSigning{hs | verified?: true}
  end

  def to_headers(
        %HttpSigning{host: host, port: port, date: date, digest: digest, signature: signature} =
          _hs,
        key_id
      ) do
    sig_header =
      """
      keyId="#{key_id}",headers="(request-target) host date digest",signature="#{signature}"
      """
      |> String.trim()

    [
      host: "#{host}:#{port}",
      date: date,
      digest: "sha-256=" <> digest,
      signature: sig_header
    ]
  end
end
