# WSL host. Kept hand-written (rather than routed through lib.mkNixos) because
# it has no home-manager, uses the nixos-wsl module, and its modules expect the
# raw flake inputs (nixos-wsl, agenix, nixified-ai) as named specialArgs.
{
  inputs,
  user,
  ...
}:
inputs.nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  specialArgs = inputs // {inherit user;};
  modules = [
    ./configuration.nix
    inputs.nixos-wsl.nixosModules.wsl
    ({pkgs, ...}: {
      environment.systemPackages = [pkgs.alejandra];
    })
  ];
}
