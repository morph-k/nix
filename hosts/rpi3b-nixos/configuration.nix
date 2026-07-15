{
  config,
  pkgs,
  ...
}: {
  # The nixos-hardware module already includes most of the necessary settings
  # We only need to override or add specific configurations

  # NixOS wants to enable GRUB by default
  boot.loader.grub.enable = false;

  boot.loader.generic-extlinux-compatible.enable = true;

  # Kernel is provided by the nixos-hardware raspberry-pi-3 module.
  # (Setting boot.kernelPackages here conflicts with it.)

  # A bunch of boot parameters needed for optimal runtime on RPi 3b+
  boot.kernelParams = ["cma=256M"];

  # Pin to latest stable kernel for ARM (Raspberry Pi compatible)
  # This prevents automatic kernel updates on every build
  boot.kernelPackages = pkgs.linuxPackages_rpi3;

  environment.systemPackages = with pkgs; [
    libraspberrypi
    ubootTools
    raspberrypi-eeprom
    dtc # For device tree compiler
  ];

  # File systems configuration for using the installer's partition layout
  fileSystems = {
    "/boot" = {
      device = "/dev/disk/by-label/NIXOS_BOOT";
      fsType = "vfat";
    };
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
    };
  };

  # Preserve space by sacrificing documentation and history
  documentation.nixos.enable = true;
  nix.gc.automatic = true;
  nix.gc.options = "--delete-older-than 30d";
  boot.tmp.cleanOnBoot = true;

  # Hardened sshd defaults come from modules/ssh-hardened.nix (imported below).
  services.openssh.enable = true;

  # Use 1GB of additional swap memory in order to not run out of memory
  # when installing lots of things while running other things at the same time.
  swapDevices = [
    {
      device = "/swapfile";
      size = 1024;
    }
  ];
  system.stateVersion = config.system.nixos.release;

  # tailscale
  services.tailscale.enable = true;

  age.identityPaths = [
    "/root/.ssh/id_ed25519"
  ];
  age.secrets.ts-rpi3b-nixos.file = ../../secrets/ts-rpi3b-nixos.age;

  # create a oneshot job to authenticate to Tailscale
  systemd.services.tailscale-autoconnect = {
    description = "Automatic connection to Tailscale";

    # make sure tailscale is running before trying to connect to tailscale
    after = ["network-pre.target" "tailscale.service"];
    wants = ["network-pre.target" "tailscale.service"];
    wantedBy = ["multi-user.target"];

    serviceConfig.Type = "oneshot";

    script = with pkgs; ''
      # wait for tailscaled to settle
      sleep 2

      # check if we are already authenticated to tailscale
      status="$(${tailscale}/bin/tailscale status -json | ${jq}/bin/jq -r .BackendState)"
      if [ $status = "Running" ]; then # if so, then do nothing
        exit 0
      fi

      # otherwise authenticate with tailscale
      ${tailscale}/bin/tailscale up --authkey=$(cat ${config.age.secrets.ts-rpi3b-nixos.path}) --advertise-exit-node --ssh
    '';
  };

  networking.firewall = {
    # warning: Strict reverse path filtering breaks Tailscale
    # exit node use and some subnet routing setups.
    checkReversePath = "loose";
    enable = true;

    # always allow traffic from your Tailscale network
    trustedInterfaces = ["tailscale0"];

    # allow the Tailscale UDP port through the firewall
    allowedUDPPorts = [config.services.tailscale.port];

    # allow you to SSH in over the public internet
    allowedTCPPorts = [22];
  };
}
