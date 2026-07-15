{pkgs, ...}: {
  imports = [
    ../../modules/home-common.nix
    # ../../modules/zathura
    ../../modules/lf
  ];

  # services.clipmenu.enable = true;
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
    # morphEmacs = { # Disabled: module not available on Linux
    #   enable = true;
    # };
    obs-studio = {
      enable = true;
      plugins = with pkgs.obs-studio-plugins; [
        wlrobs
        obs-gstreamer
        obs-backgroundremoval
        obs-pipewire-audio-capture
      ];
    };
    # lazygit = {
    #   enable = true;
    #   settings = {
    #     git = {
    #       paging = {
    #         colorArg = "always";
    #         pager = "delta --color-only --dark --paging=never";
    #         useConfig = false;
    #       };
    #     };
    #   };
    # };
    # vscode = {
    #   enable = true;
    #   extensions = with pkgs.vscode-extensions; [
    #     dracula-theme.theme-dracula
    #     vscodevim.vim
    #     yzhang.markdown-all-in-one
    #     ms-toolsai.jupyter
    #   ];
    # };
  };

  home = {
    username = "morph";
    homeDirectory = "/home/morph";
    stateVersion = "22.05";
    packages = with pkgs; [
      # NOTE: CLI tools common to all hosts live in modules/home-common.nix.
      # atuin
      clipmenu
      # cscope
      # pastel
      cargo
      sbcl
      mu
      msmtp
      pass
      # calibre
      # slides
      # sxhkd
      # inkscape
      # gimp
      # blender
      # kicad
      # ffmpeg
      eva
      # aria2
      # hyperfine
      hexyl
      spotify
      # neofetch
      zathura
      # viu
      # mpv
      feh
      # sublime  # removed from nixpkgs; sublime4 fails to evaluate (unfree/broken)
      surfraw
      redshift
      # termite
      tree-sitter
      # rnix-lsp
      gopls
      ccls
      fpp
      # tree-sitter-grammars.tree-sitter-markdown
      # sumneko-lua-language-server
      # nodePackages.typescript-language-server
      # nodePackages.insect
      # nodePackages.mermaid-cli
      # nodePackages.bash-language-server
      # nodePackages.pyright
      # nodePackages.typescript
      prettier
      # ccls
      # mathpix-snipping-tool
      black
      # rust-analyzer
      # postman
      openssl
      # protonvpn-gui
      # protonmail-bridge
      # play-with-mpv
      # rustdesk
      file
      # newsboat
      neovim
      # fasd
      # texlive.combined.scheme-full
      # python2

      # keeb packages
      # via
      qmk
      qmk-udev-rules
      # gcc_multi
      # avrlibc

      # documents packages
      # emacs
      # csv
      # xsv

      # finance
      ledger
      goose-cli

      # todo test this tool
      qrcp

      # python packages
      # (python39.withPackages (pp:
      #   with pp; [
      #     pynvim
      #     pandas
      #     # reticulate needs conda
      #     conda
      #     requests
      #     pip
      #     i3ipc
      #     ipython
      #     dbus-python
      #     html2text
      #     keymapviz
      #     mysql-connector
      #     pipx
      #     pyqt5
      #     ueberzug
      #   ]))
    ];
  };
}
