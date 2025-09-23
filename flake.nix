{
  description = "A NixOS module to automatically set up DDCCI for external monitors on NVIDIA systems";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    nixosModules.default = import ./ddcci.nix;
  };
}
