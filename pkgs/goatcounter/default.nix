{ sources ? import ../../nix/sources.nix, pkgs ? import sources.nixpkgs { }, ...
}:
pkgs.buildGoModule {
  pname = "goatcounter";
  version = sources.goatcounter.branch;
  src = sources.goatcounter;

  subPackages = [ "cmd/goatcounter" ];

  vendorSha256 = "0zd994rccrsmg54jygd3spqzk4ahcqyffzpzqgjiw939hlbxvb6s";

  doCheck = false;
}
