{ ... }:
let
  sources = import ./nix/sources.nix;

  nixpkgs = import sources.nixpkgs { config = { allowUnfree = true; }; };

  niv = import sources.niv { };
in with nixpkgs;
stdenv.mkDerivation {
  name = "gitea-experiment";
  buildInputs = [ niv.niv git terraform graphviz tarsnap ];
}
