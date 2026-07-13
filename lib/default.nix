# Host builders shared by every configuration in this flake.
#
# The goal is that each hosts/*/default.nix only declares what is *different*
# about that machine (its modules, overlays, extra home-manager args) while the
# common scaffolding — home-manager wiring, agenix, the alejandra/agenix
# system packages, the emacs overlay on Darwin — lives here once.
{
  inputs,
  user,
}: let
  inherit (inputs) nixpkgs home-manager darwin agenix;

  # Standard home-manager block. `home` is the path to the host's home.nix.
  mkHome = {
    home,
    sharedModules ? [],
    extraArgs ? {},
  }: {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
      users.${user}.imports = [home];
      inherit sharedModules;
      extraSpecialArgs = {inherit inputs user;} // extraArgs;
    };
  };
in {
  inherit mkHome;

  # Build a nix-darwin system. Every Darwin host gets agenix, home-manager,
  # the hardened-ssh module, the emacs overlay, and the shared tool packages.
  mkDarwin = {
    system ? "aarch64-darwin",
    home,
    modules ? [],
    overlays ? [],
    hmSharedModules ? [],
    hmExtraArgs ? {},
  }:
    darwin.lib.darwinSystem {
      inherit system;
      specialArgs = {
        inherit inputs user;
        rawtalk = inputs.rawtalk;
      };
      modules =
        [
          agenix.darwinModules.default
          home-manager.darwinModules.home-manager
          ../modules/ssh-hardened-darwin.nix
          ({pkgs, ...}: {
            nixpkgs.overlays = [inputs.emacs-overlay.overlays.default] ++ overlays;
            environment.systemPackages = [
              pkgs.alejandra
              agenix.packages.${system}.default
              inputs.rawtalk.packages.${system}.default
            ];
          })
          (mkHome {
            inherit home;
            sharedModules = hmSharedModules;
            extraArgs = hmExtraArgs;
          })
        ]
        ++ modules;
    };

  # Build a NixOS system. Pass `home = null` for hosts without home-manager.
  mkNixos = {
    system ? "x86_64-linux",
    home ? null,
    modules ? [],
    overlays ? [],
    hmSharedModules ? [],
    hmExtraArgs ? {},
  }:
    nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {inherit inputs user;};
      modules =
        [
          agenix.nixosModules.default
          ({pkgs, ...}: {
            nixpkgs.overlays = overlays;
            environment.systemPackages = [
              pkgs.alejandra
              agenix.packages.${system}.default
            ];
          })
        ]
        ++ nixpkgs.lib.optionals (home != null) [
          home-manager.nixosModules.home-manager
          (mkHome {
            inherit home;
            sharedModules = hmSharedModules;
            extraArgs = hmExtraArgs;
          })
        ]
        ++ modules;
    };
}
