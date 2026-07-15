# macmini home config. Shared Darwin home setup lives in
# modules/home-darwin-common.nix; only host-unique bits go here.
{pkgs, ...}: {
  imports = [
    ../../modules/home-darwin-common.nix
  ];

  home.packages = with pkgs; [
    neovim

    # Ephemeral Linux VMs on Apple Silicon, driven by the `revm` script in
    # dots/scripts/.local/bin. Unfree (Functional Source License), which
    # modules/darwin-common.nix already permits. Note this is arm64-only:
    # Tart uses Virtualization.framework, which virtualises rather than
    # emulates, so it cannot run x86_64 guests.
    tart

    # language learning (https://oliverobscure.xyz/posts/free-software-is-cool/)
    # dictd
  ];
}
