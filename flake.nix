{
  description = "Shell scripts as Nix derivations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
    treefmt = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pre-commit = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-checks = {
      url = "github:huuff/nix-checks";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      utils,
      treefmt,
      pre-commit,
      nix-checks,
    }:
    utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        treefmt-build = (treefmt.lib.evalModule pkgs ./treefmt.nix).config.build;
        pre-commit-check = pre-commit.lib.${system}.run {
          src = ./.;
          hooks = import ./pre-commit.nix {
            inherit pkgs;
            treefmt = treefmt-build.wrapper;
          };
        };
        inherit (nix-checks.lib.${system}) checks;
      in
      {

        packages = rec {
          # Screenshots a part of the screen and saves it to the clipboard
          clipscrot = pkgs.writeShellScriptBin "clipscrot" ''
            ${pkgs.scrot}/bin/scrot -s - | ${pkgs.xclip}/bin/xclip -selection clipboard -t image/png
          '';

          # Screenshots a part of the screen, saves it to a temporary file and stores the path in the clipboard
          pathscrot = pkgs.writeShellScriptBin "pathscrot" ''
            screenshot_path="$(mktemp -d)/$(date +%s).png"
            ${pkgs.scrot}/bin/scrot -s "$screenshot_path"
            echo "$screenshot_path" | ${pkgs.xclip}/bin/xclip -selection clipboard
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

          # Runs about every single command I know to clean docker
          # stuff
          docker-nuke = pkgs.writeShellScriptBin "docker-nuke" ''
            docker rm -vf $(docker ps -aq) \
            && docker rmi -f $(docker images -aq) \
            && docker volume rm $(docker volume ls -q) \
            && docker system prune -af --volumes
          '';

          # Cleans everything unused or old from the nix store
          nix-nuke = pkgs.writeShellScriptBin "nix-nuke" ''
            ${pkgs.home-manager}/bin/home-manager expire-generations "-1 days" && \
            sudo nix-collect-garbage -d
          '';

          # Runs both `nix-nuke` and `docker-nuke`
          #
          # I think it's important to run nix-nuke first since that will ask for sudo, so
          # better get it done ASAP to avoid interruptions down the line
          nuke-all = pkgs.writeShellScriptBin "nuke-all" ''
            echo "Running nix-nuke..."
            ${nix-nuke}/bin/nix-nuke
            echo "Running docker-nuke..."
            ${docker-nuke}/bin/docker-nuke
          '';

          # Delete all branches but `main` or `master` and that have been merged
          git-prune-branches = pkgs.writeShellScriptBin "git-prune-branches" ''
            git branch | grep -v master | grep -v main | xargs git branch -d
          '';
        };

        checks = {
          formatting = treefmt-build.check self;

          statix = checks.statix ./.;
          deadnix = checks.deadnix ./.;
          flake-checker = checks.flake-checker ./.;
        };

        formatter = treefmt-build.wrapper;

        devShells.default = pkgs.mkShell {
          inherit (pre-commit-check) shellHook;

          buildInputs =
            with pkgs;
            pre-commit-check.enabledPackages
            ++ [
              nil
              nixfmt-rfc-style
            ];
        };

      }
    );
}
