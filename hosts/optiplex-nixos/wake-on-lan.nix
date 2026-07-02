# Always-on / Wake-on-LAN configuration for optiplex-nixos
#
# Ensures the machine is always running and recovers automatically from:
# - Power outages (BIOS: Restore on AC Power Loss - must be set manually)
# - Network disconnections (WoL, NIC power management disabled)
# - System hangs (watchdog configured in configuration.nix)
# - Kernel panics (auto-reboot configured in configuration.nix)
#
# BIOS SETTINGS REQUIRED (access via F2/F12/Del at boot):
#   1. "Restore on AC Power Loss" / "After Power Failure" -> set to "Power On"
#      (This makes the machine automatically boot when power is restored)
#   2. "Wake on LAN" / "PME Event Wake Up" -> set to "Enabled"
#      (This allows remote wake via magic packet)
#   3. "Deep Sleep Control" -> set to "Disabled" (if available)
#      (Prevents low-power states that block WoL)
{
  config,
  pkgs,
  lib,
  ...
}: let
  # Primary network interface
  interface = "enp0s31f6";
in {
  networking.interfaces.${interface}.wakeOnLan.enable = true;

  # Install ethtool for WoL and NIC management
  environment.systemPackages = with pkgs; [
    ethtool
    powertop # For auditing power states
  ];

  # Systemd service to configure NIC for always-on operation
  # - Enables Wake-on-LAN (magic packet)
  # - Disables NIC power management / Energy Efficient Ethernet
  systemd.services.wakeonlan = {
    description = "Configure ${interface} for always-on operation (WoL + no power saving)";
    after = ["network.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # Enable Wake-on-LAN via magic packet
      ${pkgs.ethtool}/bin/ethtool -s ${interface} wol g

      # Disable Energy Efficient Ethernet (EEE) to prevent link drops
      # This prevents the NIC from entering low-power states that can cause
      # brief disconnections. Fails gracefully if NIC doesn't support EEE.
      ${pkgs.ethtool}/bin/ethtool --set-eee ${interface} eee off 2>/dev/null || true
    '';
  };

  # Disable NetworkManager power saving on the wired connection
  # This prevents NM from putting the NIC to sleep when idle
  networking.networkmanager = {
    ethernet.macAddress = "permanent";
    connectionConfig = {
      "connection.autoconnect" = "true";
      "connection.autoconnect-retries" = "0"; # Retry indefinitely
    };
  };

  # Disable USB autosuspend for network adapters and ensure NIC stays active
  # (Useful if any USB-based NICs are used as backup)
  boot.kernelParams = [
    "usbcore.autosuspend=-1" # Disable USB autosuspend globally
  ];

  # Ensure NetworkManager waits for connectivity and retries
  systemd.services.NetworkManager-wait-online = {
    serviceConfig = {
      ExecStart = lib.mkForce [
        "" # Clear the default ExecStart
        "${pkgs.networkmanager}/bin/nm-online -s -q --timeout=60"
      ];
    };
  };

  # Periodic network health check - restart NetworkManager if connectivity is lost
  systemd.services.network-watchdog = {
    description = "Network connectivity watchdog";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
    };
    script = ''
      # Check if the interface has a link
      if ! ${pkgs.iproute2}/bin/ip link show ${interface} | grep -q "state UP"; then
        echo "Network interface ${interface} is down, restarting NetworkManager..."
        systemctl restart NetworkManager
        sleep 10
      fi

      # Check if we have an IP address
      if ! ${pkgs.iproute2}/bin/ip addr show ${interface} | grep -q "inet "; then
        echo "No IP address on ${interface}, restarting NetworkManager..."
        systemctl restart NetworkManager
      fi
    '';
  };

  systemd.timers.network-watchdog = {
    description = "Run network watchdog every 5 minutes";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "5min";
      Unit = "network-watchdog.service";
    };
  };

  # Helper script to check always-on status
  environment.etc."profile.d/wol-helper.sh".text = ''
    # Wake-on-LAN helpers
    alias wol-status='sudo ethtool ${interface} | grep Wake-on'
    alias wol-enable='sudo ethtool -s ${interface} wol g'
    alias wol-info='echo "Interface: ${interface}" && ip link show ${interface} | grep "link/ether" && sudo ethtool ${interface} | grep -E "(Wake-on|Link detected)"'

    # Show MAC address for WoL commands
    alias wol-mac='ip link show ${interface} | grep "link/ether" | awk "{print \$2}"'

    # Always-on status check
    alias always-on-status='echo "=== Always-On Status ===" && echo "" && echo "-- Sleep targets --" && systemctl is-enabled sleep.target suspend.target hibernate.target hybrid-sleep.target 2>/dev/null || echo "All disabled (good)" && echo "" && echo "-- Watchdog --" && sudo cat /proc/sys/kernel/watchdog 2>/dev/null && echo "" && echo "-- NIC Power --" && sudo ethtool --show-eee ${interface} 2>/dev/null | head -5 && echo "" && echo "-- WoL --" && sudo ethtool ${interface} | grep Wake-on && echo "" && echo "-- Network --" && ip addr show ${interface} | grep "inet " && echo "" && echo "-- Uptime --" && uptime'
  '';
}
