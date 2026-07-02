{
  config,
  pkgs,
  ...
}: {
  imports = [
    ../../modules/rawtalk
    ../../modules/emacs-daemon.nix
    ../../modules/atomic-chrome.nix
    ../../modules/kanata
  ];

  users.users.morph = {
    home = "/Users/morph";
    shell = pkgs.zsh;
  };

  networking = {
    computerName = "mbp-darwin";
    hostName = "mbp-darwin";
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
      duti
      bat
      stow
      tldr
      autojump
      starship
      opencode
      cachix
      gh
      fzf
      eza
      btop
      dog
      duf
      dust
      tokei
      delta
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
    taps = [
      # "nikitabobko/tap"
      # "deskflow/tap"
    ];
    onActivation = {
      autoUpdate = false;
      cleanup = "none";
      upgrade = false;
    };
    brews = [];
    # GUI apps that require homebrew casks
    casks = [
      # "aerospace"
      # "alt-tab"
      # "deskflow"
      "ghostty"
      "hiddenbar"
      "karabiner-elements"
      "keycastr"
      "raycast"
      "spotify"
      "ghostty"
      "utm"
      "secretive"
    ];
  };

  nix = {
    package = pkgs.nix;
    extraOptions = ''
      auto-optimise-store = true
      experimental-features = nix-command flakes
      gc-keep-outputs = true
      gc-keep-derivations = true
      extra-substituters = https://jedimaster.cachix.org https://nix-community.cachix.org
      extra-trusted-public-keys = jedimaster.cachix.org-1:d3z8VEyrrqcYEe/9wOhIa6iXb4ArWUoQLB5tz1b+CZA= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=
    '';
    enable = false;
  };

  nixpkgs.config = {
    allowUnfree = true;
    allowUnsupportedSystem = true;
  };

  nixpkgs.overlays = [];

  services.openssh = {
    enable = true;
  };

  # Tailscale mesh VPN with SSH access
  services.tailscale = {
    enable = true;
  };

  # Cachix auth token for pushing to jedimaster cache
  age.secrets.cachix-token.file = ../../secrets/cachix-token.age;

  # Kanata key remapper (cross-platform, migrated from keyd)
  services.kanata-remapper = {
    enable = true;
    # Uses shared kanata.kbd config by default (CapsLock→Esc/Ctrl, vim mode, etc.)
  };

  # Rawtalk QMK Layer Switcher Service
  services.rawtalk = {
    enable = true;
  };

  services.emacs-daemon = {
    enable = false;
    package = pkgs.emacs;
    socketActivation = false;
  };

  # Touch ID for sudo (incl. inside tmux via pam_reattach)
  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;
  };

  system = {
    primaryUser = "morph";
    defaults = {
      NSGlobalDomain = {
        KeyRepeat = 1;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
        NSAutomaticWindowAnimationsEnabled = false;
        NSWindowResizeTime = 0.001;
      };
      dock = {
        autohide = true;
        orientation = "bottom";
        showhidden = true;
        tilesize = 40;
        launchanim = false;
        autohide-delay = 0.0;
        autohide-time-modifier = 0.0;
        expose-animation-duration = 0.1;
      };
      finder = {
        QuitMenuItem = false;
        AppleShowAllExtensions = true;
        ShowPathbar = true;
        ShowStatusBar = true;
        FXPreferredViewStyle = "Nlsv";
        FXDefaultSearchScope = "SCcf";
        FXEnableExtensionChangeWarning = false;
        _FXSortFoldersFirst = true;
      };
      trackpad = {
        Clicking = true;
        TrackpadRightClick = true;
      };
      spaces = {
        spans-displays = true;
      };
    };
    keyboard = {
      enableKeyMapping = true;
    };

    activationScripts.postActivation.text = ''
      sudo -u morph bash -c '
        defaults write com.apple.finder FXPreferredGroupBy -string "Date Modified"
        find ~/Documents ~/Downloads ~/Desktop -name ".DS_Store" -depth -exec rm {} \; 2>/dev/null || true
        killall Finder 2>/dev/null || true
      '

      # Kanata uses Karabiner's VirtualHIDDevice as its output driver, but
      # karabiner-elements' Karabiner-Core-Service also grabs the input
      # devices, leaving kanata with IOHIDDeviceOpen "not permitted". Stop
      # and disable everything from karabiner-elements; keep the
      # VirtualHIDDevice-Daemon running since that's what kanata talks to.
      launchctl disable system/org.pqrs.service.daemon.Karabiner-Core-Service 2>/dev/null || true
      launchctl bootout system/org.pqrs.service.daemon.Karabiner-Core-Service 2>/dev/null || true

      morph_uid=$(id -u morph)
      for agent in \
        org.pqrs.service.agent.Karabiner-Core-Service \
        org.pqrs.service.agent.Karabiner-Menu \
        org.pqrs.service.agent.Karabiner-NotificationWindow \
        org.pqrs.service.agent.karabiner_console_user_server \
        org.pqrs.service.agent.karabiner_session_monitor
      do
        launchctl disable "gui/$morph_uid/$agent" 2>/dev/null || true
        launchctl bootout "gui/$morph_uid/$agent" 2>/dev/null || true
      done

      # bootout asks launchd to stop the service, but karabiner-elements'
      # menu-bar app and login-item registrations re-spawn these processes
      # quickly. Force-kill any survivors so the input devices are free for
      # kanata before we kickstart it below.
      for proc in \
        Karabiner-Core-Service \
        Karabiner-Menu \
        Karabiner-NotificationWindow \
        karabiner_console_user_server \
        karabiner_session_monitor
      do
        /usr/bin/pkill -x "$proc" 2>/dev/null || true
      done

      launchctl kickstart -k system/org.kanata.daemon 2>/dev/null || true

      # One-time manual step after first karabiner-elements install:
      # open Karabiner-Elements and allow the system extension in
      # System Settings -> Privacy & Security. After that, this activation
      # script handles the rest.
    '';

    stateVersion = 4;
  };
}
