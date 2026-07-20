# A small aarch64-linux NixOS VM, run under UTM, used as a Nix remote builder
# for the Darwin hosts.
#
# This is *remote building*, not cross-compilation. Anything whose build step
# executes the artifact it produces cannot be cross-compiled: SBCL's
# save-lisp-and-die dumps a running image, so a Linux binary can only come out
# of a running Linux process. A builder VM supplies that; a cross-compiler
# cannot. Because the guest is aarch64 on aarch64 Apple Silicon there is no
# emulation involved, so it runs at native speed.
#
# Deliberately not using nix-darwin's `nix.linux-builder`: that option asserts
# `nix.enable`, and Nix on these hosts is managed by the Determinate installer,
# which owns /etc/nix/nix.conf. This VM is registered through /etc/nix/machines
# instead, which Nix reads by default regardless of who manages nix.conf.
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # UTM boots this through EFI.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;
  boot.growPartition = true;

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
    autoResize = true;
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
  };

  # Deliberately no services.qemuGuest: UTM's Apple Virtualization backend has
  # no guest-agent channel, so `utmctl ip-address` and `utmctl exec` return
  # "Operation not supported by the backend" no matter what runs in the guest.
  # scripts/utm-builder-setup.sh finds the address via macOS's DHCP lease table
  # instead. The qemu-guest profile above is still wanted, purely for its
  # virtio kernel modules, which this backend does use.

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  # Declared once and shared, so the builder account and the break-glass root
  # account cannot drift apart.
  users.users.builder = {
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE2TMl3MBm7E6y51xrNE7bBs1cWHFRv+avJ3/ZIE+DSH nix-remote-builder@macmini-darwin"
    ];
  };

  # Root key access, declared rather than dropped into /root by hand: anything
  # written into the filesystem out-of-band is not reproduced by a rebuild, and
  # a builder VM with no way in is not debuggable.
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE2TMl3MBm7E6y51xrNE7bBs1cWHFRv+avJ3/ZIE+DSH nix-remote-builder@macmini-darwin"
  ];

  # Serial console on ttyAMA0 so `utmctl attach` can reach a getty. Without
  # this the only view into a VM that fails to come up on the network is UTM's
  # graphical window, which is not reachable from a script.
  boot.kernelParams = ["console=ttyAMA0,115200"];

  # Nyxt's Electron comes from npm as a generic-Linux prebuilt, so NixOS cannot
  # execute it: its ELF interpreter is /lib/ld-linux-aarch64.so.1, which here is
  # only a stub that prints "Could not start dynamically linked executable".
  # nix-ld supplies a real loader plus a library path for such binaries. The
  # build succeeds without this; only launching the browser needs it.
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      # Chromium's runtime set.
      glib
      nss
      nspr
      atk
      at-spi2-atk
      at-spi2-core
      cups
      dbus
      expat
      libdrm
      libxkbcommon
      mesa
      # libgbm.so.1 moved out of mesa into its own package, so `mesa` alone
      # leaves Electron failing with "libgbm.so.1: cannot open shared object".
      libgbm
      libglvnd
      alsa-lib
      pango
      cairo
      gtk3
      gdk-pixbuf
      zlib
      stdenv.cc.cc.lib
      xorg.libX11
      xorg.libXcomposite
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXrandr
      xorg.libxcb
      xorg.libXcursor
      xorg.libXi
      xorg.libXrender
      xorg.libXtst
      xorg.libxshmfence
    ];
  };

  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    # The remote side must trust the builder user, otherwise offloaded
    # derivations are rejected rather than built.
    trusted-users = ["builder"];
    max-jobs = "auto";
  };

  # Keep the image small: this VM only ever builds, it is never logged into
  # for real work.
  documentation.enable = false;
  documentation.man.enable = false;
  environment.systemPackages = [pkgs.git];

  networking.hostName = "utm-builder";
  networking.firewall.allowedTCPPorts = [22];

  # UTM's shared network blackholes full-size frames: at the default 1500 the
  # TLS handshake to api.github.com and proxy.golang.org stalls and dies
  # ("unexpected eof while reading" / "TLS handshake timeout"), while smaller
  # responses like channels.nixos.org succeed — the classic PMTU blackhole,
  # where the ICMP "fragmentation needed" reply never makes it back. That
  # failure mode is worth naming because it looks like a flaky mirror rather
  # than a network setting, and it silently breaks any fetcher that needs
  # GitHub or the Go module proxy.
  networking.interfaces.enp0s1.mtu = 1280;

  system.stateVersion = "25.05";
}
