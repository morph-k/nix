{
  config,
  pkgs,
  lib,
  ...
}: let
  # RustDesk server configuration
  rustdesk_server = "100.89.107.92"; # Tailscale IP of this machine (server)

  # Tailscale CGNAT range for whitelist
  tailscale_cidr = "100.64.0.0/10";

  # RustDesk client config template (key will be filled in by setup script)
  rustdeskConfigTemplate = pkgs.writeText "RustDesk2.toml.template" ''
    rendezvous_server = '${rustdesk_server}:21115'
    nat_type = 1
    serial = 0

    [options]
    custom-rendezvous-server = '${rustdesk_server}:21115'
    relay-server = '${rustdesk_server}:21117'
    key = 'RUSTDESK_KEY_PLACEHOLDER'

    # Auto-accept connections with password (no manual click required)
    approve-mode = 'password'
    verification-method = 'use-permanent-password'

    # Whitelist only Tailscale network
    whitelist = '${tailscale_cidr}'

    # Enable LAN discovery and direct connections
    enable-lan-discovery = 'Y'
    enable-direct-ip-access = 'Y'
    direct-access-port = '21118'

    # Quality settings
    image-quality = 'best'
    custom-fps = '60'
    enable-hwcodec = 'Y'

    # Security settings
    access-mode = 'full'
    enable-keyboard = 'Y'
    enable-clipboard = 'Y'
    enable-file-transfer = 'Y'
    enable-audio = 'Y'
    enable-tcp-tunneling = 'Y'
  '';

  # Script to set up RustDesk config and password
  rustdeskSetup = pkgs.writeShellScript "rustdesk-client-setup.sh" ''
    CONFIG_DIR="/root/.config/rustdesk"
    USER_CONFIG_DIR="/home/morph/.config/rustdesk"
    PASSWORD_FILE="${config.age.secrets.rustdesk-optiplex-nixos.path}"
    KEY_FILE="${config.age.secrets.rustdesk-key-optiplex-nixos.path}"

    # Create config directories
    mkdir -p "$CONFIG_DIR" "$USER_CONFIG_DIR"

    # Read the encryption key from secret
    if [ -f "$KEY_FILE" ]; then
      RUSTDESK_KEY=$(cat "$KEY_FILE")
    else
      echo "Error: RustDesk key secret not found at $KEY_FILE"
      exit 1
    fi

    # Generate config with the actual key
    for dir in "$CONFIG_DIR" "$USER_CONFIG_DIR"; do
      ${pkgs.gnused}/bin/sed "s/RUSTDESK_KEY_PLACEHOLDER/$RUSTDESK_KEY/" ${rustdeskConfigTemplate} > "$dir/RustDesk2.toml"
      chmod 600 "$dir/RustDesk2.toml"
    done

    # Fix ownership for user config
    chown -R morph:users "$USER_CONFIG_DIR"

    # Set permanent password using RustDesk CLI (read from agenix secret)
    if [ -f "$PASSWORD_FILE" ]; then
      PASSWORD=$(cat "$PASSWORD_FILE")
      DISPLAY=:0 ${pkgs.rustdesk}/bin/rustdesk --password "$PASSWORD" 2>/dev/null || true
    else
      echo "Warning: Password secret not found at $PASSWORD_FILE"
    fi
  '';
in {
  # ============================================
  # AGENIX SECRETS - RustDesk Password & Encryption Key
  # ============================================
  age.secrets.rustdesk-optiplex-nixos = {
    file = ../../secrets/rustdesk-optiplex-nixos.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  age.secrets.rustdesk-key-optiplex-nixos = {
    file = ../../secrets/rustdesk-key-optiplex-nixos.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  environment.systemPackages = with pkgs; [
    rustdesk
    xorg.xrandr
    xorg.xorgserver # For Xvfb
    xorg.xf86videodummy # Dummy/virtual display driver
    dbus # For dbus-launch
  ];

  # NOTE: services.displayManager.gdm.wayland was removed — it no longer has
  # any effect under GNOME 50 (nixpkgs asserts on it).

  # Auto-login for morph user to have an active session
  services.displayManager.autoLogin = {
    enable = true;
    user = "morph";
  };

  # Workaround for GNOME auto-login race condition
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  # Configure a virtual/dummy display for headless operation
  services.xserver.videoDrivers = lib.mkBefore ["dummy"];

  # X11 configuration for dummy monitor
  services.xserver.config = ''
    Section "Monitor"
      Identifier "Monitor0"
      HorizSync 28.0-80.0
      VertRefresh 48.0-75.0
      # Modeline for 1920x1080 @ 60Hz
      Modeline "1920x1080_60.00" 173.00 1920 2048 2248 2576 1080 1083 1088 1120 -hsync +vsync
    EndSection

    Section "Device"
      Identifier "Card0"
      Driver "dummy"
      VideoRam 256000
    EndSection

    Section "Screen"
      Identifier "Screen0"
      Device "Card0"
      Monitor "Monitor0"
      DefaultDepth 24
      SubSection "Display"
        Depth 24
        Modes "1920x1080_60.00"
      EndSubSection
    EndSection
  '';

  # RustDesk client systemd service
  systemd.services.rustdesk-client = {
    description = "RustDesk Client Service";
    after = ["network.target" "graphical.target" "agenix.service"];
    wantedBy = ["graphical.target"];

    # Use main display (X11 session from GDM)
    environment = {
      DISPLAY = ":0";
      XAUTHORITY = "/run/user/1000/gdm/Xauthority";
      XDG_RUNTIME_DIR = "/run/user/1000";
      DBUS_SESSION_BUS_ADDRESS = "unix:path=/run/user/1000/bus";
    };

    serviceConfig = {
      Type = "simple";
      User = "morph";
      Group = "users";
      ExecStartPre = "+${rustdeskSetup}";
      ExecStart = "${pkgs.rustdesk}/bin/rustdesk --server";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  # Set up config on boot
  systemd.services.rustdesk-config-setup = {
    description = "RustDesk Client Configuration Setup";
    after = ["network.target" "agenix.service"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${rustdeskSetup}";
      RemainAfterExit = true;
    };
  };

  # Firewall for RustDesk client
  networking.firewall = {
    allowedTCPPorts = [21118 21119];
    allowedUDPPorts = [21118];

    interfaces.tailscale0 = {
      allowedTCPPorts = [21118 21119];
      allowedUDPPorts = [21118];
    };
  };
}
