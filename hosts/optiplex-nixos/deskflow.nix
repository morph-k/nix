{
  config,
  pkgs,
  lib,
  ...
}: {
  # Input Leap (Synergy fork) - Share keyboard/mouse across computers

  environment.systemPackages = with pkgs; [
    input-leap # Keyboard/mouse sharing across computers
  ];

  # Systemd user service for Input Leap server
  systemd.user.services.deskflow-server = {
    description = "Input Leap Server - Keyboard/Mouse Sharing";
    wantedBy = ["sway-session.target"];
    after = ["sway-session.target"];
    partOf = ["sway-session.target"];

    serviceConfig = {
      Type = "simple";
      # Run Input Leap in server mode
      # -f = run in foreground
      # --no-tray = don't show tray icon
      # --debug INFO = logging level
      # --name = server name
      # --address 0.0.0.0:24800 = listen on all interfaces
      # -c = config file
      # --use-x11 = use X11 backend (avoids Wayland portal issues)
      # --disable-crypto = disable SSL (not needed on private network)
      ExecStart = "${pkgs.input-leap}/bin/input-leaps -f --no-tray --debug INFO --name optiplex-nixos --address 0.0.0.0:24800 -c /home/morph/.config/input-leap/input-leap.conf --use-x11 --disable-crypto";
      Restart = "on-failure";
      RestartSec = "5s";
    };

    environment = {
      # Use X11 compatibility mode (XWayland) to avoid Wayland portal issues
      DISPLAY = ":0";
      XDG_RUNTIME_DIR = "/run/user/1000";
      # Don't set WAYLAND_DISPLAY to force X11 mode
    };
  };

  # Firewall configuration - allow Input Leap server on Tailscale AND local network
  networking.firewall = {
    # Allow on Tailscale
    interfaces.tailscale0 = {
      allowedTCPPorts = [
        24800 # Input Leap/Synergy default port
      ];
    };
    # Also allow on main network interface for local LAN access
    interfaces.enp0s31f6 = {
      allowedTCPPorts = [
        24800 # Input Leap/Synergy default port
      ];
    };
  };

  # Create default Input Leap server config
  environment.etc."input-leap-server-config".text = ''
    section: screens
        optiplex-nixos:
        macmini-darwin:
    end

    section: links
        optiplex-nixos:
            right = macmini-darwin
        macmini-darwin:
            left = optiplex-nixos
    end

    section: options
        keystroke(Super+L) = switchInDirection(right)
        keystroke(Super+H) = switchInDirection(left)
    end
  '';

  # Helper script for Input Leap server
  environment.etc."profile.d/deskflow-helper.sh".text = ''
    # Input Leap server helpers (using deskflow-* aliases for consistency)
    alias deskflow-status='systemctl --user status deskflow-server'
    alias deskflow-restart='systemctl --user restart deskflow-server'
    alias deskflow-logs='journalctl --user -u deskflow-server -f'
    alias deskflow-stop='systemctl --user stop deskflow-server'
    alias deskflow-start='systemctl --user start deskflow-server'
    alias input-leap-status='systemctl --user status deskflow-server'
    alias input-leap-restart='systemctl --user restart deskflow-server'
    alias input-leap-logs='journalctl --user -u deskflow-server -f'

    # Create Input Leap config if it doesn't exist
    if [ ! -f ~/.config/input-leap/input-leap.conf ]; then
        mkdir -p ~/.config/input-leap
        cp /etc/input-leap-server-config ~/.config/input-leap/input-leap.conf
        echo "Input Leap config created at ~/.config/input-leap/input-leap.conf"
    fi
  '';
}
