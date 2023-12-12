defmodule Fedex.Activitystreams.Plug do
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
    Logger.info("Fetching actor by key: #{key}")

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

  def call(conn, _opts), do: conn
end
