defmodule Fedex.Plugs.Activitystreams do
  alias Plug.Conn

  require Logger
  def init(options), do: options

  @spec call(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def call(%Conn{path_info: []} = conn, _opts) do
    conn
  end

  def call(%Conn{path_info: parts} = conn, opts) do
    prefix = Keyword.get(opts, :prefix, "/")
    key = Path.join([prefix | parts])
    fetch_thing = Keyword.fetch!(opts, :fetch)

    case fetch_thing.(key) do
      nil ->
        conn

      entity when is_binary(entity) ->
        conn
        |> Conn.put_resp_content_type("application/json")
        |> Conn.send_resp(
          200,
          entity
        )
        |> Conn.halt()
    end
  end

  def call(conn, _opts), do: conn
end
