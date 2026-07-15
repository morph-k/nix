{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    croc
  ];

  # Croc relay server systemd service
  systemd.services.croc-relay = {
    description = "Croc relay server for easy file transfers";
    after = ["network.target"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "simple";
      User = "morph";
      Group = "users";
      ExecStart = "${pkgs.croc}/bin/croc relay";
      Restart = "on-failure";
      RestartSec = "10s";

      # Security hardening
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = false;
    };
  };

  # Open firewall ports for croc relay (default ports 9009-9013)
  networking.firewall = {
    allowedTCPPorts = [9009 9010 9011 9012 9013];
  };
}
