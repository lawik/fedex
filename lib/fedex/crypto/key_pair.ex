defmodule Fedex.Crypto.KeyPair do
  defstruct length: nil, private: nil, public: nil
  alias Fedex.Crypto.KeyPair
  alias Fedex.Crypto.PublicKey
  alias Fedex.Crypto.PrivateKey

  def new(length, %PublicKey{} = public, %PrivateKey{} = private)
      when length >= 2048 do
    %KeyPair{length: length, public: public, private: private}
  end
end
