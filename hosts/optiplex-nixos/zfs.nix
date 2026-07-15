{config, ...}: {
  boot.supportedFilesystems = ["zfs"];
  networking.hostId = "7a0852d2";
  boot.kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";
  boot.loader.efi.canTouchEfiVariables = false;
  boot.loader.generationsDir.copyKernels = true;
  boot.loader.grub.efiInstallAsRemovable = true;
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.copyKernels = true;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.zfsSupport = true;
  boot.loader.grub.extraPrepareConfig = ''
    mkdir -p /boot/efis
    for i in  /boot/efis/*; do mount $i ; done

    mkdir -p /boot/efi
    mount /boot/efi
  '';
  boot.loader.grub.extraInstallCommands = ''
    ESP_MIRROR=$(mktemp -d)
    cp -r /boot/efi/EFI $ESP_MIRROR
    for i in /boot/efis/*; do
     cp -r $ESP_MIRROR/EFI $i
    done
    rm -rf $ESP_MIRROR
  '';
  boot.loader.grub.devices = [
    "/dev/disk/by-id/ata-SK_hynix_SC300_2.5_7MM_256GB_FS62N525812102M1U"
  ];
  users.users.root.initialHashedPassword = "$6$gQsqghBWYSP5k4y1$jL6V1MtD5JplFiGKBTgy8AkxbvJ3KnNYD.uTYG/H5YhIj/yEmfcxd3gc9HaQwIH9dxkyJAUEIgux37t7tqeoP0";
}
