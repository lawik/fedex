defmodule Fedex.Plugs.Activitystreams do
  alias Plug.Conn

  require Logger
  def init(options), do: options

  @spec call(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def call(%Conn{path_info: []} = conn, _opts) do
    conn
  end

  def call(%Conn{path_info: parts} = conn, opts) do
    IO.inspect(Enum.join(parts, "/"), label: inspect(conn.method))
    IO.inspect(conn.req_headers, label: "headers incoming")
    prefix = Keyword.get(opts, :prefix, "/")
    key = Path.join([prefix | parts])
    fetch_thing = Keyword.fetch!(opts, :fetch)
    Logger.info("Fetching actor by key: #{key}")

    case fetch_thing.(key) do
      nil ->
        Logger.info("No actor found, continuing...")
        conn

      entity when is_binary(entity) ->
        Logger.info("Actor found, so displaying them.")

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
