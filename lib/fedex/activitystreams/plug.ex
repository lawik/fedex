defmodule Fedex.Activitystreams.Plug do
  alias Plug.Conn
  def init(options), do: options

  def call(%Conn{path_info: []} = conn, _opts) do
    conn
  end

  def call(%Conn{path_info: parts} = conn, opts) do
    prefix = Keyword.get(opts, :prefix, "/")
    key = Path.join([prefix | parts])
    fetch_thing = Keyword.fetch!(opts, :fetch)
    IO.inspect(key, label: "key in plug")

    case fetch_thing.(key) do
      nil ->
        Conn.send_resp(conn, 404, "Not found")

      entity when is_binary(entity) ->
        conn
        |> Conn.put_resp_content_type("application/json")
        |> Conn.send_resp(
          200,
          entity
        )
    end
  end

  def call(conn), do: conn
end
