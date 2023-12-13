defmodule Fedex.Webfinger.Plug do
  alias Plug.Conn
  def init(options), do: options

  def call(%Conn{path_info: [".well-known", "webfinger"]} = conn, opts) do
    %Conn{query_params: q} = conn = Conn.fetch_query_params(conn)
    fetch_entity = Keyword.fetch!(opts, :fetch)

    case q do
      %{"resource" => subject} ->
        case fetch_entity.(subject) do
          nil ->
            Conn.send_resp(conn, 404, "Not found")
            |> Conn.halt()

          entity when is_binary(entity) ->
            conn
            |> Conn.put_resp_content_type("application/json")
            |> Conn.send_resp(
              200,
              entity
            )
            |> Conn.halt()
        end

      _ ->
        Conn.send_resp(conn, 404, "Not found")
        |> Conn.halt()
    end
  end

  def call(conn, _opts), do: conn
end
