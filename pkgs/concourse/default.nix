{ ... }:
let
  sources = import ../../nix/sources.nix;
  pkgs = import sources.nixpkgs { };
in {
  concourse = pkgs.buildGoModule {
    pname = "concourse";
    version = "5.6.1";
    src = sources.concourse;
    subPackages = [ "cmd/concourse" "fly" ];

    vendorSha256 = "1fxbxkg7disndlmb065abnfn7sn79qclkcbizmrq49f064w1ijr4";

    checkPhase = false;
  };
}
