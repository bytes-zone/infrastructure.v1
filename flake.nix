{
  description = "bytes.zone infrastructure";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-22.11";

    bad-datalog.url =
      "git+https://git.bytes.zone/brian/bad-datalog.git?ref=main";
    bad-datalog.inputs.nixpkgs.follows = "nixpkgs";

    bytes-zone.url =
      "git+https://git.bytes.zone/bytes.zone/bytes.zone.git?ref=main";
    bytes-zone.inputs.nixpkgs.follows = "nixpkgs";

    elo-anything.url =
      "git+https://git.bytes.zone/brian/elo-anything.git?ref=main";
    elo-anything.inputs.nixpkgs.follows = "nixpkgs";

    goatcounter = {
      url = "github:zgoat/goatcounter/release-1.4";
      flake = false;
    };

    nates-mazes.url =
      "git+https://git.bytes.zone/brian/nates-mazes.git?ref=main";
    nates-mazes.inputs.nixpkgs.follows = "nixpkgs";

    sysz = {
      url = "github:joehillen/sysz";
      flake = false;
    };
  };

  outputs = inputs:
    let
      mkOverlays = system:
        let pkgs = import inputs.nixpkgs { inherit system; };
        in [
          inputs.bad-datalog.overlay.${system}
          inputs.bytes-zone.overlay.${system}
          inputs.elo-anything.overlay.${system}
          inputs.nates-mazes.overlay.${system}
          (final: prev: {
            goatcounter = pkgs.buildGoModule {
              pname = "goatcounter";
              version = inputs.goatcounter.rev;
              src = inputs.goatcounter;

              subPackages = [ "cmd/goatcounter" ];

              vendorSha256 =
                "0zd994rccrsmg54jygd3spqzk4ahcqyffzpzqgjiw939hlbxvb6s";

              doCheck = false;
            };

            sysz = final.stdenv.mkDerivation {
              name = "sysz";
              src = inputs.sysz;

              buildPhase = "true";
              buildInputs = [ final.makeWrapper ];
              installPhase = ''
                mkdir -p $out/bin
                install -m755 sysz $out/bin

                wrapProgram $out/bin/sysz --prefix PATH : ${
                  final.lib.makeBinPath [ final.fzf ]
                }
              '';
            };
          })
        ];
    in {
      nixosConfigurations.gitea = inputs.nixpkgs.lib.nixosSystem rec {
        system = "x86_64-linux";

        modules = [
          ({ ... }: { nixpkgs.overlays = mkOverlays system; })
          ./machines/gitea
        ];
      };

      devShells = builtins.listToAttrs (map (system:
        let pkgs = import inputs.nixpkgs { inherit system; };
        in {
          name = system;
          value = {
            default = pkgs.mkShell {
              buildInputs = with pkgs; [ git terraform graphviz borgbackup pv ];
            };
          };
        }) [ "x86_64-linux" "x86_64-darwin" "aarch64-darwin" ]);
    };
}
