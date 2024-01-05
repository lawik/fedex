defmodule Fedex.Activitypub.Actor do
  defstruct
    type: nil
    id: nil,
    local_identifier: nil,
    name: nil,
    preferred_username: nil,
    summary: nil,
    inbox: nil,
    outbox: nil,
    followers: nil,
    following: nil,
    liked: nil

  alias Fedex.Activitypub
  alias Fedex.Activitypub.Actor
  alias Fedex.Activitypub.Host
  alias Fedex.Webfinger

  def person(%Host{host: host}, name, to_host \\ &person_to_id/2) do
    %Actor{local_identifier: name, id: to_host.(host, name), type: "Person"}
  end

  def from_id("@" <> _ = query) do
    from_mastodon_at(query)
  end

  def from_id("https://" <> _ = actor_id) do
    Activitypub.get_actor(actor_id)
  end

  def from_mastodon_at("@" <> _ = at) do
    [_, host] = String.split(at, "@", parts: 2)
    Webfinger.fetch(host, at)
  end

  defp person_to_id(host, name) do
    Path.join([host, "users", name])
  end
end
