defmodule Fedex.Crypto do
  alias Fedex.Crypto

  defmodule PublicKey do
    defstruct length: nil, public_key: nil

    def new(length, public_key) do
      %PublicKey{length: length, public_key: public_key}
    end
  end

  defmodule PrivateKey do
    defstruct length: nil, private_key: nil

    def new(length, private_key) do
      %PrivateKey{length: length, private_key: private_key}
    end
  end

  defmodule KeyPair do
    defstruct length: nil, private: nil, public: nil
    alias Fedex.Crypto

    def new(length, %Crypto.PublicKey{} = public, %Crypto.PrivateKey{} = private)
        when length >= 2048 do
      %KeyPair{length: length, public: public, private: private}
    end
  end

  @default_length 2048
  def generate_keypair(length \\ @default_length) do
    # {pub, priv} = :crypto.generate_key(:rsa, {length, 65537})
    {priv, pub} = generate_rsa_key_pair()
    KeyPair.new(length, PublicKey.new(length, pub), PrivateKey.new(length, priv))
  end

  defmodule HttpSigning do
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

    alias Fedex.Crypto.HttpSigning
    alias Fedex.Crypto.PrivateKey

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
      digest = Fedex.Crypto.digest(body)

      to_sign = Fedex.Crypto.build_to_sign(http_verb, path, host, port, date, digest)

      %HttpSigning{hs | digest: digest, to_sign: to_sign}
    end

    def sign(%HttpSigning{to_sign: to_sign} = hs, %PrivateKey{private_key: private_key_pem}) do
      [pem_entry] = :public_key.pem_decode(private_key_pem)

      # {:RSAPrivateKey, _, _modulus, _public_exponent, _private_exponent, _, _, _exponent1, _, _,
      # _otherPrimeInfos} =
      private_key = :public_key.pem_entry_decode(pem_entry)

      signed =
        :public_key.sign(to_sign, :sha256, private_key, [{:rsa_padding, :rsa_pkcs1_padding}])

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
            hs,
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

  defp generate_rsa_key_pair() do
    {:RSAPrivateKey, _, modulus, publicExponent, _, _, _, _exponent1, _, _, _otherPrimeInfos} =
      rsa_private_key = :public_key.generate_key({:rsa, 2048, 65537})

    rsa_public_key = {:RSAPublicKey, modulus, publicExponent}

    private_key =
      [:public_key.pem_entry_encode(:RSAPrivateKey, rsa_private_key)]
      |> :public_key.pem_encode()

    public_key =
      [:public_key.pem_entry_encode(:RSAPublicKey, rsa_public_key)]
      |> :public_key.pem_encode()

    {private_key, public_key}
  end

  def digest(text) do
    :crypto.hash(:sha256, text) |> Base.encode64()
  end

  def build_to_sign(http_verb, path, host, port, date, digest) do
    [
      "(request-target): #{http_verb} #{path}",
      "host: #{host}:#{port}",
      "date: #{date}",
      "digest: sha-256=#{digest}"
    ]
    |> Enum.join("\n")
  end

  def signature_valid?(msg, signature, public_key_pem) do
    [pem_entry] = :public_key.pem_decode(public_key_pem)
    public_key = :public_key.pem_entry_decode(pem_entry)

    signed = Base.decode64!(signature)
    :public_key.verify(msg, :sha256, signed, public_key)
  end
end
