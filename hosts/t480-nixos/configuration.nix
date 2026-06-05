{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./keyd.nix
    ./tailscale.nix
    ./syncthing.nix
    # ./restic.nix
    # ./dslr.nix
  ];

  # Bootloader zfs specific
  boot.supportedFilesystems = ["zfs"];
  networking.hostId = "d1308988";

  boot.loader.efi.canTouchEfiVariables = true;

  boot.loader.grub = {
    enable = true;
    version = 2;
    device = "nodev";
    efiSupport = true;
    enableCryptodisk = true;
    useOSProber = true;
  };

  # Pin to latest LTS kernel for stability and security
  # This prevents automatic kernel updates on every build
  boot.kernelPackages = pkgs.linuxPackages_6_12;

  # Enable networking
  networking = {
    hostName = "t480-nixos";
    networkmanager.enable = true;
    # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
    firewall = {
      enable = true;

      # always allow traffic from tailscale network
      trustedInterfaces = ["tailscale0"];

      # allow the Tailscale UDP port through the firewall
      allowedUDPPorts = [config.services.tailscale.port];

      # let you SSH in over the public internet
      allowedTCPPorts = [22];
    };
  };

  services.openssh = {
    enable = true;
    # settings = {
    #   PermitRootLogin = "no";
    #   PasswordAuthentication = false;
    # };
    openFirewall = true;
  };

  # Enable tailscale Mesh VPN
  # services.tailscale.enable = true;

  # Set your time zone.
  time.timeZone = "America/New_York";

  # Select internationalisation properties.
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
  };

  security.rtkit.enable = true;
  hardware.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  services = {
    emacs = {
      package = pkgs.emacs;
      enable = true;
      install = true;
    };

    blueman.enable = true;

    xserver = {
      libinput.enable = true;
      enable = true;

      layout = "us";
      xkbVariant = "";
      # desktopManager = {
      #   mate = {
      #     enable = true;
      #     # excludePackages = [ pkgs.mate.mate-terminal pkgs.mate.pluma ];
      #   };
      # };

      displayManager = {
        startx.enable = false;
        sddm = {
          enable = true;
        };
        # gdm = {
        #   enable = true;
        #   wayland = false;
        # };
        autoLogin = {
          enable = false;
          user = "morph";
        };
      };

      windowManager = {
        i3 = {
          enable = true;
          package = pkgs.i3-gaps;
        };
      };
    };

    # printing.enable = true;

    avahi = {
      nssmdns = true;
      enable = true;
      openFirewall = true;
      publish = {
        enable = true;
        userServices = true;
        domain = true;
      };
      allowInterfaces = ["wlp0s20f3" "tailscale0"];
    };
  };

  users.users.morph = {
    isNormalUser = true;
    shell = pkgs.zsh;
    description = "Morphy Kuffour";
    extraGroups = ["networkmanager" "wheel" "libvirtd"];
    packages = with pkgs; [];
  };

  programs = {
    waybar.enable = true;
    zsh.enable = true;
    mtr.enable = true;
    autojump.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };

    thunar = {
      enable = true;
      plugins = with pkgs.xfce; [
        thunar-archive-plugin
        thunar-volman
      ];
    };
  };

  # vms
  # virtualisation.libvirtd.enable = true;
  # programs.virt-manager.enable = true;
  # virtualisation.docker = {
  #   enable = true;
  #   rootless = {
  #     enable = true;
  #     setSocketVariable = true;
  #   };
  # };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system = {
    # stateVersion = config.system.nixos.release;
    stateVersion = "24.05"; # Did you read the comment?
    autoUpgrade = {
      enable = true;
      allowReboot = true;
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
    ventoy-bin
    rustup
    rustc
    brightnessctl
    xdragon
    keyd
    dconf-editor
    # mate.mate-power-manager
    # mate.mate-media
    orchis-theme
    tela-circle-icon-theme
    docker
    libreoffice
    # reptyr
    wireshark
    tshark
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
    gdb
    libinput-gestures
    wmctrl
    fwupd
    # mysql80
    # dbeaver
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
    ghostty
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
    avahi
    eza
    discord
    gimp
    # mullvad
    code-cursor
  ];
}
