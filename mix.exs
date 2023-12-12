defmodule Fedex.MixProject do
  use Mix.Project

  def project do
    [
      app: :fedex,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :crypto]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:req, "~> 0.4.0"},
      {:jason, "~> 1.4"},
      {:json_ld, "~> 0.3.7"},
      {:plug, "~> 1.0"},
      # {:http_signature, "~> 2.0"},
      # {:http_signature, path: "../erlang-http_signature"},
      {:http_signature, github: "lawik/erlang-http_signature", ref: "fix-otp-26"},
      {:bandit, "~> 1.1", only: :test}
    ]
  end
end
