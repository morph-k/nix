# Remote Desktop configuration for headless Wayland access
# - Passwordless RustDesk for Tailscale network
# - Virtual Wayland display for headless operation
# - Auto-start on boot
{
  config,
  pkgs,
  lib,
  ...
}: let
  # RustDesk server configuration (self-hosted on this machine)
  rustdesk_server = "100.89.107.92";

  # Tailscale CIDR for whitelist (passwordless access)
  tailscale_cidr = "100.64.0.0/10";

  # RustDesk client config template - passwordless for Tailscale
  rustdeskConfigTemplate = pkgs.writeText "RustDesk2.toml.template" ''
    rendezvous_server = '${rustdesk_server}:21115'
    nat_type = 1
    serial = 0

    [options]
    custom-rendezvous-server = '${rustdesk_server}:21115'
    relay-server = '${rustdesk_server}:21117'
    key = 'RUSTDESK_KEY_PLACEHOLDER'

    # Passwordless for Tailscale network - auto-accept connections from whitelist
    # Using 'click' mode means no password required, just auto-accept from whitelist
    approve-mode = 'click'
    verification-method = 'use-both'

    # Whitelist Tailscale network for passwordless access
    whitelist = '${tailscale_cidr}'

    # Allow direct access without password for whitelisted IPs
    allow-only-conn-window-open = 'N'

    # Enable direct IP access (for Tailscale direct connections)
    enable-lan-discovery = 'Y'
    enable-direct-ip-access = 'Y'
    direct-access-port = '21118'

    # Quality settings for good remote experience
    image-quality = 'best'
    custom-fps = '60'
    codec-preference = 'vp9'

    # Full access permissions
    access-mode = 'full'
    enable-keyboard = 'Y'
    enable-clipboard = 'Y'
    enable-file-transfer = 'Y'
    enable-audio = 'Y'
    enable-tcp-tunneling = 'Y'

    # Enable remote restart
    enable-remote-restart = 'Y'
  '';

  # Script to set up RustDesk config and start server
  rustdeskSetup = pkgs.writeShellScript "rustdesk-wayland-setup" ''
    set -e
    CONFIG_DIR="$HOME/.config/rustdesk"
    KEY_FILE="${config.age.secrets.rustdesk-key-optiplex-nixos.path}"

    mkdir -p "$CONFIG_DIR"

    if [ -f "$KEY_FILE" ]; then
      RUSTDESK_KEY=$(cat "$KEY_FILE")
    else
      echo "Error: RustDesk key secret not found at $KEY_FILE"
      exit 1
    fi

    ${pkgs.gnused}/bin/sed "s/RUSTDESK_KEY_PLACEHOLDER/$RUSTDESK_KEY/" ${rustdeskConfigTemplate} > "$CONFIG_DIR/RustDesk2.toml"
    chmod 600 "$CONFIG_DIR/RustDesk2.toml"

    # Set empty password for passwordless access from whitelist
    # The whitelist + click mode combination allows auto-accept from Tailscale IPs
    ${pkgs.rustdesk}/bin/rustdesk --password "" 2>/dev/null || true

    echo "RustDesk configured for Wayland with passwordless Tailscale access"
  '';
in {
  # ============================================
  # AGENIX SECRET - RustDesk Encryption Key
  # ============================================
  age.secrets.rustdesk-key-optiplex-nixos = {
    file = ../../secrets/rustdesk-key-optiplex-nixos.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };
  # ============================================
  # PASSWORDLESS RUSTDESK - Whitelist-based
  # ============================================
  # No password secret needed - using whitelist + click mode
  # for auto-accept from Tailscale network

  # ============================================
  # VIRTUAL DISPLAY - Headless Wayland support
  # ============================================
  # With HDMI EDID dummy plug connected, no software EDID needed
  # The physical adapter provides proper EDID data

  # Enable GNOME's headless/virtual display support
  # Enable both Wayland (for Waydroid) and X11 (for RustDesk)
  # Note: GDM autologin defaults to X11 as a known quirk, which is perfect for RustDesk
  # Wayland is available when manually logging in for Waydroid support
  services.displayManager.gdm = {
    enable = true;
    wayland = true; # Enable Wayland support (available on manual login)
    autoSuspend = false;
  };

  # Configure mutter for virtual displays
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/mutter" = {
          experimental-features = ["scale-monitor-framebuffer" "kms-modifiers"];
        };
        # Prevent screen blanking
        "org/gnome/desktop/session" = {
          idle-delay = lib.gvariant.mkUint32 0;
        };
        "org/gnome/settings-daemon/plugins/power" = {
          sleep-inactive-ac-type = "nothing";
          sleep-inactive-battery-type = "nothing";
          power-button-action = "nothing";
        };
        # Disable screen lock
        "org/gnome/desktop/screensaver" = {
          lock-enabled = false;
          idle-activation-enabled = false;
        };
      };
    }
  ];

  # ============================================
  # AUTO-LOGIN - Configured in configuration.nix
  # ============================================
  # Removed duplicate autologin config - see configuration.nix

  # Workaround for GNOME auto-login race condition
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  # ============================================
  # D-BUS ENVIRONMENT - Propagate Wayland vars for portals
  # ============================================
  # This ensures xdg-desktop-portal can access Wayland display
  systemd.user.services.dbus-wayland-env = {
    description = "Update D-Bus environment for Wayland";
    wantedBy = ["graphical-session.target"];
    after = ["graphical-session.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.dbus}/bin/dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE";
      RemainAfterExit = true;
    };
  };

  # ============================================
  # RUSTDESK CLIENT - Wayland with passwordless Tailscale
  # ============================================
  systemd.user.services.rustdesk-client = {
    description = "RustDesk Client for Wayland Remote Access";
    wantedBy = ["graphical-session.target"];
    after = ["graphical-session.target" "pipewire.service" "dbus-wayland-env.service"];
    requires = ["dbus-wayland-env.service"];

    serviceConfig = {
      Type = "simple";
      ExecStartPre = "${rustdeskSetup}";
      ExecStart = "${pkgs.rustdesk}/bin/rustdesk --server";
      Restart = "on-failure";
      RestartSec = "5s";
    };

    environment = {
      # Wayland environment
      WAYLAND_DISPLAY = "wayland-0";
      XDG_SESSION_TYPE = "wayland";
      # For PipeWire screen capture via portal
      XDG_CURRENT_DESKTOP = "GNOME";
      # Required for D-Bus and portal access
      XDG_RUNTIME_DIR = "/run/user/1000";
      DBUS_SESSION_BUS_ADDRESS = "unix:path=/run/user/1000/bus";
    };
  };

  # ============================================
  # FIREWALL - RustDesk ports via Tailscale
  # ============================================
  networking.firewall = {
    interfaces.tailscale0 = {
      allowedTCPPorts = [
        21118 # RustDesk direct access
        21119 # RustDesk
        3389 # RDP (fallback)
      ];
      allowedUDPPorts = [
        21118 # RustDesk direct access
      ];
    };
  };

  # ============================================
  # PACKAGES
  # ============================================
  environment.systemPackages = with pkgs; [
    rustdesk

    # Screen/display tools
    wdisplays # Wayland display configuration
    wl-clipboard # Wayland clipboard

    # For debugging
    wlr-randr # Wayland output management
  ];

  # ============================================
  # DISPLAY CONFIGURATION
  # ============================================
  # Keep display active for remote access
  services.logind = {
    lidSwitch = "ignore";
    lidSwitchDocked = "ignore";
    lidSwitchExternalPower = "ignore";
    powerKey = "ignore";
    powerKeyLongPress = "ignore";
    settings = {
      Login = {
        IdleAction = "ignore";
        IdleActionSec = 0;
      };
    };
  };

  # ============================================
  # PIPEWIRE - Required for Wayland screen capture
  # ============================================
  # PipeWire is needed for RustDesk to capture Wayland screens
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # Portal for screen sharing (required for Wayland)
  xdg.portal = {
    enable = true;
    wlr.enable = false; # Not needed for GNOME
    extraPortals = [
      pkgs.xdg-desktop-portal-gnome
      pkgs.xdg-desktop-portal-gtk
    ];
    # Explicit portal backend configuration for GNOME
    config = {
      common = {
        default = ["gnome" "gtk"];
      };
      gnome = {
        default = ["gnome" "gtk"];
      };
    };
  };

  # ============================================
  # HELPER SCRIPTS
  # ============================================
  environment.etc."profile.d/remote-desktop-helper.sh".text = ''
    # RustDesk helpers
    alias rustdesk-id='rustdesk --get-id'
    alias rustdesk-server='rustdesk --server'
    alias rustdesk-status='systemctl --user status rustdesk-client'
    alias rustdesk-restart='systemctl --user restart rustdesk-client'

    # Display helpers
    alias list-displays='wlr-randr'

    # Session switching helpers
    # To switch to Wayland (for Waydroid): logout and select "GNOME" at login screen
    # To switch to X11 (for RustDesk): logout and select "GNOME on Xorg" at login screen
    # Current session type: echo $XDG_SESSION_TYPE
  '';
}
