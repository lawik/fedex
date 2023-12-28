defmodule Fedex.Crypto.PrivateKey do
  defstruct length: nil, private_key: nil

  alias Fedex.Crypto.PrivateKey

  def new(length, private_key) do
    %PrivateKey{length: length, private_key: private_key}
  end
end
