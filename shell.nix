{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  buildInputs = with pkgs; [
    beam.interpreters.erlang
    beam.packages.erlang.elixir
    git
  ];

  name = "ex_tra";
}
