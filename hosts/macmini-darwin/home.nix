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

    # Xcode tooling for xcodebuild.nvim. sourcekit-lsp and lldb-dap already
    # come with Xcode itself; xcode-build-server is not in nixpkgs and is
    # installed as a brew in this host's configuration.nix.
    xcbeautify # formats raw xcodebuild output into readable logs

    # pymobiledevice3 (debugging on physical devices, and running on anything
    # below iOS 17) is deliberately absent: it depends on python3Packages.pyimg4,
    # which is marked broken in the current nixpkgs pin, so adding it fails
    # evaluation of the whole host. There is no homebrew formula either.
    # Simulator work does not need it. If a physical device is ever required:
    #   pipx install pymobiledevice3

    # language learning (https://oliverobscure.xyz/posts/free-software-is-cool/)
    # dictd
  ];

  # Swift treesitter support.
  #
  # The neovim config uses built-in vim.treesitter only — no nvim-treesitter
  # plugin — so both halves have to be put on the runtime path by hand. The
  # grammar alone is not enough: without the queries, vim.treesitter.start()
  # fails and Swift buffers fall back to regex syntax with no error shown.
  home.file = {
    ".local/share/nvim/site/parser/swift.so".source =
      "${pkgs.vimPlugins.nvim-treesitter-parsers.swift}/parser/swift.so";

    ".local/share/nvim/site/queries/swift".source =
      "${pkgs.vimPlugins.nvim-treesitter}/runtime/queries/swift";
  };
}
