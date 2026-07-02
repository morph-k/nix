{
  config,
  pkgs,
  ...
}: {
  imports = [
    ../../modules/ssh-hardened.nix
    ./configuration.nix
  ];
}
