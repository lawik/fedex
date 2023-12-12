defmodule Fedex.Webfinger do
  defmodule Link do
    defstruct rel: nil, type: nil, href: nil

    def new(rel, type, href) when is_binary(rel) and is_binary(type) and is_binary(href),
      do: %Link{rel: rel, type: type, href: href}

    def as_map(%Link{} = l) do
      %{rel: l.rel, type: l.type, href: l.href}
    end
  end

  defmodule Entity do
    defstruct subject: nil, links: []

    def new(subject, links \\ []) when is_binary(subject) and is_list(links),
      do: %Entity{subject: subject, links: links}

    def as_map(%Entity{} = e) do
      %{
        subject: e.subject,
        links: Enum.map(e.links, &Link.as_map/1)
      }
    end
  end

  def entities(ents) do
    ents
    |> Enum.map(fn e -> {e.subject, e} end)
    |> Map.new()
  end

  def ent(email_style, links) do
    Entity.new("acct:" <> email_style, links)
  end

  def link(rel, type, href) do
    Link.new(rel, type, href)
  end

  def fetch(host, email_style) do
    url = Path.join(host, "/.well-known/webfinger?resource=acct:#{email_style}")

    with {:ok, response} <- Req.get(url) do
      {:ok, response.body}
    end
  end
end
