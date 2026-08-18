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
    # zoxide replaces autojump: same `j <dir>` muscle memory (see the
    # `zoxide init --cmd j` hook in ~/dots/zsh/.zshrc), but written in Rust
    # rather than Python, so it does not pay an interpreter start on every
    # directory change. Existing autojump data is migrated with
    # `zoxide import --from autojump`.
    zoxide

    # File tools
    ripgrep
    fd
    fzf
    eza
    bat
    edir

    # Git & version control
    # git is the single most-used command in this setup by a wide margin
    # (~670 invocations in shell history, 2.5x the next tool), yet it was
    # never declared -- it resolved to Apple's /usr/bin/git, which lags
    # upstream and is not reproducible across hosts.
    git
    gh
    delta
    lazygit # the `lg` alias in ~/dots referenced this without it installed

    # Text/document processing
    pandoc
    jq

    # Development & multiplexing
    tmux
    abduco

    # Languages & runtimes
    go
    # Python tooling from Astral, same family as uv: a Rust reimplementation
    # of flake8/black/isort that runs orders of magnitude faster.
    ruff

    # Network & communication
    curl
    croc
    yt-dlp # used by the ytdl() function in ~/dots/zsh/.zsh_functions

    # Archive
    # ouch handles tar/zip/7z/zst/xz behind one command, replacing the
    # per-format branching the extract() shell function used to need.
    ouch
    p7zip

    # Nix tooling
    nix-index # `nix-locate` a file -> the package providing it
    comma # `, <cmd>` runs a program without installing it (needs nix-index's db)

    # Other utilities
    tealdeer
    ranger
    stylua
    chafa # terminal image viewer; the `icat` alias referenced it

    # Rust-native replacements for common coreutils/procps work. Chosen on
    # the same grounds as uv and ripgrep: single static binary, no
    # interpreter, dramatically faster on large trees.
    dust # `du` — disk usage, sorted and human-readable by default
    procs # `ps` — with tree view and colour
    sd # `sed` for the common find/replace case, without the regex dialect
    hyperfine # statistically sound command benchmarking
    tokei # source line counts
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
