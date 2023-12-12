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

  def sign_request(private_key_pem, key_id, http_verb, path) do
    key = :http_signature_key.decode_pem(private_key_pem)
    #key = %{key | id: key_id}
    signer = :http_signature_signer.new(key)
    request = :http_signature.sign(signer, http_verb, path, %{})
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
end