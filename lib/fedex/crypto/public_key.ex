defmodule Fedex.Crypto.PublicKey do
  defstruct length: nil, public_key: nil

  alias Fedex.Crypto.PublicKey

  def new(length, public_key) do
    %PublicKey{length: length, public_key: public_key}
  end
end
