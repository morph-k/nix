{
  inputs,
  config,
  current,
  pkgs,
  lib,
  plover,
  user,
  agenix,
  ...
}: {
  imports = [
    ../../modules/home-common.nix
    # ../../modules/i3.nix  # Disabled for XFCE
    ../../modules/pass.nix
    ../../modules/fonts.nix
    ../../modules/zathura
    ../../modules/lf
    # ../../modules/nvim.nix
    # ../../modules/redshift.nix
    # ../../modules/picom.nix  # Disabled for XFCE - not needed
    # ./fakwin.nix  # Disabled - not needed with XFCE
    # ../../modules/grobi  # Disabled - using manual xrandr/arandr instead
    # ../../modules/wallpaper.nix  # Disabled for XFCE - use XFCE's own wallpaper settings
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
      profiles.default.extensions = with pkgs.vscode-extensions; [
        dracula-theme.theme-dracula
        vscodevim.vim
        yzhang.markdown-all-in-one
        ms-toolsai.jupyter
      ];
    };
  };

  # Launch Deskflow (Barrier successor) GUI on login; configure server via its UI
  # systemd.user.services.deskflow = {
  #   Unit = {
  #     Description = "Deskflow keyboard/mouse sharing";
  #     PartOf = ["graphical-session.target"];
  #     After = ["graphical-session-pre.target" "tray.target"];
  #   };
  #   Service = {
  #     Type = "simple";
  #     ExecStartPre = "${pkgs.coreutils}/bin/sleep 5";
  #     ExecStart = "${pkgs.deskflow}/bin/deskflow";
  #     Restart = "on-failure";
  #     RestartSec = 5;
  #   };
  #   Install = {
  #     WantedBy = ["graphical-session.target"];
  #   };
  # };

  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = ["qemu:///system"];
      uris = ["qemu:///system"];
    };
  };

  # Note: nixpkgs.config is set at system level in configuration.nix
  # Removed nixpkgs block as it conflicts with home-manager.useGlobalPkgs = true

  home = {
    username = "morph";
    homeDirectory = "/home/morph";
    stateVersion = "22.05";
    packages = with pkgs; [
      # NOTE: CLI tools common to all hosts live in modules/home-common.nix.
      # i3status-rust  # Disabled for XFCE
      clipmenu
      deadnix
      statix
      cargo
      sbcl
      mu
      # msmtp
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
      # fzf-tmux

      # texlive.combined.scheme-full
      (texlive.combine {
        inherit
          (texlive)
          scheme-small
          latexmk
          xetex
          listings
          amsmath
          geometry
          fontspec
          hyperref
          ;
      })

      # qmk
      # qmk-udev-rules
      zip
    ];
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "image/png" = ["sxiv.desktop"];
      "image/jpeg" = ["sxiv.desktop"];
      "image/gif" = ["sxiv.desktop"];
      "image/webp" = ["sxiv.desktop"];
      "image/tiff" = ["sxiv.desktop"];
      "image/bmp" = ["sxiv.desktop"];
      "image/x-icon" = ["sxiv.desktop"];
      "image/x-portable-pixmap" = ["sxiv.desktop"];
      "image/x-portable-bitmap" = ["sxiv.desktop"];
      "image/x-portable-graymap" = ["sxiv.desktop"];
      "image/x-xbitmap" = ["sxiv.desktop"];
      "image/x-xpixmap" = ["sxiv.desktop"];
    };
  };

  # Disabled for XFCE - XFCE has its own panel and configuration system
  # xdg.configFile = {
  #   "i3status-rust/config.toml".text = ''
  #     [theme]
  #     theme = "ctp-mocha"
  #
  #     [icons]
  #     icons = "awesome6"
  #
  #     # Time
  #     [[block]]
  #     block = "time"
  #     interval = 5
  #     format = "%a %d/%m %H:%M"
  #
  #     # Currently playing media (via MPRIS)
  #     [[block]]
  #     block = "music"
  #
  #     # System load averages
  #     [[block]]
  #     block = "load"
  #     interval = 5
  #
  #     # CPU usage
  #     [[block]]
  #     block = "cpu"
  #     interval = 1
  #
  #     # Memory usage
  #     [[block]]
  #     block = "memory"
  #   '';
  #
  #   # Prefer wlr portal for RemoteDesktop/Screencast when under sway
  #   # "xdg-desktop-portal/sway-portals.conf".text = ''
  #   #   [preferred]
  #   #   default=gtk
  #   #   org.freedesktop.impl.portal.Screenshot=wlr
  #   #   org.freedesktop.impl.portal.ScreenCast=wlr
  #   #   org.freedesktop.impl.portal.RemoteDesktop=wlr
  #   # '';
  # };
}
