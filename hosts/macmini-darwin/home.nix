{pkgs, ...}: {
  imports = [
    ../../modules/home-common.nix
    ../../modules/lf
    ../../modules/zathura
    ../../modules/hammerspoon.nix
  ];

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

  # TODO remove homebrew packages
  home = {
    username = "morph";
    stateVersion = "22.05";

    shellAliases = {
      zathura = "open -a Zathura";
    };

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
      neovim
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

      # language learning (https://oliverobscure.xyz/posts/free-software-is-cool/)
      # dictd
    ];
  };
}
