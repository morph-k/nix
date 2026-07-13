{mkDarwin, ...}:
mkDarwin {
  home = ./home.nix;
  modules = [
    ./configuration.nix
    ./restic.nix
  ];
}
