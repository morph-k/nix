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

    # neovim = {
    #   enable = true;
    #   plugins = with pkgs.vimPlugins; [
    #     nvim-treesitter.withAllGrammars
    #     nvim-treesitter-textobjects
    #   ];
    # };
  };

  home = {
    username = "morph";
    stateVersion = "22.05";

    shellAliases = {
      zathura = "open -a Zathura";
    };

    packages = with pkgs; [
      # NOTE: CLI tools common to all hosts live in modules/home-common.nix.

      # Archive/compression
      unar
      xz
      zstd

      # File tools
      tree
      rename
      fswatch
      watchexec

      # Text/document processing
      glow
      gum

      # Development tools
      coreutils
      entr
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
      htop
      dog
      duf
      dust
      tokei

      # Media & documents
      ffmpeg
      imagemagick
      exiftool
      tesseract
      mupdf

      # Network & communication
      wget
      aria2
      socat
      qrcp

      # Email tools
      notmuch
      msmtp

      # Security & encryption
      age
      rage
      age-plugin-yubikey # PIV/age identities held on a YubiKey (agenix recipient)
      yubikey-manager # `ykman` for managing the YubiKey

      # Nix tools
      deadnix
      nix-your-shell

      # Other utilities
      stow
      todoist
      cscope
      minicom
    ];
  };
}
