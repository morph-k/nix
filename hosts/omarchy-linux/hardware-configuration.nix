# PLACEHOLDER hardware profile.
#
# This host does not exist as physical hardware yet, so this file is a
# generic x86_64 UEFI stub that lets the configuration evaluate and build.
# Replace it on the real machine with either:
#
#   nixos-generate-config --show-hardware-config > hardware-configuration.nix
#
# or, since disko and nixos-facter are already in your starred repos, a
# declarative equivalent:
#
#   nix run github:nix-community/nixos-facter -- -o facter.json
#
# The UUIDs below are deliberately obvious placeholders: this will evaluate
# and build, but it must not be deployed to real hardware as-is.
{
  config,
  lib,
  modulesPath,
  ...
}: {
  imports = [(modulesPath + "/installer/scan/not-detected.nix")];

  boot = {
    initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod"];
    initrd.kernelModules = [];
    kernelModules = ["kvm-intel"];
    extraModulePackages = [];

    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/00000000-0000-0000-0000-000000000000";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/0000-0000";
    fsType = "vfat";
    options = ["fmask=0077" "dmask=0077"];
  };

  swapDevices = [];

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
