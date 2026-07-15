{
  config,
  pkgs,
  ...
}: let
  mediaUser = "morph";
  mediaUid = builtins.toString config.users.users.morph.uid;
  mediaGid = builtins.toString config.users.groups.users.gid;
  timezone = config.time.timeZone or "Etc/UTC";

  dataRoot = "/var/lib/media-stack";
  mediaLibraryRoot = "/mnt/nas/media";
  downloadsRoot = "/mnt/nas/downloads";
  gluetunEnvFile = "${dataRoot}/gluetun/gluetun.env";
in {
  virtualisation.oci-containers = {
    backend = "docker";

    containers = {
      gluetun = {
        image = "qmcgaw/gluetun";
        autoStart = true;
        volumes = [
          "${dataRoot}/gluetun:/gluetun"
        ];
        environment = {
          VPN_TYPE = "openvpn";
          VPN_SERVICE_PROVIDER = "protonvpn";
          VPN_PORT_FORWARDING = "on";
          SERVER_COUNTRIES = "United States";
          TZ = timezone;
          # Automatic port forwarding configuration
          VPN_PORT_FORWARDING_STATUS_FILE = "/gluetun/forwarded_port";
          FIREWALL_OUTBOUND_SUBNETS = "192.168.1.0/24";
        };
        environmentFiles = [gluetunEnvFile];
        ports = [
          "8701:8701"
          "6881:6881"
          "6881:6881/udp"
          "7878:7878"
          "8989:8989"
          "8686:8686"
          "6767:6767"
          "9696:9696"
          "8191:8191"
          "5055:5055"
        ];
        extraOptions = [
          "--cap-add=NET_ADMIN"
          "--device=/dev/net/tun"
        ];
      };

      qbittorrent = {
        image = "lscr.io/linuxserver/qbittorrent";
        autoStart = true;
        dependsOn = ["gluetun"];
        volumes = [
          "${dataRoot}/qbittorrent:/config"
          "${downloadsRoot}:/downloads"
          "${dataRoot}/gluetun:/gluetun:ro" # Mount gluetun data for port file access
        ];
        environment = {
          PUID = mediaUid;
          PGID = mediaGid;
          TZ = timezone;
          WEBUI_PORT = "8701";
          WEBUI_ADDRESS = "0.0.0.0";
          WEBUI_EXTERNAL_ACCESS = "true";
        };
        extraOptions = ["--network=container:gluetun"];
      };

      radarr = {
        image = "lscr.io/linuxserver/radarr";
        autoStart = true;
        dependsOn = ["gluetun"];
        volumes = [
          "${dataRoot}/radarr:/config"
          "${mediaLibraryRoot}:/data/media"
          "${downloadsRoot}:/downloads"
        ];
        environment = {
          PUID = mediaUid;
          PGID = mediaGid;
          TZ = timezone;
        };
        extraOptions = ["--network=container:gluetun"];
      };

      sonarr = {
        image = "lscr.io/linuxserver/sonarr";
        autoStart = true;
        dependsOn = ["gluetun"];
        volumes = [
          "${dataRoot}/sonarr:/config"
          "${mediaLibraryRoot}:/data/media"
          "${downloadsRoot}:/downloads"
        ];
        environment = {
          PUID = mediaUid;
          PGID = mediaGid;
          TZ = timezone;
        };
        extraOptions = ["--network=container:gluetun"];
      };

      lidarr = {
        image = "lscr.io/linuxserver/lidarr:latest";
        autoStart = true;
        dependsOn = ["gluetun"];
        volumes = [
          "${dataRoot}/lidarr:/config"
          "${mediaLibraryRoot}:/data/media"
          "${downloadsRoot}:/downloads"
        ];
        environment = {
          PUID = mediaUid;
          PGID = mediaGid;
          TZ = timezone;
        };
        extraOptions = ["--network=container:gluetun"];
      };

      bazarr = {
        image = "lscr.io/linuxserver/bazarr";
        autoStart = true;
        dependsOn = ["gluetun"];
        volumes = [
          "${dataRoot}/bazarr:/config"
          "${mediaLibraryRoot}:/data/media"
        ];
        environment = {
          PUID = mediaUid;
          PGID = mediaGid;
          TZ = timezone;
        };
        extraOptions = ["--network=container:gluetun"];
      };

      prowlarr = {
        image = "lscr.io/linuxserver/prowlarr";
        autoStart = true;
        dependsOn = ["gluetun"];
        volumes = [
          "${dataRoot}/prowlarr:/config"
        ];
        environment = {
          PUID = mediaUid;
          PGID = mediaGid;
          TZ = timezone;
        };
        extraOptions = ["--network=container:gluetun"];
      };

      flaresolverr = {
        image = "ghcr.io/flaresolverr/flaresolverr:latest";
        autoStart = true;
        dependsOn = ["gluetun"];
        environment = {
          TZ = timezone;
        };
        extraOptions = ["--network=container:gluetun"];
      };

      jellyseerr = {
        image = "fallenbagel/jellyseerr:latest";
        autoStart = true;
        dependsOn = ["gluetun"];
        volumes = ["${dataRoot}/jellyseerr:/app/config"];
        environment = {
          TZ = timezone;
          LOG_LEVEL = "info";
        };
        extraOptions = ["--network=container:gluetun"];
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d ${dataRoot} 0750 ${mediaUser} users - -"
    "d ${dataRoot}/gluetun 0750 ${mediaUser} users - -"
    "f ${gluetunEnvFile} 0600 ${mediaUser} users - -"
    "d ${dataRoot}/qbittorrent 0750 ${mediaUser} users - -"
    "d ${dataRoot}/radarr 0750 ${mediaUser} users - -"
    "d ${dataRoot}/sonarr 0750 ${mediaUser} users - -"
    "d ${dataRoot}/lidarr 0750 ${mediaUser} users - -"
    "d ${dataRoot}/bazarr 0750 ${mediaUser} users - -"
    "d ${dataRoot}/prowlarr 0750 ${mediaUser} users - -"
    "d ${dataRoot}/jellyseerr 0750 ${mediaUser} users - -"
    "d ${downloadsRoot} 0775 ${mediaUser} users - -"
    "d ${downloadsRoot}/movies 0775 ${mediaUser} users - -"
    "d ${downloadsRoot}/tv 0775 ${mediaUser} users - -"
    "d ${downloadsRoot}/music 0775 ${mediaUser} users - -"
    "d ${downloadsRoot}/audiobooks 0775 ${mediaUser} users - -"
    "d ${downloadsRoot}/incomplete 0775 ${mediaUser} users - -"
  ];

  # Systemd service to automatically update qBittorrent port when Gluetun changes it
  systemd.services.qbittorrent-port-updater = {
    description = "Update qBittorrent listening port from Gluetun forwarded port";
    after = ["docker-gluetun.service" "docker-qbittorrent.service"];
    wants = ["docker-gluetun.service" "docker-qbittorrent.service"];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = false;
      # Run as root to have permission to edit qBittorrent config
      # User = mediaUser;
      # Group = "users";
    };

    path = [pkgs.bash];

    script = ''
      # Use the dedicated port updater script
      /usr/local/bin/qbt-port-updater
    '';
  };

  # Timer to periodically check and update the port (every 5 minutes)
  systemd.timers.qbittorrent-port-updater = {
    description = "Timer for qBittorrent port updater";
    wantedBy = ["timers.target"];

    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "5min";
      Unit = "qbittorrent-port-updater.service";
    };
  };
}
