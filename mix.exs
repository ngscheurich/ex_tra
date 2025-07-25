defmodule ExTra.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_tra,
      version: "0.1.0",
      elixir: "~> 1.17",
      escript: [main_module: ExTra, name: "extra"]
    ]
  end
end
