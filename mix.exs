defmodule Zing.MixProject do
  use Mix.Project

  def project do
    [
      app: :zing,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:connection, "~> 1.0.4"},
      {:zigler, "== 0.3.0-pre"}
    ]
  end
end
