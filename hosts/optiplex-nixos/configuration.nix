{
  config,
  pkgs,
  ...
}: {
  imports = [
    ../../modules/ssh-hardened.nix
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./tailscale.nix
    ./rustdesk.nix # RustDesk server for remote access
    ./rustdesk-client.nix # RustDesk client configuration
    # ./remote-desktop.nix  # Disabled - replaced by sway.nix
    ./sway.nix # Sway window manager with WayVNC
    ./waydroid.nix
    ./wake-on-lan.nix
    ./deskflow.nix # Barrier for keyboard/mouse sharing
    ./roon.nix
    ./code-server.nix
    ./vert.nix
    ./searxng.nix
    ./croc.nix
    ./jellyfin-stack.nix
    ./stremio-working.nix # Working Stremio web proxy
    ./silverbullet.nix
    ./esphome.nix # XIAO ESP32-S3 camera system
    # ./zfs.nix
  ];

  nixpkgs.config.allowUnfree = true;

  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;
  boot.extraModulePackages = [
    config.boot.kernelPackages.rtl8814au
  ];

  # Pin to latest LTS kernel for stability and security
  # This prevents automatic kernel updates on every build
  boot.kernelPackages = pkgs.linuxPackages_6_12;

  # Auto-reboot on kernel panic (wait 10 seconds then reboot)
  boot.kernelParams = [
    "panic=10" # Reboot 10 seconds after kernel panic
    "oops=panic" # Treat kernel oops as panic (reboot on oops too)
  ];

  networking.hostName = "optiplex-nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://proxy.example.com:8080";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  networking.networkmanager.enable = true;

  time.timeZone = "America/New_York";

  i18n.defaultLocale = "en_US.UTF-8";

  services = {
    # Sway with greetd autologin (configured in sway.nix)
    # Removed GNOME/GDM configuration - using Sway + greetd instead

    # Prevent system from suspending/hibernating; keep always on
    logind = {
      settings = {
        Login = {
          IdleAction = "ignore";
          IdleActionSec = 0;
          HandleSuspendKey = "ignore";
          HandleHibernateKey = "ignore";
        };
      };
    };

    # emacs = {
    #   # package = pkgs.emacs-unstable;
    #   # package = pkgs.emacs-git;
    #   package = pkgs.emacs;
    #   enable = true;
    #   install = true;
    # };

    xserver = {
      enable = true;
      # displayManager = {
      #   startx.enable = true;
      #   defaultSession = "plasma";
      #   autoLogin = {
      #     enable = true;
      #     user = "morph";
      #   };
      #   sddm.enable = true;
      # };

      # i3 kept available as fallback (can select at login)
      windowManager.i3 = {
        enable = true;
        package = pkgs.i3;

        extraPackages = with pkgs; [
          dmenu
          i3status
          i3lock
          sxhkd
        ];
      };
    };
    jellyfin = {
      enable = true;
      # Run as morph so it can access /home/morph/iCloud media
      user = "morph";
      group = "users";
      openFirewall = true; # opens 8096/tcp and 8920/tcp
      # Keep state in standard locations but owned by the service user
      dataDir = "/var/lib/jellyfin";
      cacheDir = "/var/cache/jellyfin";
    };

    # Enable Avahi for mDNS/Bonjour discovery (needed for Apple TV auto-discovery)
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
      publish = {
        enable = true;
        addresses = true;
        workstation = true;
        userServices = true;
      };
    };
    # vscode-server.enable = true;
    # And then enable them for the relevant users:
    # systemctl --user enable auto-fix-vscode-server.service

    syncthing = {
      enable = true;
      dataDir = "/home/morph";
      openDefaultPorts = true;
      configDir = "/home/morph/.config/syncthing";
      user = "morph";
      group = "users";
      guiAddress = "127.0.0.1:8384";
      overrideDevices = true;
      overrideFolders = true;
      settings.devices = {
        "xps17-nixos" = {id = "MX3EJ5F-VQWN4O5-7DB2MZG-BQPUKVT-W6KJJJM-4GBZ7RA-ZRVXERL-GU5ZMQS";};
        "macmini-darwin" = {id = "OK4365M-ZZC4CDT-A6W2YF2-MPIX3GR-FYZIWWJ-5QS6RYM-5KYU35K-SLYBHQO";};
      };

      # settings.folders = {
      #   # "Org" = {
      #   #   path = "/home/morph/Org/";
      #   #   id = "Org";
      #   #   devices = ["xps17-nixos" "macmini-darwin"];
      #   #   versioning = {
      #   #     type = "staggered";
      #   #     params = {
      #   #       cleanInterval = "3600";
      #   #       maxAge = "15768000";
      #   #     };
      #   #   };
      #   # };

      #   # "iCloud" = {
      #   #   path = "/home/morph/iCloud/";
      #   #   id = "iCloud";
      #   #   devices = ["xps17-nixos" "macmini-darwin"];
      #   #   versioning = {
      #   #     type = "staggered";
      #   #     params = {
      #   #       cleanInterval = "3600";
      #   #       maxAge = "15768000";
      #   #     };
      #   #   };
      #   # };
      # };
    };
  };

  # Hardware watchdog - reboots system if it becomes unresponsive
  systemd.settings.Manager = {
    WatchdogDevice = "/dev/watchdog";
    RuntimeWatchdogSec = "30s"; # Reboot if systemd doesn't pet watchdog within 30s
    RebootWatchdogSec = "10min"; # Force reboot if graceful reboot takes >10min
    KExecWatchdogSec = "10min";
  };

  # Disable all sleep-related systemd targets
  systemd = {
    targets.sleep.enable = false;
    targets.suspend.enable = false;
    targets.hibernate.enable = false;
    targets.hybrid-sleep.enable = false;
    tmpfiles.rules = [
      # Ensure Jellyfin state/cache directories exist and are writable by morph
      "d /var/lib/jellyfin 0750 morph users - -"
      "d /var/cache/jellyfin 0750 morph users - -"
    ];
    services.jellyfin.path = [pkgs.jellyfin-ffmpeg];
  };

  # Improve filesystem event watching so Jellyfin detects new files immediately
  boot.kernel.sysctl = {
    "fs.inotify.max_user_watches" = 1048576;
    "fs.inotify.max_user_instances" = 1024;
    # Auto-reboot on hung tasks and soft lockups
    "kernel.hung_task_panic" = 1;
    "kernel.hung_task_timeout_secs" = 120;
    "kernel.softlockup_panic" = 1;
  };

  # Configure keymap in X11
  #   "eurosign:e";
  #   "caps:escape" # map caps to escape.
  # };

  services.printing.enable = true;

  # Enable sound.
  # sound.enable = true;
  # hardware.pulseaudio.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).

  # Define a user account. Don't forget to set a password with 'passwd'.
  users = {
    defaultUserShell = pkgs.zsh;
    users.morph = {
      isNormalUser = true;
      extraGroups = ["networkmanager" "wheel" "docker"]; # Enable 'sudo' for the user.
      shell = pkgs.zsh;
      # packages = with pkgs; [ thunderbird ];
    };
  };

  # Enable passwordless sudo for wheel group (required for remote NixOS rebuilds)
  security.sudo.wheelNeedsPassword = false;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };
  programs.zsh.enable = true;

  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?

  virtualisation.docker.enable = true;

  # Open firewall ports for self-hosted apps and BitTorrent forwarding
  networking.firewall.allowedTCPPorts = [
    5055 # Jellyseerr
    6767 # Bazarr
    7878 # Radarr
    8191 # FlareSolverr
    8686 # Lidarr
    8888 # SearXNG
    8989 # Sonarr
    9696 # Prowlarr
    8701 # qBittorrent WebUI (via Gluetun)
  ];
  networking.firewall.allowedUDPPorts = [
    6881 # qBittorrent peer traffic
  ];

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  nix.settings.experimental-features = ["nix-command" "flakes"];

  # nix-community cache for pre-built emacs-unstable and other packages
  nix.settings.substituters = [
    "https://cache.nixos.org"
    "https://nix-community.cachix.org"
  ];
  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  ];

  # Automatic GC + store optimisation (server host — keep disk in check)
  nix.gc = {
    automatic = true;
    options = "--delete-older-than 14d";
  };
  nix.optimise.automatic = true;

  # networking.firewall = {
  #   # warning: Strict reverse path filtering breaks Tailscale
  #   # exit node use and some subnet routing setups.
  #   checkReversePath = "loose";
  #   # enable the firewall
  #   enable = true;

  #   # always allow traffic from your Tailscale network
  #   trustedInterfaces = ["tailscale0"];

  #   # allow the Tailscale UDP port through the firewall
  #   allowedUDPPorts = [config.services.tailscale.port];

  #   # allow you to SSH in over the public internet
  #   allowedTCPPorts = [22];
  # };

  environment.systemPackages = with pkgs; [
    vim
    wget
    discord
    tealdeer
    xclip
    git
    stow
    zsh
    tmux
    starship
    # atuin
    ghostty
    ranger
    eza
    autojump
    bat
    which
    gnumake
    tailscale
    vscode
    rustup
    cargo
    rage
    brave
    firefox
    neovim
    flashrom
    code-cursor
    dysk
    docker-compose
    claude-code
    nodejs_20 # Required for VSCode/Cursor Remote SSH
  ];
}
