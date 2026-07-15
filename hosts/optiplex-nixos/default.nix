{mkNixos, ...}:
mkNixos {
  home = ./home.nix;
  modules = [
    ./configuration.nix
    ../../modules/tailscale
  ];
  overlays = [
    (import ../../overlays/rustdesk-gcc15.nix)
  ];
}
