let sources = import ../nix/sources.nix;
in (import "${sources.nixos}/nixos" {
  system = "x86_64-linux";

  configuration = { imports = [ ./configuration.nix ]; };
}).system
