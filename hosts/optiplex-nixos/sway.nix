{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    xwayland.enable = true; # Enable XWayland for X11 app compatibility
    extraPackages = with pkgs; [
      # Core Sway tools
      swaylock
      swayidle
      swaybg
      swayimg

      # Application launcher (replacement for dmenu)
      wofi
      bemenu

      # Wayland-native tools
      wl-clipboard
      wlr-randr

      # Status bar
      waybar # Alternative to i3status
      i3status # Your current i3status should work

      # Brightness control (replacement for xbacklight)
      brightnessctl

      # Screenshots
      grim
      slurp

      # Notifications
      mako

      # Terminal (if not already installed)
      ghostty

      # Network manager applet for Wayland
      networkmanagerapplet

      # Display configuration
      wdisplays

      # System info
      pavucontrol
    ];

    extraSessionCommands = ''
      # Force Wayland for various applications
      export MOZ_ENABLE_WAYLAND=1
      export QT_QPA_PLATFORM=wayland
      export SDL_VIDEODRIVER=wayland
      export _JAVA_AWT_WM_NONREPARENTING=1

      # Ensure XDG portals work properly
      export XDG_CURRENT_DESKTOP=sway
      export XDG_SESSION_TYPE=wayland
    '';
  };

  # XDG Desktop Portal for screen sharing (required for WayVNC and Waydroid)
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-wlr
      pkgs.xdg-desktop-portal-gtk
    ];
    config = {
      common = {
        default = ["wlr" "gtk"];
      };
      # Sway portal config - use mkForce to override default from sway module
      sway = lib.mkForce {
        default = ["wlr" "gtk"];
        "org.freedesktop.impl.portal.Screenshot" = ["wlr"];
        "org.freedesktop.impl.portal.ScreenCast" = ["wlr"];
      };
    };
  };

  # Autologin to Sway using greetd
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd sway";
        user = "morph";
      };
      initial_session = {
        command = "sway";
        user = "morph";
      };
    };
  };

  # Disable GDM since we're using greetd
  services.displayManager.gdm.enable = lib.mkForce false;
  services.xserver.enable = lib.mkForce true; # Still needed for some apps
  services.xserver.displayManager.startx.enable = false;

  # WayVNC for remote desktop access
  # Note: WayVNC doesn't have a NixOS service, so we'll create a systemd user service
  systemd.user.services.wayvnc = {
    description = "WayVNC - VNC server for Wayland";
    wantedBy = ["sway-session.target"];
    after = ["sway-session.target"];
    partOf = ["sway-session.target"];

    serviceConfig = {
      Type = "simple";
      # -f 60 = max 60 fps
      # -r = render cursor overlay
      # -g = enable GPU features
      # -C = config file path
      # Bind to 0.0.0.0 to accept Tailscale connections
      ExecStart = "${pkgs.wayvnc}/bin/wayvnc -C /home/morph/.config/wayvnc/config -f 60 -r -g 0.0.0.0 5900";
      Restart = "on-failure";
      RestartSec = "5s";
      # Ensure network access is allowed
      RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
    };

    environment = {
      WAYLAND_DISPLAY = "wayland-1";
      XDG_RUNTIME_DIR = "/run/user/1000";
    };
  };

  # Firewall configuration for WayVNC over Tailscale
  networking.firewall = {
    interfaces.tailscale0 = {
      allowedTCPPorts = [
        5900 # WayVNC
      ];
    };
  };

  # System packages
  environment.systemPackages = with pkgs; [
    wayvnc

    # VNC clients for testing
    tigervnc

    # Sway-specific tools
    sway-contrib.grimshot # Screenshot script

    # i3 compatibility tools
    i3status

    # Wayland debugging
    wayland-utils
  ];

  # Helper script for Sway configuration
  environment.etc."profile.d/sway-helper.sh".text = ''
    # Sway config location: ~/.config/sway/config
    # You can symlink your i3 config: ln -sf ~/dots/i3/.config/i3/config ~/.config/sway/config

    # WayVNC helpers
    alias wayvnc-status='systemctl --user status wayvnc'
    alias wayvnc-restart='systemctl --user restart wayvnc'
    alias wayvnc-stop='systemctl --user stop wayvnc'
    alias wayvnc-start='systemctl --user start wayvnc'

    # Display info
    alias list-outputs='swaymsg -t get_outputs'

    # For connecting from macOS/Linux:
    # macOS: Install TigerVNC or VNC Viewer (NOT default Screen Sharing)
    # Linux: vncviewer <tailscale-ip>:5900
    # Command: vncviewer 100.89.107.92:5900
  '';

  # Security settings
  security.polkit.enable = true;
  security.pam.services.swaylock = {};
}
