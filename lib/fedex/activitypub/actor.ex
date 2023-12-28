defmodule Fedex.Activitypub.Actor do
  defstruct id: nil, type: nil

  alias Fedex.Activitypub.Actor

  def new(id, type \\ "Person") do
    %Actor{id: id, type: type}
  end
end
