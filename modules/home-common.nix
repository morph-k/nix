# Home-manager packages shared across all hosts.
# Host-specific packages stay in each host's home.nix; anything common to
# every host lives here so it's declared once (prevents cross-host drift).
{pkgs, ...}: {
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

    # Other utilities
    tealdeer
    ranger
    stylua
  ];
}
