{
  description = "bytes.zone infrastructure";

  inputs = {
    nixpkgs-release.url = "github:NixOS/nixpkgs/release-21.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    bad-datalog = {
      url = "git+https://git.bytes.zone/brian/bad-datalog.git?ref=main";
      flake = false;
    };

    bytes-zone = {
      url = "git+https://git.bytes.zone/bytes.zone/bytes.zone.git?ref=main";
      flake = false;
    };

    comma = {
      url = "github:Shopify/comma";
      flake = false;
    };

    elo-anything = {
      url = "git+https://git.bytes.zone/brian/elo-anything.git?ref=main";
      flake = false;
    };

    goatcounter = {
      url = "github:zgoat/goatcounter/release-1.4";
      flake = false;
    };
  };

  outputs = inputs:
    let overlays = [ ];
    in {
      nixosConfigurations.gitea = inputs.nixpkgs-release.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ({ ... }: { nixpkgs.overlays = overlays; }) ];
      };
    };
}
