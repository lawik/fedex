defmodule Fedex.Activitypub.Dumb do
  alias Fedex.Webfinger

  def go("@" <> stripped) do
    [name, host] = String.split(stripped, "@", parts: 2)
    {:ok, body} = Webfinger.fetch("https://" <> host, "#{name}@#{host}")
    IO.inspect(body)
  end

  def go("https://" <> _ = id_url) do
    {:ok, %{status: 200, body: body}} = Req.get(id_url, headers: [accept: "application/activity+json"])
    Process.put(id_url, body)
    Process.put(:latest, body)
    print(body)
    |> IO.puts()
  end

  def go(field) when is_atom(field), do: go(Atom.to_string(field))

  def go(field) when is_binary(field) do
    latest = Process.get(:latest)

    case latest do
      nil ->
        IO.puts("No current to get field from.")

      _ ->
        case Map.get(latest, field) do
          nil ->
            IO.puts("Field not found: #{field}")
            IO.puts("This is the current:")
            print(latest)
            |> IO.puts()

          value ->
            go(value)
        end
    end
  end

  def print(thing, indent \\ 0)

  def print(thing, indent) when is_map(thing) do
    [
      "\n",
      Enum.map(thing, fn {key, value} ->
        ["\n#{key}: ", print(value, indent + 1)]
      end),
      "\n\n"
    ]
  end

  def print(thing, indent) when is_list(thing) do
    [
      "\n",
      Enum.map(thing, fn value ->
        print(value, indent + 1)
      end),
      "\n\n"
    ]
  end

  def print(thing, indent) do
    ["\n", Enum.map(1..indent, fn _ -> "  " end), inspect(thing)]
  end
end
