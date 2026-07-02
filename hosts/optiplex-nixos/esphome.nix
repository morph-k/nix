{
  config,
  pkgs,
  ...
}: {
  # ESPHome for XIAO ESP32-S3 Sense Camera System
  # Project location: ~/projects/home-camera

  environment.systemPackages = with pkgs; [
    esphome # ESPHome CLI and libraries
    platformio-core # PlatformIO for ESP32 compilation
    esptool # ESP32 flashing tool
    python3
    python3Packages.pip
  ];

  # USB access for ESP32 flashing
  users.users.morph.extraGroups = [
    "dialout" # Serial port access
    "plugdev" # USB device access
  ];

  # udev rules for ESP32 devices
  services.udev.extraRules = ''
    # ESP32 USB Serial - CP210x
    SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", MODE="0666", GROUP="dialout"

    # ESP32 USB Serial - CH340
    SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="7523", MODE="0666", GROUP="dialout"

    # ESP32-S3 Native USB
    SUBSYSTEM=="tty", ATTRS{idVendor}=="303a", ATTRS{idProduct}=="1001", MODE="0666", GROUP="dialout"

    # XIAO ESP32-S3 Sense
    SUBSYSTEM=="tty", ATTRS{idVendor}=="303a", MODE="0666", GROUP="dialout"
  '';

  users.groups.dialout = {};
  users.groups.plugdev = {};

  # Optional: ESPHome systemd service for Home Assistant integration
  # This runs ESPHome dashboard for easy web-based configuration
  systemd.services.esphome = {
    enable = false; # Set to true if you want the web dashboard
    description = "ESPHome Dashboard";
    after = ["network.target"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "simple";
      User = "morph";
      WorkingDirectory = "/home/morph/projects/home-camera";
      ExecStart = "${pkgs.esphome}/bin/esphome dashboard esphome/ --port 6052";
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };
}
