{pkgs, ...}: {
  imports = [
    ../../modules/home-common.nix
    ../../modules/i3.nix
    ../../modules/pass.nix
    ../../modules/fonts.nix
    ../../modules/zathura
    ../../modules/lf
    ../../modules/grobi
    ../../modules/wallpaper.nix
    # ../../modules/nvim.nix
    ../../modules/redshift.nix
    # ../../modules/picom.nix
  ];

  services.clipmenu.enable = true;
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
    morphEmacs = {
      enable = true;
    };
    # obs-studio = {
    #   enable = true;
    #   plugins = with pkgs.obs-studio-plugins; [
    #     wlrobs
    #     obs-gstreamer
    #   ];
    # };
    vscode = {
      enable = true;
      extensions = with pkgs.vscode-extensions; [
        dracula-theme.theme-dracula
        vscodevim.vim
        yzhang.markdown-all-in-one
        ms-toolsai.jupyter
      ];
    };
  };

  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = ["qemu:///system"];
      uris = ["qemu:///system"];
    };
  };

  nixpkgs = {
    config.allowUnfree = true;
  };

  home = {
    username = "morph";
    homeDirectory = "/home/morph";
    stateVersion = "22.05";
    packages = with pkgs; [
      # NOTE: CLI tools common to all hosts live in modules/home-common.nix.
      brave
      clipmenu
      cargo
      sbcl
      mu
      msmtp
      pass
      eva
      hexyl
      zathura
      feh
      tree-sitter
      # nodePackages.insect
      file
      newsboat
      neovim
      texlive.combined.scheme-full
      qmk
      qmk-udev-rules
      zip
      dconf

      # python packages
      # (python39.withPackages (pp:
      #   with pp; [
      #     pynvim
      #     # pandas
      #     # reticulate needs conda
      #     # conda
      #     # requests
      #     pip
      #     i3ipc
      #     ipython
      #     dbus-python
      #     html2text
      #     keymapviz
      #     # mysql-connector
      #     # pipx
      #     # pyqt5
      #     ueberzug
      #   ]))
      # https://stackoverflow.com/questions/52941074/in-nixos-how-can-i-resolve-a-collision
      # ]).override (args: { ignoreCollisions = true; }))
    ];
  };
}
