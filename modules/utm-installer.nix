# A NixOS installer ISO with an SSH key baked in, so the UTM builder VM can be
# installed without touching its console.
#
# The stock minimal ISO boots with no root password and no authorized key, so
# sshd rejects every method — the only way in is the VM's graphical console.
# Baking the key in removes that manual step, which matters because the whole
# point of this VM is to be driven by scripts.
#
# Building an ISO needs no VM and no kvm (unlike make-disk-image), so this can
# be produced inside an aarch64-linux container on a Darwin host.
{
  modulesPath,
  pkgs,
  lib,
  ...
}: {
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
  ];

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = lib.mkForce "prohibit-password";
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE2TMl3MBm7E6y51xrNE7bBs1cWHFRv+avJ3/ZIE+DSH nix-remote-builder@macmini-darwin"
  ];

  # This ISO is booted once, from local disk, by one VM. Trading compression
  # ratio for build time is the right way round here.
  isoImage.squashfsCompression = "zstd -Xcompression-level 3";

  # Tools the unattended install script expects.
  environment.systemPackages = with pkgs; [parted curl];
}
