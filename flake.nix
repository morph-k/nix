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
    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      # Dedupe agenix's private dev inputs against ours (drops stale trees).
      inputs.darwin.follows = "darwin";
      inputs.home-manager.follows = "home-manager";
    };
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixified-ai = {
      # Intentionally NOT following nixpkgs: nixified-ai pins its own nixpkgs
      # for CUDA/pytorch binary compatibility; overriding it risks breaking
      # comfyui on win-wsl. Accept the second nixpkgs tree here.
      url = "github:nixified-ai/flake";
    };
    rawtalk = {
      url = "github:morph-k/rawtalk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    ...
  } @ inputs: let
    user = "morph";

    # Shared host builders (see ./lib/default.nix).
    hostLib = import ./lib {inherit inputs user;};

    # Args handed to every hosts/*/default.nix. Each host destructures only
    # what it needs (all headers end with `...`).
    hostArgs =
      {inherit inputs user;}
      // {inherit (hostLib) mkDarwin mkNixos mkHome;};

    systems = ["aarch64-darwin" "x86_64-linux" "aarch64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs systems;
    pkgsFor = system: nixpkgs.legacyPackages.${system};

    # A check that fails if any Nix file is not alejandra-formatted.
    fmtCheck = system: let
      pkgs = pkgsFor system;
    in
      pkgs.runCommandLocal "check-formatting" {nativeBuildInputs = [pkgs.alejandra];} ''
        alejandra --check ${self}
        touch $out
      '';

    # Force full evaluation of a host's system closure without building it.
    # Referencing `drv` in the builder makes Nix evaluate the whole config
    # (catching removed packages, option conflicts, and wiring errors) while
    # only realising a trivial derivation — so CI stays fast and independent
    # of binary-cache timing.
    evalCheck = system: name: drv: let
      pkgs = pkgsFor system;
    in
      pkgs.runCommandLocal "eval-${name}" {} ''
        echo "${drv}" > $out
      '';
  in {
    # `nix fmt`
    formatter = forAllSystems (system: (pkgsFor system).alejandra);

    # `nix develop` — consistent tooling for editing this flake.
    devShells = forAllSystems (system: let
      pkgs = pkgsFor system;
    in {
      default = pkgs.mkShell {
        packages = [
          pkgs.alejandra
          pkgs.nil
          pkgs.git
          inputs.agenix.packages.${system}.default
        ];
      };
    });

    # `nix flake check` — evaluate every host for its native system and enforce
    # formatting. Evaluation (not a full build) keeps CI fast and cache-timing
    # independent; run `nix build .#darwinConfigurations.<host>.system` locally
    # for a real build. CI runs this per-system (see .github/workflows/check.yml).
    checks = {
      aarch64-darwin = {
        formatting = fmtCheck "aarch64-darwin";
        eval-macmini = evalCheck "aarch64-darwin" "macmini" self.darwinConfigurations.macmini-darwin.system.drvPath;
        eval-mbp = evalCheck "aarch64-darwin" "mbp" self.darwinConfigurations.mbp-darwin.system.drvPath;
      };
      x86_64-linux = {
        formatting = fmtCheck "x86_64-linux";
        eval-optiplex = evalCheck "x86_64-linux" "optiplex" self.nixosConfigurations.optiplex-nixos.config.system.build.toplevel.drvPath;
        eval-win-wsl = evalCheck "x86_64-linux" "win-wsl" self.nixosConfigurations.win-wsl.config.system.build.toplevel.drvPath;
        # rpi3b cross-compiles to aarch64-linux but evaluates from x86_64-linux.
        eval-rpi3b = evalCheck "x86_64-linux" "rpi3b" self.nixosConfigurations.rpi3b-nixos.config.system.build.toplevel.drvPath;
      };
    };

    # SD card image for Raspberry Pi 3B
    # NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1 nix build .#packages.aarch64-linux.rpi3b-sdcard --impure
    packages.aarch64-linux.rpi3b-sdcard =
      self.nixosConfigurations.rpi3b-nixos.config.system.build.sdImage;

    # Bootable disk image for the UTM builder VM.
    #
    # Raw rather than qcow2 so UTM's Apple Virtualization backend can boot it
    # directly; the file is sparse, so the nominal 40G costs far less on disk.
    #
    # This cannot be built from Darwin — the host has no Linux builder, which
    # is the entire reason this VM exists. Build it on an aarch64-linux machine
    # or inside an aarch64-linux container.
    packages.aarch64-linux.utm-builder-image = import "${nixpkgs}/nixos/lib/make-disk-image.nix" {
      inherit (nixpkgs) lib;
      pkgs = nixpkgs.legacyPackages.aarch64-linux;
      config = self.nixosConfigurations.utm-builder.config;
      format = "raw";
      partitionTableType = "efi";
      installBootLoader = true;
      touchEFIVars = false;
      diskSize = 40 * 1024;
      copyChannel = false;
    };

    # Installer ISO with the builder's SSH key baked in. Unlike the disk image
    # above, this needs no VM and no kvm, so it builds fine inside a container.
    packages.aarch64-linux.utm-installer-iso =
      self.nixosConfigurations.utm-installer.config.system.build.isoImage;

    # ── Darwin hosts ────────────────────────────────────────────────────────
    darwinConfigurations.macmini-darwin = import ./hosts/macmini-darwin hostArgs;
    darwinConfigurations.mbp-darwin = import ./hosts/mbp-darwin hostArgs;

    # ── NixOS hosts ─────────────────────────────────────────────────────────
    nixosConfigurations.optiplex-nixos = import ./hosts/optiplex-nixos hostArgs;
    nixosConfigurations.win-wsl = import ./hosts/win-wsl hostArgs;

    # utm-builder: small aarch64-linux VM run under UTM, used as a Nix remote
    # builder so the Darwin hosts can realise Linux derivations natively.
    nixosConfigurations.utm-builder = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [./modules/utm-builder.nix];
    };

    # Installer ISO for the above, with an SSH key baked in so the install can
    # be driven over the network instead of through the VM's console.
    nixosConfigurations.utm-installer = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [./modules/utm-installer.nix];
    };

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

    # rpi3b NixOS (cross-compiled to aarch64-linux). `crossSystem` is not a
    # valid argument to nixosSystem; the platform is set via nixpkgs options in
    # a module instead. buildPlatform is left unpinned so it can be built from
    # x86_64-linux (CI) or an aarch64 machine natively.
    nixosConfigurations.rpi3b-nixos = nixpkgs.lib.nixosSystem {
      specialArgs = inputs;
      modules = [
        {nixpkgs.hostPlatform = "aarch64-linux";}
        "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
        inputs.nixos-hardware.nixosModules.raspberry-pi-3
        ./hosts/rpi3b-nixos
        inputs.agenix.nixosModules.default
        {
          nixpkgs.config.allowUnsupportedSystem = true;
          nixpkgs.config.allowBroken = true;
        }
      ];
    };
  };
}
