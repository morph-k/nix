{
  config,
  pkgs,
  ...
}: {
  imports = [
    ../../modules/rawtalk
    # Emacs modules disabled - using stow + simple nix package instead
    # ../../modules/emacs-daemon.nix
    # ../../modules/atomic-chrome.nix
    ../../modules/kanata
  ];

  users.users.morph = {
    home = "/Users/morph";
    shell = pkgs.zsh;
  };

  networking = {
    computerName = "macmini-darwin";
    hostName = "macmini-darwin";
  };

  # fonts = {
  #   # Fonts
  #   fontDir.enable = true;
  #   fonts = with pkgs; [
  #     source-code-pro
  #     font-awesome
  #     (nerdfonts.override {
  #       fonts = [
  #         "FiraCode"
  #         "JetBrainsMono"
  #       ];
  #     })
  #   ];
  # };

  environment = {
    shells = with pkgs; [zsh];
    variables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      TERMINAL = "ghostty";
    };
    systemPackages = with pkgs; [
      # Terminal
      git
      fd
      ripgrep
      # PDF viewer setup
      duti
      # Emacs daemon wrapper for single-instance behavior
      /*
      (pkgs.writeShellScriptBin "emacs" ''
        # Function to start daemon if not running
        start_daemon_if_needed() {
          if ! ${morph-emacs.packages.aarch64-darwin.default}/bin/emacsclient -e "t" >/dev/null 2>&1; then
            ${morph-emacs.packages.aarch64-darwin.default}/bin/emacs --daemon >/dev/null 2>&1 &
            # Wait for daemon to start
            for i in {1..10}; do
              if ${morph-emacs.packages.aarch64-darwin.default}/bin/emacsclient -e "t" >/dev/null 2>&1; then
                break
              fi
              sleep 0.5
            done
          fi
        }

        # Start daemon if needed and connect
        start_daemon_if_needed
        exec ${morph-emacs.packages.aarch64-darwin.default}/bin/emacsclient -c -a "" "$@"
      '')
      */
    ];
  };

  programs = {
    zsh.enable = true;
  };

  homebrew = {
    # Temporarily disable nix-darwin Homebrew management to bypass bundle crash
    enable = true;
    global = {
      brewfile = false;
    };
    taps = [];
    onActivation = {
      autoUpdate = false;
      cleanup = "none";
      upgrade = false;
    };
    brews = [];
    # GUI apps that require homebrew casks
    casks = [
      "raycast"
      # "spotify"
      "aerospace"
      # "alt-tab"
      "background-music"
      "barrier"
      "buzz"
      "deskflow"
      "flameshot"
      "font-fira-code-nerd-font"
      "free-gpgmail"
      "gcloud-cli"
      "ghostty"
      "gpg-suite-no-mail"
      "hashicorp-vagrant"
      "hiddenbar"
      "keycastr"
      "libndi"
      "mactex"
      "miniforge"
      "notunes"
      "qmk-toolbox"
      "raspberry-pi-imager"
      "raycast"
      "spotify"
      "utm"
      "vlc"
    ];
  };

  nix = {
    package = pkgs.nix;
    # gc = {
    #   # Garbage collection
    #   automatic = true;
    #   interval.Day = 7;
    #   options = "--delete-older-than 7d";
    # };
    extraOptions = ''
      auto-optimise-store = true
      experimental-features = nix-command flakes
      gc-keep-outputs = true
      gc-keep-derivations = true
    '';
    enable = false;
  };

  nixpkgs.config = {
    allowUnfree = true;
    allowUnsupportedSystem = true;
    # # insecure package needed for nixops
    # permittedInsecurePackages = [
    #   "python2.7-pyjwt-1.7.1"
    # ];
  };

  nixpkgs.overlays = [];

  # Kanata key remapper (cross-platform, migrated from keyd)
  services.kanata-remapper = {
    enable = true;
  };

  # Rawtalk QMK Layer Switcher Service
  services.rawtalk = {
    enable = true;
  };

  # Emacs daemon service - DISABLED
  # Using stow + simple nix package approach instead of flake-based config
  # services.emacs-daemon = {
  #   enable = false;
  #   package = pkgs.emacs;
  #   socketActivation = false;
  # };

  # Atomic Chrome service - DISABLED
  # services.atomic-chrome = {
  #   enable = false;
  # };

  system = {
    primaryUser = "morph";
    defaults = {
      NSGlobalDomain = {
        KeyRepeat = 1;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;

        # Disable/reduce animations
        NSAutomaticWindowAnimationsEnabled = false; # Disable window open/close animations
        NSWindowResizeTime = 0.001; # Speed up window resize animations
        # "com.apple.mouse.linear" = true;  # Disable smooth scrolling - NOT SUPPORTED by nix-darwin
      };
      dock = {
        autohide = true;
        orientation = "left";
        showhidden = true;
        tilesize = 40;
        # mineffect = "genie";
        launchanim = false; # Disable Dock app launch animations
        # show-process-indicators = true;
        # show-recents = true;

        # Additional animation settings
        autohide-delay = 0.0; # Remove delay when showing/hiding Dock
        autohide-time-modifier = 0.0; # Remove animation when showing/hiding Dock
        expose-animation-duration = 0.1; # Speed up Mission Control animations
      };
      finder = {
        QuitMenuItem = false; # I believe this probably will need to be true if using spacebar
        # DisableAllAnimations = true;  # NOT SUPPORTED by nix-darwin

        # View and display settings
        AppleShowAllExtensions = true; # Show all file extensions
        ShowPathbar = true; # Show path bar at bottom
        ShowStatusBar = true; # Show status bar at bottom
        FXPreferredViewStyle = "Nlsv"; # Default view: Nlsv = List, icnv = Icon, clmv = Column, glyv = Gallery
        FXDefaultSearchScope = "SCcf"; # Search current folder by default
        FXEnableExtensionChangeWarning = false; # Disable warning when changing file extension
        _FXSortFoldersFirst = true; # Keep folders on top when sorting
      };
      trackpad = {
        Clicking = true;
        TrackpadRightClick = true;
      };
      spaces = {
        # Prevent other displays from going black when one is fullscreen
        spans-displays = true;
      };
    };
    keyboard = {
      enableKeyMapping = true; # Needed for skhd
    };
    # activationScripts.postActivation.text = ''
    #   sudo chsh -s ${pkgs.zsh}/bin/zsh
    #   # Setup Zathura PDF viewer if it's installed
    #   if command -v zathura &> /dev/null; then
    #     chmod +x ${./setup-zathura.sh}
    #     ${./setup-zathura.sh}
    #   fi
    # ''; # Since it's not possible to declare default shell, run this command after build

    # Finder configuration activation script
    activationScripts.postActivation.text = ''
      # Run user-specific Finder configuration as the morph user
      sudo -u morph bash -c '
        # Configure Finder to sort by Date Modified (newest first)
        defaults write com.apple.finder FXPreferredGroupBy -string "Date Modified"

        # Remove .DS_Store files to force Finder to use new defaults
        # Only remove from common user directories to avoid system issues
        find ~/Documents ~/Downloads ~/Desktop -name ".DS_Store" -depth -exec rm {} \; 2>/dev/null || true

        # Restart Finder to apply changes
        killall Finder 2>/dev/null || true
      '
    '';

    stateVersion = 4;
  };
}
