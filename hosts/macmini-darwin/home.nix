# macmini home config. Shared Darwin home setup lives in
# modules/home-darwin-common.nix; only host-unique bits go here.
{pkgs, ...}: {
  imports = [
    ../../modules/home-darwin-common.nix
  ];

  home.packages = with pkgs; [
    neovim

    # language learning (https://oliverobscure.xyz/posts/free-software-is-cool/)
    # dictd
  ];
}
