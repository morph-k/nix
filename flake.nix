{
  description = "Configurations targeting NixOS, Darwin, and WSL";

  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:lnl7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-wsl = {
      url = "github:nix-community/nixos-wsl";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    discord = {
      url = "github:InternetUnexplorer/discord-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plover = {
      url = "github:dnaq/plover-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tailscale = {
      url = "github:tailscale/tailscale";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixified-ai = {
      url = "github:nixified-ai/flake";
    };
    fakwin = {
      url = "github:DMaroo/fakwin";
      flake = false;
    };
    rawtalk = {
      url = "github:morph-k/rawtalk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agtx = {
      url = "github:fynnfluegge/agtx";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    darwin,
    agenix,
    emacs-overlay,
    discord,
    nixos-hardware,
    nixified-ai,
    fakwin,
    rawtalk,
    agtx,
    ...
  } @ inputs: let
    user = "morph";
    overlays = [
      discord.overlays.default
    ];
    # List of unix configurations
  in {
    # nix formatter
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.alejandra;
    formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.alejandra;

    # SD card image for Raspberry Pi 3B
    # NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1 nix build .#packages.aarch64-darwin.rpi3b-sdcard --impure
    packages.aarch64-linux.rpi3b-sdcard = self.nixosConfigurations.rpi3b-nixos.config.system.build.sdImage;

    # mac_mini MacOs
    darwinConfigurations.macmini-darwin = import ./hosts/macmini-darwin {
      inherit self nixpkgs darwin inputs user home-manager agenix emacs-overlay rawtalk agtx;
    };

    # macbook_pro MacOs
    darwinConfigurations.mbp-darwin = import ./hosts/mbp-darwin {
      inherit self nixpkgs darwin inputs user home-manager agenix emacs-overlay rawtalk;
    };

    # optiplex NixOs
    nixosConfigurations.optiplex-nixos = import ./hosts/optiplex-nixos {
      inherit nixpkgs self inputs user home-manager agenix overlays;
    };

    # win-wsl NixOs
    nixosConfigurations.win-wsl = import ./hosts/win-wsl {
      inherit nixpkgs self inputs user home-manager agenix overlays nixified-ai;
    };

    # visionfive2 NixOs
    # https://github.com/NixOS/nixos-hardware/tree/master/starfive/visionfive/v1
    # nixosConfigurations.visionfive2 = nixpkgs.lib.nixosSystem {
    #   system = "riscv64-linux";
    #   modules = [
    #     nixos-hardware.nixosModules.starfive-visionfive-v1
    #     {
    #       # with nix channel
    #       # imports = [<nixos-hardware/starfive/visionfive/v1/sd-image-installer.nix>];
    #
    #       nixpkgs.crossSystem = {
    #         config = "riscv64-unknown-linux-gnu";
    #         system = "riscv64-linux";
    #       };
    #     }
    #   ];
    # };

    # riscv-vm NixOS
    nixosConfigurations.riscv-vm = nixpkgs.lib.nixosSystem {
      system = "riscv64-linux";
      modules = [
        {
          boot.supportedFilesystems = ["ext4"];
          boot.loader.grub.devices = [
            "/dev/disk/by-id/nvme-WDS100T1XHE-00AFY0_215070800985"
          ];
          fileSystems."/" = {
            device = "/dev/disk/by-id/nvme-WDS100T1XHE-00AFY0_215070800985";
            fsType = "ext4";
          };
        }
      ];
    };

    # rpi3b NixOS (cross-compile on Darwin → aarch64-linux)
    nixosConfigurations.rpi3b-nixos = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";

      # 2) tell Nix how to cross
      crossSystem = {
        system = "aarch64-unknown-linux-gnu";
        config = "aarch64-linux";
      };

      specialArgs = inputs;
      modules = [
        "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
        nixos-hardware.nixosModules.raspberry-pi-3
        ./hosts/rpi3b-nixos
        agenix.nixosModules.default
        {
          nixpkgs.config.allowUnsupportedSystem = true;
          nixpkgs.config.allowBroken = true;
        }
      ];
    };
  };
}
