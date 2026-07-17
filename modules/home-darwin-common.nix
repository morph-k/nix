# Shared home-manager config for the Darwin hosts (macmini, mbp).
# Each host's home.nix imports this and only adds its host-unique packages.
{
  pkgs,
  user,
  ...
}: let
  # Homebrew 6.0 refuses to load formulae/casks from third-party taps unless
  # they are trusted. `brew trust` writes to $XDG_CONFIG_HOME/homebrew/trust.json
  # when that is set and ~/.homebrew/trust.json otherwise; nix-darwin runs
  # `brew bundle` through sudo, which resets the environment and drops
  # XDG_CONFIG_HOME. Write both paths so activation and interactive shells agree.
  trustedTaps = {
    trustedtaps = [
      "deskflow/tap" # deskflow
      "nikitabobko/tap" # aerospace
    ];
  };
  trustFile = (pkgs.formats.json {}).generate "homebrew-trust.json" trustedTaps;
in {
  imports = [
    ./home-common.nix
    ./lf
    ./zathura
    ./hammerspoon.nix
  ];

  # force: these paths may already hold a real file written by `brew trust`.
  home.file = {
    ".homebrew/trust.json" = {
      source = trustFile;
      force = true;
    };
    ".config/homebrew/trust.json" = {
      source = trustFile;
      force = true;
    };
  };

  programs = {
    home-manager = {
      enable = true;
    };

    # mcfly (Ctrl-R history): package + options managed here. The `mcfly init zsh`
    # hook stays in the stowed ~/.zshrc since zsh isn't a home-manager program.
    mcfly = {
      enable = true;
      keyScheme = "vim";
      enableZshIntegration = false;
    };

    # Emacs with packages - config is stowed from ~/dots/emacs
    emacs = {
      enable = true;
      package = pkgs.emacs30.override {
        withNativeCompilation = true;
      };
      extraPackages = epkgs:
        with epkgs; [
          # Core
          use-package
          gcmh

          # Evil ecosystem
          evil
          evil-collection
          evil-org
          evil-commentary
          undo-tree

          # Completion
          counsel
          counsel-tramp
          ivy
          swiper
          flx

          # Git
          magit
          magit-delta
          git-commit
          magit-section
          with-editor
          git-timemachine

          # Org ecosystem
          org-roam
          org-roam-ui
          org-msg
          org-transclusion
          # md-roam adds Markdown support to org-roam (indexes exported Apple
          # Notes .md files as roam nodes). It is not on MELPA / in nixpkgs, so
          # build it from source. To bump: change rev, then run
          #   nix store prefetch-file --unpack https://github.com/nobiot/md-roam/archive/<rev>.tar.gz
          # and paste the reported hash below.
          (epkgs.trivialBuild {
            pname = "md-roam";
            version = "20250419.1521";
            src = pkgs.fetchFromGitHub {
              owner = "nobiot";
              repo = "md-roam";
              rev = "1113a568138c1e1084a3cd41a04a9cff2ff14a72";
              hash = "sha256-YxkL6vqabh2qkmgH2zUNFhUoQBQ07sjj9bFdFrWGlf0=";
            };
            packageRequires = with epkgs; [org-roam markdown-mode];
          })

          # Terminal
          vterm
          multi-vterm
          eat

          # UI/UX
          which-key
          rainbow-delimiters
          olivetti
          deadgrep
          circadian
          autothemer
          gruvbox-theme
          modus-themes

          # Dired
          dired-hide-dotfiles
          nerd-icons-dired
          nerd-icons
          async

          # Editing
          yasnippet
          markdown-mode
          nix-mode
          slime
          pdf-tools

          # Utilities
          exec-path-from-shell
          atomic-chrome
        ];
    };
  };

  home = {
    username = user;
    stateVersion = "22.05";

    shellAliases = {
      zathura = "open -a Zathura";
    };

    # Host-unique packages are added in each host's home.nix (lists merge).
    packages = with pkgs; [
      # NOTE: CLI tools common to all hosts live in modules/home-common.nix.

      # Archive/compression
      xz
      zstd

      # File tools
      tree
      rename
      fswatch

      # Text/document processing
      gum

      # Development tools
      coreutils
      cmake
      meson
      ninja
      gnused
      moreutils

      # Languages & runtimes
      lua
      luarocks
      nodejs

      # Python tools
      pipx
      poetry
      uv

      # System monitoring
      btop

      # Media & documents
      ffmpeg
      imagemagick
      mupdf

      # Network & communication
      wget

      # Email tools
      notmuch
      msmtp

      # Security & encryption
      age
      age-plugin-yubikey # PIV/age identities held on a YubiKey (agenix recipient)
      yubikey-manager # `ykman` for managing the YubiKey

      # Nix tools
      deadnix

      # Other utilities
      stow
    ];
  };
}
