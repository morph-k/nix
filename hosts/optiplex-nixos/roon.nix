{config, ...}: {
  services.roon-server = {
    enable = true;
    openFirewall = true;
    user = "morph";
    group = "users";
  };

  # Advertise Roon Server web interface as a Tailscale service
  systemd.services.tailscale-serve-roon = {
    description = "Advertise Roon Server on Tailscale";
    after = ["tailscale.service" "roon-server.service"];
    wants = ["tailscale.service" "roon-server.service"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Roon web interface runs on port 9330
      ExecStart = "${config.services.tailscale.package}/bin/tailscale serve --bg --https=443 --set-path=/roon http://127.0.0.1:9330";
      ExecStop = "${config.services.tailscale.package}/bin/tailscale serve --https=443 --set-path=/roon off";
    };
  };
}
