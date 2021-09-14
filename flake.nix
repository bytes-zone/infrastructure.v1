{
  description = "bytes.zone infrastructure";

  inputs = {
    nixpkgs-release.url = "github:NixOS/nixpkgs/release-21.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    bad-datalog.url =
      "git+https://git.bytes.zone/brian/bad-datalog.git?ref=main";
    bad-datalog.inputs.nixpkgs.follows = "nixpkgs-release";

    bytes-zone.url =
      "git+https://git.bytes.zone/bytes.zone/bytes.zone.git?ref=main";
    bytes-zone.inputs.nixpkgs.follows = "nixpkgs-release";

    comma = {
      url = "github:Shopify/comma";
      flake = false;
    };

    elo-anything.url =
      "git+https://git.bytes.zone/brian/elo-anything.git?ref=main";
    elo-anything.inputs.nixpkgs.follows = "nixpkgs-release";

    goatcounter = {
      url = "github:zgoat/goatcounter/release-1.4";
      flake = false;
    };
  };

  outputs = inputs:
    let
      mkOverlays = system:
        let pkgs = inputs.nixpkgs-release.legacyPackages.${system};
        in [
          inputs.bad-datalog.overlay.${system}
          inputs.bytes-zone.overlay.${system}
          inputs.elo-anything.overlay.${system}
          (final: prev: {
            comma = pkgs.callPackage inputs.comma { };

            goatcounter = pkgs.buildGoModule {
              pname = "goatcounter";
              version = inputs.goatcounter.rev;
              src = inputs.goatcounter;

              subPackages = [ "cmd/goatcounter" ];

              vendorSha256 =
                "0zd994rccrsmg54jygd3spqzk4ahcqyffzpzqgjiw939hlbxvb6s";

              doCheck = false;
            };
          })
        ];
    in {
      nixosConfigurations.gitea = inputs.nixpkgs-release.lib.nixosSystem rec {
        system = "x86_64-linux";

        modules = [
          ({ ... }: { nixpkgs.overlays = mkOverlays system; })
          ./machines/gitea
        ];
      };
    };
}
