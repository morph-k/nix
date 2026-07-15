{
  pkgs,
  nixos-wsl,
  modulesPath,
  agenix,
  ...
}: {
  imports = [
    "${modulesPath}/profiles/minimal.nix"
    nixos-wsl.nixosModules.wsl
    agenix.nixosModules.default
    # This WSL host runs sshd (services.openssh below), so apply the shared
    # hardening (key-only auth, modern crypto). All values are mkDefault.
    ../../modules/ssh-hardened.nix
    ./tailscale.nix
    ./comfyui.nix
  ];

  # Set your time zone.
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  system.stateVersion = "25.11";
  services.xserver.videoDrivers = ["nvidia"];
  hardware.nvidia.open = true;
  hardware.graphics.enable = true;

  environment.sessionVariables = {
    CUDA_PATH = "${pkgs.cudatoolkit}";
    EXTRA_LDFLAGS = "-L/lib -L${pkgs.linuxPackages.nvidia_x11}/lib";
    EXTRA_CCFLAGS = "-I/usr/include";
    LD_LIBRARY_PATH = [
      "/usr/lib/wsl/lib"
      "${pkgs.linuxPackages.nvidia_x11}/lib"
      "${pkgs.ncurses5}/lib"
    ];
    MESA_D3D12_DEFAULT_ADAPTER_NAME = "NVIDIA";
  };
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.allowBroken = true;
  networking = {
    hostName = "win-wsl";
    dhcpcd.enable = false;
  };

  programs.zsh.enable = true;
  users = {
    defaultUserShell = pkgs.zsh;
    users.morph = {
      isNormalUser = true;
      home = "/home/morph";
      shell = pkgs.zsh;
      extraGroups = ["wheel"];
    };

    users.root = {
      # Otherwise WSL fails to login as root with "initgroups failed 5"
      extraGroups = ["root"];
    };
  };

  services = {
    openssh.enable = true;
    # And then enable them for the relevant users:
    # systemctl --user enable auto-fix-vscode-server.service
    # vscode-server.enable = true;
    ollama = {
      package = pkgs.ollama-cuda;
      enable = true;
      # acceleration removed — no longer has effect (nixpkgs asserts); the
      # ollama-cuda package already provides CUDA acceleration.
      environmentVariables = {
        OLLAMA_HOST = "0.0.0.0:11434";
        OLLAMA_ORIGINS = "*";
      };
    };

    open-webui = {
      enable = true;
      environment = {
        ANONYMIZED_TELEMETRY = "False";
        DO_NOT_TRACK = "True";
        SCARF_NO_ANALYTICS = "True";
        OLLAMA_API_BASE_URL = "http://127.0.0.1:11434/api";
        OLLAMA_BASE_URL = "http://127.0.0.1:11434";
      };
    };
  };

  wsl = {
    enable = true;
    wslConf = {
      automount.root = "/mnt";
      network.generateResolvConf = false; # Prevent WSL from managing resolv.conf
    };
    defaultUser = "morph";
    startMenuLaunchers = true;
  };

  hardware.nvidia-container-toolkit = {
    enable = true;
    mount-nvidia-executables = false;
  };

  systemd.services.nvidia-cdi-generator = {
    description = "Generate nvidia cdi";
    wantedBy = ["docker.service"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.nvidia-docker}/bin/nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml --nvidia-ctk-path=${pkgs.nvidia-container-toolkit}/bin/nvidia-ctk";
    };
  };

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
    daemon.settings = {
      features.cdi = true;
      cdi-spec-dirs = ["/etc/cdi"];
    };
  };

  # Create necessary directories for docker and nvidia
  systemd.tmpfiles.rules = [
    "d /var/lib/ollama 0755 root root"
    "d /etc/cdi 0755 root root"
  ];

  # nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # Enable nix flakes
  nix = {
    # package = pkgs.nixFlakes;
    settings = {
      auto-optimise-store = true;
      sandbox = true;
      trusted-users = ["root" "morph" "@wheel"];
      # Add nixified.ai binary cache for faster AI model builds
      substituters = [
        "https://nix-community.cachix.org"
        "https://ai.cachix.org"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "ai.cachix.org-1:N9dzRK+alWwoKXQlnn0H6aUx0lU/mspIoz8hMvGvbbc="
      ];
    };

    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  security.sudo.wheelNeedsPassword = false;

  # Disable systemd units that don't make sense on WSL
  systemd.services."serial-getty@ttyS0".enable = false;
  systemd.services."serial-getty@hvc0".enable = false;
  systemd.services."getty@tty2".enable = false;
  systemd.services."autovt@".enable = false;

  systemd.services.firewall.enable = false;
  systemd.services.systemd-resolved.enable = false;
  systemd.services.systemd-udevd.enable = false;

  # Don't allow emergency mode, because we don't have a console.
  systemd.enableEmergencyMode = false;

  systemd.services.nixs-wsl-systemd-fix = {
    description = "Fix the /dev/shm symlink to be a mount";
    unitConfig = {
      DefaultDependencies = "no";
      # Before = "sysinit.target";
      Before = ["sysinit.target" "systemd-tmpfiles-setup-dev.service" "systemd-tmpfiles-setup.service" "systemd-sysctl.service"];
      ConditionPathExists = "/dev/shm";
      ConditionPathIsSymbolicLink = "/dev/shm";
      ConditionPathIsMountPoint = "/run/shm";
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = [
        "${pkgs.coreutils-full}/bin/rm /dev/shm"
        "/run/wrappers/bin/mount --bind -o X-mount.mkdir /run/shm /dev/shm"
      ];
    };
    wantedBy = ["sysinit.target"];
  };

  # emacs package
  # services.emacs = {
  #   enable = true;
  #   # package = pkgs.emacs;
  #   package = pkgs.emacsGit;
  #   # package = pkgs.emacs-overlay;
  #   install = true;
  # };

  # import emacs config as a submodule
  # nixpkgs.overlays = [
  #   # (import ../../third_party/emacs-overlay)
  #   (import (builtins.fetchTarball {
  #     url = https://github.com/nix-community/emacs-overlay/archive/master.tar.gz;
  #   }))
  # ];

  # packageOverrides = pkgs: {
  #   emacs-overlay = pkgs.buildEnv {
  #     name = "emacs-overlay-env";
  #     paths = [(import (builtins.fetchTarball "https://cachix.org/api/v1/cache/emacs-overlay"))];
  #   };
  # };

  environment.systemPackages = with pkgs; [
    git
    wget
    vim
    zsh
    delta
    home-manager
    curl
    jq
    # emacs
    file
    eza
    bat
    rsync
    stow
    binutils
    autojump
    atuin
    starship
    tmux
    abduco
    tealdeer
    xclip
    nodejs
    ranger
    gnumake
    ripgrep
    fzf
    mcfly
    cargo
    oterm
    neovim

    # NVIDIA packages
    cudatoolkit
    nvidia-docker
    nvidia-container-toolkit
    linuxPackages.nvidia_x11
    # R packages for data science
    # rstudio
    # (pkgs.rWrapper.override {
    #   packages = with pkgs.rPackages; let
    #     llr = buildRPackage {
    #       name = "llr";
    #       src = pkgs.fetchFromGitHub {
    #         owner = "dirkschumacher";
    #         repo = "llr";
    #         rev = "0a654d469af231e9017e1100f00df47bae212b2c";
    #         sha256 = "0ks96m35z73nf2sb1cb8d7dv8hq8dcmxxhc61dnllrwxqq9m36lr";
    #       };
    #       propagatedBuildInputs = [rlang knitr reticulate];
    #       nativeBuildInputs = [rlang knitr reticulate];
    #     };
    #   in [
    #     knitr
    #     rlang
    #     llr
    #     tidyverse
    #     devtools
    #     bookdown
    #     VennDiagram
    #     DiagrammeR
    #     webshot
    #     networkD3
    #   ];
    # })
  ];
}
