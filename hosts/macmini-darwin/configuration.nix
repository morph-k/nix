{pkgs, ...}: {
  imports = [
    ../../modules/rawtalk
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

  environment = {
    shells = with pkgs; [zsh];
    variables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      TERMINAL = "ghostty";
    };
    systemPackages = with pkgs; [
      git
      fd
      ripgrep
      duti # sets default app associations (e.g. PDF viewer)
    ];
  };

  programs = {
    zsh.enable = true;
  };

  homebrew = {
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
      "utm"
      "vlc"
    ];
  };

  nix = {
    package = pkgs.nix;
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
  };

  # Kanata key remapper (cross-platform, migrated from keyd)
  services.kanata-remapper = {
    enable = true;
  };

  # Rawtalk QMK Layer Switcher Service
  services.rawtalk = {
    enable = true;
  };

  system = {
    primaryUser = "morph";
    defaults = {
      NSGlobalDomain = {
        KeyRepeat = 1;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;

        # Disable/reduce animations
        NSAutomaticWindowAnimationsEnabled = false;
        NSWindowResizeTime = 0.001;
      };
      dock = {
        autohide = true;
        orientation = "left";
        showhidden = true;
        tilesize = 40;
        launchanim = false;

        # Remove Dock/Mission Control animation delays
        autohide-delay = 0.0;
        autohide-time-modifier = 0.0;
        expose-animation-duration = 0.1;
      };
      finder = {
        QuitMenuItem = false;
        AppleShowAllExtensions = true;
        ShowPathbar = true;
        ShowStatusBar = true;
        FXPreferredViewStyle = "Nlsv"; # Nlsv=List, icnv=Icon, clmv=Column, glyv=Gallery
        FXDefaultSearchScope = "SCcf"; # SCcf = search current folder
        FXEnableExtensionChangeWarning = false;
        _FXSortFoldersFirst = true;
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
      enableKeyMapping = true;
    };

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
