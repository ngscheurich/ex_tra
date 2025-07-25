import Config

transforms =
  Path.expand("../lib/transforms", __DIR__)
  |> File.ls!()
  |> Enum.filter(&String.ends_with?(&1, ".ex"))
  |> Enum.map(fn filename ->
    name = filename |> String.replace_suffix(".ex", "")
    module = name |> Macro.camelize() |> String.to_atom()
    {name, module}
  end)
  |> Map.new()

config :ex_tra, transforms: transforms
