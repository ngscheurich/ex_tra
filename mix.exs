defmodule ExTra.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_tra,
      aliases: [
        build: [
          "escript.build",
          "cmd echo \"./emacs/ ./nvim/lua/ex_tra/ ./vscode/out/\" | xargs -n 1 cp -r ex_tra",
          "cmd rm -rf ex_tra"
        ]
      ],
      version: "0.2.0",
      elixir: "~> 1.17",
      elixirc_paths: if(Mix.env() == :test, do: ["lib", "test/support"], else: ["lib"]),
      escript: [main_module: ExTra, name: "ex_tra"],
      deps: [{:sourceror, "~> 1.10"}]
    ]
  end
end
