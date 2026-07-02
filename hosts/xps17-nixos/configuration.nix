{
  inputs,
  config,
  current,
  lib,
  pkgs,
  home-manager,
  agenix,
  user,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./keyd.nix
    ./tailscale.nix
    ./syncthing.nix
    # ./rustdesk-client.nix  # Temporarily disabled - rustdesk fails to build with GCC 15
    ./wireshark-usb.nix
    # ../../modules/mullvad
    ../../modules/kanata
    # ./fakwin.nix
    # ./restic.nix
    # ./dslr.nix
  ];

  # Kanata key remapper (cross-platform module)
  services.kanata-remapper = {
    enable = true;
    config = builtins.readFile ../../modules/kanata/xps17.kbd;
    devices = ["/dev/input/by-path/platform-i8042-serio-0-event-kbd"];
    extraDefCfg = "process-unmapped-keys yes";
  };

  # Bootloader.

  # zfs specific
  boot.supportedFilesystems = ["zfs"];
  networking.hostId = "cc5926fa";

  # Use prebuilt kernel from binary cache (6.12 series, ZFS-compatible)
  # Pin to linuxPackages_6_12 to avoid building kernel when nixpkgs is ahead of cache
  boot.kernelPackages = pkgs.linuxPackages_6_12;

  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "nodev";
  boot.loader.grub.useOSProber = true;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.enableCryptodisk = true;

  boot.initrd.luks.devices = {
    root = {
      device = "/dev/disk/by-uuid/f134f473-95f4-4037-a167-600084b82a7e"; ## Use blkid to find this UUID
      # Required even if we're not using LVM
      preLVM = true;
    };
  };

  # Enable networking
  networking = {
    hostName = "xps17-nixos";
    networkmanager.enable = true;
    # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
    firewall = {
      enable = true;

      # always allow traffic from tailscale network
      trustedInterfaces = ["tailscale0"];

      # allow the Tailscale UDP port through the firewall
      allowedUDPPorts = [config.services.tailscale.port];

      # let you SSH in over the public internet
      allowedTCPPorts = [22 24800]; # 24800 = Deskflow/Synergy/Barrier/InputLeap

      allowedTCPPortRanges = [
        {
          from = 1714;
          to = 1764;
        } # KDE Connect
      ];
      allowedUDPPortRanges = [
        {
          from = 1714;
          to = 1764;
        } # KDE Connect
      ];
    };
  };

  services.openssh = {
    enable = true;
    openFirewall = true;
  };

  time.timeZone = "America/New_York";

  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  nix = {
    extraOptions = "experimental-features = nix-command flakes";
    gc = {
      automatic = true;
      options = "--delete-older-than 14d";
    };
    optimise.automatic = true;
    # Add nix-community cache for pre-built emacs-unstable and other packages
    settings = {
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
  };

  # Power management and lid handling
  services.logind = {
    lidSwitch = "suspend"; # Suspend when lid closes on battery
    lidSwitchExternalPower = "suspend"; # Suspend when lid closes on AC power
    lidSwitchDocked = "ignore"; # Ignore lid close when docked (external display)
  };

  # NVIDIA power management for proper suspend/resume
  hardware.nvidia.powerManagement.enable = true;

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;
  };

  # bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  services = {
    emacs = {
      # package = pkgs.emacs-unstable;
      # package = pkgs.emacs-git;
      package = pkgs.emacs;
      enable = true;
      install = true;
    };

    pulseaudio.enable = false;
    blueman.enable = true;

    # printing.enable = true;

    # avahi = {
    #   nssmdns4 = true;
    #   enable = true;
    #   openFirewall = true;
    #   publish = {
    #     enable = true;
    #     userServices = true;
    #     domain = true;
    #   };
    #   allowInterfaces = ["wlp0s20f3" "tailscale0"];
    # };

    # libinput moved out of xserver
    libinput = {
      enable = true;
      # touchpad.disableWhileTyping = true;
    };

    # Display manager
    displayManager = {
      sddm.enable = true;
      defaultSession = "xfce";
      # defaultSession = "i3";
      autoLogin = {
        enable = false;
        user = "morph";
      };
    };

    xserver = {
      enable = true;

      xkb = {
        layout = "us";
        variant = "";
      };

      displayManager.startx.enable = false;

      desktopManager.xfce = {
        enable = true;
        enableXfwm = true; # Use XFCE's lightweight window manager
      };

      # windowManager = {
      #   i3 = {
      #     enable = true;
      #     package = pkgs.i3;
      #   };
      # };
    };
  };

  users.users.morph = {
    isNormalUser = true;
    shell = pkgs.zsh;
    description = "Morphy Kuffour";
    extraGroups = ["networkmanager" "wheel" "libvirtd" "docker" "wireshark"];
    packages = with pkgs; [];
  };

  programs = {
    # Steam
    steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
      localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
    };
    # obs-studio = {
    #   enable = true;
    #   plugins = with pkgs; [ obs-studio-plugins.wlrobs ];
    # };
    kdeconnect.enable = true;

    # waybar.enable = true;  # Disabled for XFCE
    zsh.enable = true;
    mtr.enable = true;
    autojump.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
    thunar = {
      enable = true;
      # plugins = with pkgs.xfce; [
      #   thunar-archive-plugin
      #   thunar-volman
      # ];
    };
  };

  # vms
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
    };
  };
  # Graphical management for libvirt/KVM VMs
  programs.virt-manager.enable = true;
  # Optional but useful for USB passthrough in VMs
  virtualisation.spiceUSBRedirection.enable = true;
  virtualisation.docker = {
    enable = true;
    rootless = {
      enable = true;
      setSocketVariable = true;
    };
  };

  nixpkgs.config.allowUnfree = true;

  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system = {
    # stateVersion = config.system.nixos.release;
    stateVersion = "23.05"; # Did you read the comment?
    autoUpgrade = {
      enable = false;
      allowReboot = false;
    };
  };

  # sudoless
  # security.sudo.wheelNeedsPassword = false;

  environment.interactiveShellInit = ''
    alias c99='gcc'
  '';

  environment.systemPackages = with pkgs; [
    wget
    xclip
    git
    stow
    brave
    sqlite
    unzip
    coreutils
    binutils
    gcc
    flameshot
    sxiv
    gnumake
    xorg.xbacklight
    autorandr
    xdotool
    xdg-user-dirs
    pciutils
    usbutils
    # ventoy-bin
    rustup
    rustc
    brightnessctl
    # xdragon
    keyd
    dconf-editor
    mate.mate-power-manager
    mate.mate-media
    orchis-theme
    tela-circle-icon-theme
    docker
    libreoffice
    # reptyr
    # wireshark  # Handled by programs.wireshark in wireshark-usb.nix
    # tshark     # Included with wireshark package
    procps
    zsync
    cdrkit
    sqlitebrowser
    bashmount
    # vagrant
    grub2
    qemu
    libvirt
    virt-manager
    spice-gtk
    quickemu
    samba
    OVMF
    # Virtualisation tooling for Windows/libvirt workflow
    swtpm
    vagrant
    # vagrant-libvirt  # Not available as standalone package; use vagrant plugin if needed
    gdb
    libinput-gestures
    wmctrl
    fwupd
    # mysql80
    dbeaver-bin
    dig
    psmisc
    # discord
    # mycli
    grc
    cmake
    ninja
    clang
    yarn
    firefox
    ffmpeg-full
    vim
    wireguard-tools
    libtool
    libvterm
    os-prober
    age
    rage
    uxplay
    arandr
    libclang
    # libstdcxx5
    ctags
    zsh-completions
    networkmanager
    networkmanagerapplet
    dmenu
    # rofi
    # avahi
    eza
    discord
    # gimp
    # mullvad
    ghostty
    mpv
    code-cursor
    anki
    # rustdesk  # Temporarily disabled - fails to build with GCC 15
    claude-code
    deskflow
    tigervnc
    python313Packages.i3ipc
    filezilla
    # notepad-next
    ntfs3g
    ntfsprogs

    # R packages for data science
    rstudio
    (pkgs.rWrapper.override {
      packages = with pkgs.rPackages; let
        llr = buildRPackage {
          name = "llr";
          src = pkgs.fetchFromGitHub {
            owner = "dirkschumacher";
            repo = "llr";
            rev = "0a654d469af231e9017e1100f00df47bae212b2c";
            sha256 = "0ks96m35z73nf2sb1cb8d7dv8hq8dcmxxhc61dnllrwxqq9m36lr";
          };
          propagatedBuildInputs = [rlang knitr reticulate];
          nativeBuildInputs = [rlang knitr reticulate];
        };
      in [
        knitr
        rlang
        # llr
        reticulate
        tidyverse
        devtools
        bookdown
        VennDiagram
        DiagrammeR
        webshot
        networkD3
        knitcitations
      ];
    })
  ];
}
