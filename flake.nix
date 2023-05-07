{
  description = "Shell scripts as Nix derivations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
  in
  {

    packages.${system} = {
      clipscrot = pkgs.writeShellScriptBin "clipscrot" ''
        ${pkgs.scrot}/bin/scrot -s - | ${pkgs.xclip}/bin/xclip -selection clipboard -t image/png
      '';
    };

  };
}
