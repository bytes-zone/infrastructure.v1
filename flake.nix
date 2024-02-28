{
  description = "bytes.zone infrastructure";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-23.11";

    sysz = {
      url = "github:joehillen/sysz";
      flake = false;
    };
  };

  outputs = inputs:
    {
      formatter.aarch64-darwin = inputs.nixpkgs.legacyPackages.aarch64-darwin.nixpkgs-fmt;

      nixosConfigurations.gitea = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [
          ./machines/gitea
        ];
      };

      devShells = builtins.listToAttrs (map
        (system:
          let pkgs = import inputs.nixpkgs {
            inherit system;
            config.allowUnfree = true; # for Terraform
          };
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
