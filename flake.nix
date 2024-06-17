{
  description = "Shell scripts as Nix derivations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils }:
  utils.lib.eachDefaultSystem(system: 
  let
    pkgs = import nixpkgs { inherit system; };
  in
  {

    packages = {
      # Screenshots a part of the screen and saves it to the clipboard
      clipscrot = pkgs.writeShellScriptBin "clipscrot" ''
        ${pkgs.scrot}/bin/scrot -s - | ${pkgs.xclip}/bin/xclip -selection clipboard -t image/png
      '';

      # Creates a backup of a file/directory and makes it
      # read-only to avoid accidentally deleting it
      # (rm asks for confirmation on read-only files)
      bakup = pkgs.writeShellScriptBin "bakup" ''
        if [ ! -e "$1" ]
        then
          >&2 echo "File $1 does not exist"
          exit 1
        fi

        last_backup=$(ls | grep -Po "(?<=$1.bak.)\\d+" | sort -nr | head -1)
        last_backup=''${last_backup:-0}
        next_backup=$((last_backup + 1))
        next_backup_file="$1.bak.$next_backup"

        cp -r "$1" "$next_backup_file"
        chmod -w "$next_backup_file"
      '';
    };

  });
}
