defmodule Fedex.Plugs.Inbox do
  @moduledoc """
  Checks that incoming ActivityPub requests are reasonable and structurally sound.

  Will protect against attempts to sign for someone else.
  Should probably protect against replay attacks by checking date.
  """

  alias Plug.Conn

  def init(opts), do: opts

  def call(%Conn{} = conn, _opts) do
    case conn.body_params do
      %{"actor" => actor_1, "object" => %{"attributedTo" => actor_2}} when actor_1 != actor_2 ->
        conn
        |> Conn.send_resp(400, "Actor and attributedTo must match: #{actor_1} is not #{actor_2}")

      _ ->
        conn
    end
  end
end
