defmodule Fedex.Crypto do
  alias Fedex.Crypto.{KeyPair, PublicKey, PrivateKey}

  @default_length 2048
  def generate_keypair(length \\ @default_length) do
    # {pub, priv} = :crypto.generate_key(:rsa, {length, 65537})
    {priv, pub} = generate_rsa_key_pair()
    KeyPair.new(length, PublicKey.new(length, pub), PrivateKey.new(length, priv))
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
