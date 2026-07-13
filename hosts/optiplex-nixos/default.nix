{
  mkNixos,
  inputs,
  ...
}:
mkNixos {
  home = ./home.nix;
  modules = [
    ./configuration.nix
    ../../modules/tailscale
  ];
  overlays = [
    (import ../../overlays/rustdesk-gcc15.nix)
  ];
  hmExtraArgs = {
    plover = inputs.plover.packages."x86_64-linux".plover;
  };
}
