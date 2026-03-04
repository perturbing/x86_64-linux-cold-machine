{
  description = "x86_64 disk image for Cardano with GNOME";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    cardano-node.url = "github:intersectmbo/cardano-node";
    cardano-addresses.url = "github:perturbing/cardano-addresses";
    cardano-signer.url = "github:perturbing/cardano-signer-nix";
  };

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
      "https://cache.iog.io"
    ];
    extra-trusted-public-keys = [
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux"];

      imports = [
        ./perSystem/packages/airgap.nix
      ];
    };
}
