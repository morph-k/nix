{
  user,
  nixpkgs,
  darwin,
  inputs,
  home-manager,
  agenix,
  emacs-overlay,
  rawtalk,
  ...
}:
darwin.lib.darwinSystem {
  system = "aarch64-darwin";
  specialArgs = {inherit rawtalk;};
  modules = [
    agenix.darwinModules.default
    ./configuration.nix
    ../../modules/ssh-hardened-darwin.nix
    # ./restic.nix
    {
      environment.systemPackages = with nixpkgs.legacyPackages.aarch64-darwin; [
        alejandra
        agenix.packages.aarch64-darwin.default
        rawtalk.packages.aarch64-darwin.default
      ];
    }
    home-manager.darwinModules.home-manager
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.morph = import ./home.nix;
      home-manager.backupFileExtension = "backup";
    }
    {
      nixpkgs.overlays = [emacs-overlay.overlays.default];
    }
  ];
}
