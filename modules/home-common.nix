# Home-manager packages shared across all hosts.
# Host-specific packages stay in each host's home.nix; anything common to
# every host lives here so it's declared once (prevents cross-host drift).
{
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    # Shell & navigation
    zsh
    starship
    autojump

    # File tools
    ripgrep
    fd
    fzf
    eza
    bat
    edir

    # Git & version control
    gh
    delta

    # Text/document processing
    pandoc
    jq

    # Development & multiplexing
    tmux
    abduco

    # Languages & runtimes
    go
    ruby
    jupyter

    # Network & communication
    curl
    croc

    # Email
    neomutt
    isync

    # Archive
    p7zip

    # Nix tooling
    nix-index # `nix-locate` a file -> the package providing it
    comma # `, <cmd>` runs a program without installing it (needs nix-index's db)

    # Other utilities
    tealdeer
    ranger
    stylua
  ];

  programs = {
    # direnv: per-directory environments (https://github.com/direnv/direnv).
    # nix-direnv replaces direnv's stock `use nix`/`use flake` with a version
    # that caches the evaluated environment and registers it as a GC root, so
    # entering a project is instant instead of re-evaluating the flake. It
    # relies on gc-keep-outputs/gc-keep-derivations, which the Darwin hosts
    # already set in configuration.nix.
    direnv = {
      enable = true;
      nix-direnv.enable = true;

      # Same convention as mcfly in home-darwin-common.nix: zsh is not a
      # home-manager program on these hosts (~/.zshrc is stowed from ~/dots),
      # so home-manager has no initExtra to write the hook into. The
      # `direnv hook zsh` line lives in the stowed ~/.zshrc instead.
      # mkDefault, not a plain false: a host whose shell *is* managed by
      # home-manager (omarchy-linux, via omarchy-nix's zsh module) sets this
      # to true, and an unprefixed false here would be a conflict rather than
      # an override.
      enableZshIntegration = lib.mkDefault false;
      enableBashIntegration = lib.mkDefault false;
    };
  };
}
