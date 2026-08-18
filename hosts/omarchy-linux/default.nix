# omarchy-linux: the Linux desktop environment.
#
# Built from omarchy-nix (github:henrysipp/omarchy-nix), a NixOS
# reimplementation of DHH's Arch-based Omarchy: Hyprland, waybar, theming and
# keybinds. Omarchy itself is an Arch distro and cannot be imported directly;
# omarchy-nix is the bridge.
{
  inputs,
  user,
  mkNixos,
  ...
}:
mkNixos {
  system = "x86_64-linux";
  home = ./home.nix;
  overlays = [(import ../../overlays/omarchy-compat.nix)];
  modules = [
    ./configuration.nix
    inputs.omarchy-nix.nixosModules.default
  ];
  # The home-manager side of omarchy-nix reads osConfig.omarchy, so the
  # options set in configuration.nix flow through without repeating them.
  hmSharedModules = [inputs.omarchy-nix.homeManagerModules.default];
}
