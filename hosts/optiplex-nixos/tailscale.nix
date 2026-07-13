{
  config,
  pkgs,
  agenix,
  inputs,
  ...
}: {
  age.identityPaths = ["/home/morph/.ssh/id_ed25519"];
  age.secrets.ts-optiplex-nixos.file = ../../secrets/ts-optiplex-nixos.age;

  services.tailscale = {
    enable = true;
    authKeyFile = config.age.secrets.ts-optiplex-nixos.path;
    extraUpFlags = [
      "--advertise-exit-node"
      "--ssh"
      # optional if you've experimented before:
      # "--reset"
    ];
  };

  # Allow morph user to manage Tailscale serve without sudo
  systemd.services.tailscale-set-operator = {
    description = "Set Tailscale operator to allow non-root serve management";
    after = ["tailscale.service"];
    wants = ["tailscale.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${config.services.tailscale.package}/bin/tailscale set --operator=morph";
    };
  };

  # Simplified Tailscale Serve - only for non-media services
  # Media stack services are accessed directly via Tailscale IP on native ports
  systemd.services.tailscale-serve-config = {
    description = "Configure Tailscale serve routes for non-media services";
    after = [
      "tailscale.service"
      "code-server.service"
      "docker.service"
      "docker-vert.service"
      "docker-silverbullet.service"
      "tailscale-set-operator.service"
    ];
    wants = [
      "tailscale.service"
      "code-server.service"
      "docker.service"
      "docker-vert.service"
      "docker-silverbullet.service"
      "tailscale-set-operator.service"
    ];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart =
        "${pkgs.bash}/bin/bash -euc '"
        +
        # Serve SilverBullet notes on dedicated port 445 (for new tab page)
        "${config.services.tailscale.package}/bin/tailscale serve --bg --https=445 http://127.0.0.1:3030; "
        +
        # Serve SearXNG on BOTH /search subpath AND dedicated port 8443
        "${config.services.tailscale.package}/bin/tailscale serve --bg --https=443 --set-path=/search http://127.0.0.1:8888; "
        + "${config.services.tailscale.package}/bin/tailscale serve --bg --https=8443 http://127.0.0.1:8888; "
        +
        # Serve VERT UI on its own HTTPS port 444
        "${config.services.tailscale.package}/bin/tailscale serve --bg --https=444 http://127.0.0.1:3000; "
        +
        # Serve code-server on its own HTTPS port 8081
        "${config.services.tailscale.package}/bin/tailscale serve --bg --https=8081 http://127.0.0.1:8081; "
        +
        # Serve vertd backend API on its own HTTPS port 24153
        "${config.services.tailscale.package}/bin/tailscale serve --bg --https=24153 http://127.0.0.1:24153; "
        +
        # Serve BookLore on its own HTTPS port 6060
        "${config.services.tailscale.package}/bin/tailscale serve --bg --https=6060 http://127.0.0.1:6060'";
      ExecStop =
        "${pkgs.bash}/bin/bash -euc '"
        + "${config.services.tailscale.package}/bin/tailscale serve --https=445 off || true; "
        + "${config.services.tailscale.package}/bin/tailscale serve --https=443 --set-path=/search off || true; "
        + "${config.services.tailscale.package}/bin/tailscale serve --https=8443 off || true; "
        + "${config.services.tailscale.package}/bin/tailscale serve --https=444 off || true; "
        + "${config.services.tailscale.package}/bin/tailscale serve --https=8081 off || true; "
        + "${config.services.tailscale.package}/bin/tailscale serve --https=24153 off || true; "
        + "${config.services.tailscale.package}/bin/tailscale serve --https=6060 off || true'";
    };
  };

  # Good practice for exit nodes
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  networking.firewall = {
    enable = true;
    checkReversePath = "loose";
    trustedInterfaces = ["tailscale0"];
    allowedUDPPorts = [config.services.tailscale.port];
    # Allow SSH, media stack, and Stremio ports via Tailscale
    allowedTCPPorts = [
      22 # SSH
      5055 # Jellyseerr
      6060 # BookLore
      6767 # Bazarr
      7878 # Radarr
      8686 # Lidarr
      8701 # qBittorrent
      8989 # Sonarr
      9696 # Prowlarr
      8191 # FlareSolverr
      # Stremio services
      8080 # Stremio streaming server
      11470 # Stremio server
      12470 # Stremio web interface
      9117 # Jackett (via Gluetun)
      # Stremio addons (7000-7010 range)
      7000
      7001
      7002
      7003
      7004
      7005
      7006
      7007
      7008
      7009
      7010
    ];
  };
}
