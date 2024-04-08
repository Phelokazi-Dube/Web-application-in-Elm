{ pkgs ? import <nixpkgs> {} }:
  pkgs.mkShell {
    nativeBuildInputs = with pkgs.buildPackages; [
      nodejs_20 elmPackages.elm elixir
      # for clouseau
      zulu8 wget unzip
    ];
}
