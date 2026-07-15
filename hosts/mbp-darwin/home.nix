# mbp home config. Shared Darwin home setup lives in
# modules/home-darwin-common.nix; only host-unique bits go here.
{pkgs, ...}: {
  imports = [
    ../../modules/home-darwin-common.nix
  ];

  # mbp uses nix-your-shell instead of a home-manager-managed neovim.
  home.packages = with pkgs; [
    nix-your-shell
  ];
}
