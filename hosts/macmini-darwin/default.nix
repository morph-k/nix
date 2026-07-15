{mkDarwin, ...}:
mkDarwin {
  home = ./home.nix;
  modules = [
    ./configuration.nix
    ../../modules/restic-darwin.nix
  ];
}
