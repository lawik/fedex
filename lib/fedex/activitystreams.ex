defmodule Fedex.Activitystreams do
  @activitystreams_context "https://www.w3.org/ns/activitystreams"
  @activitystreams_public "https://www.w3.org/ns/activitystreams#Public"
  @w3id_security_v1 "https://w3id.org/security/v1"

  def actor(host, id, type, preferred_username, inbox, public_key_id, public_key_pem) do
    id = Path.join(host, id)

    %{
      id: id,
      type: type,
      preferredUsername: preferred_username,
      inbox: Path.join(host, inbox),
      publicKey: %{
        id: id <> "#" <> public_key_id,
        owner: id,
        publicKeyPem: public_key_pem
      }
    }
    |> at_context([@activitystreams_context, @w3id_security_v1])
  end

  def new(host, id, type, actor, object) do
    %{
      id: Path.join(host, id),
      type: type,
      actor: actor,
      object: object
    }
    |> at_context(@activitystreams_context)
  end

  def new_note_object(
        host,
        id,
        actor,
        %DateTime{} = published,
        in_reply_to,
        content,
        to
      ) do
    %{
      id: Path.join(host, id),
      type: "Note",
      published: DateTime.to_iso8601(published),
      attributedTo: actor,
      inReplyTo: in_reply_to,
      content: content,
      to: to
    }
  end

  def new_follow_object(
    host,
    id,
    actor,
    object
  ) do
    %{
      id: Path.join(host, id),
      type: "Follow",
      actor: actor,
      object: object
    }
    |> at_context([@activitystreams_context])
  end

  def new_accept_object(
    host,
    id,
    actor,
    object
  ) do
    %{
      id: Path.join(host, id),
      type: "Accept",
      actor: actor,
      object: object
    }
    |> at_context([@activitystreams_context])
  end

  def new_reject_object(
    host,
    id,
    actor,
    object
  ) do
    %{
      id: Path.join(host, id),
      type: "Reject",
      actor: actor,
      object: object
    }
    |> at_context([@activitystreams_context])
  end

  def to_public(), do: @activitystreams_public

  defp at_context(thing, value) do
    Map.put(thing, :"@context", value)
  end
end
