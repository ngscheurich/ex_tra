defmodule Extra.MixProject do
  use Mix.Project

  def project do
    [
      app: :extra,
      version: "0.1.0",
      elixir: "~> 1.17",
      escript: [main_module: Extra]
    ]
  end
end
