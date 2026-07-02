{
  config,
  pkgs,
  ...
}: let
  # RustDesk server ports
  hbbs_port = 21115; # TCP - ID/Rendezvous server
  hbbs_port_udp = 21116; # UDP - ID/Rendezvous server
  hbbs_port_web = 21114; # TCP - Web console (admin)
  hbbr_port = 21117; # TCP - Relay server
  hbbr_port_ws = 21119; # TCP - Relay server WebSocket

  # Server address for relay configuration
  server_address = "100.89.107.92"; # Tailscale IP

  # Data directory for RustDesk
  rustdesk_data = "/var/lib/rustdesk";
in {
  systemd.tmpfiles.rules = [
    "d ${rustdesk_data} 0750 rustdesk rustdesk - -"
  ];

  users.users.rustdesk = {
    isSystemUser = true;
    group = "rustdesk";
    home = rustdesk_data;
    createHome = true;
  };
  users.groups.rustdesk = {};

  # RustDesk hbbs (ID/Rendezvous server)
  systemd.services.rustdesk-hbbs = {
    description = "RustDesk ID/Rendezvous Server (hbbs)";
    after = ["network.target"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "simple";
      User = "rustdesk";
      Group = "rustdesk";
      WorkingDirectory = rustdesk_data;
      ExecStart = ''
        /usr/local/bin/hbbs \
          -p ${toString hbbs_port} \
          -k _ \
          -r ${server_address}:${toString hbbr_port}
      '';
      Restart = "always";
      RestartSec = "5s";
      StartLimitIntervalSec = "60s";
      StartLimitBurst = "5";

      # Fault tolerance settings

      RestartKillSignal = "SIGINT";
      TimeoutStopSec = "10s";

      # Health check via systemd
      ExecStartPost = "${pkgs.bash}/bin/bash -c 'sleep 3 && ${pkgs.netcat}/bin/nc -z localhost ${toString hbbs_port}'";

      # Enhanced logging for debugging
      StandardOutput = "journal";
      StandardError = "journal";
      SyslogIdentifier = "rustdesk-hbbs";

      # Security hardening
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [rustdesk_data];

      # Network optimizations for high throughput
      LimitNOFILE = 1000000;
      LimitNPROC = 512;
    };
  };

  # RustDesk hbbr (Relay server)
  systemd.services.rustdesk-hbbr = {
    description = "RustDesk Relay Server (hbbr)";
    after = ["network.target"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "simple";
      User = "rustdesk";
      Group = "rustdesk";
      WorkingDirectory = rustdesk_data;
      ExecStart = ''
        /usr/local/bin/hbbr \
          -p ${toString hbbr_port} \
          -k _
      '';
      Restart = "always";
      RestartSec = "5s";
      StartLimitIntervalSec = "60s";
      StartLimitBurst = "5";

      # Fault tolerance settings

      RestartKillSignal = "SIGINT";
      TimeoutStopSec = "10s";

      # Health check via systemd
      ExecStartPost = "${pkgs.bash}/bin/bash -c 'sleep 3 && ${pkgs.netcat}/bin/nc -z localhost ${toString hbbr_port}'";

      # Enhanced logging for debugging
      StandardOutput = "journal";
      StandardError = "journal";
      SyslogIdentifier = "rustdesk-hbbr";

      # Security hardening
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [rustdesk_data];

      # Network optimizations for high throughput
      LimitNOFILE = 1000000;
      LimitNPROC = 512;
    };
  };

  # Advertise RustDesk web console via Tailscale
  systemd.services.tailscale-serve-rustdesk = {
    description = "Advertise RustDesk Web Console on Tailscale";
    after = ["tailscale.service" "rustdesk-hbbs.service"];
    wants = ["tailscale.service" "rustdesk-hbbs.service"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${config.services.tailscale.package}/bin/tailscale serve --bg --https=443 --set-path=/rustdesk http://127.0.0.1:${toString hbbs_port_web}";
      ExecStop = "${config.services.tailscale.package}/bin/tailscale serve --https=443 --set-path=/rustdesk off";
    };
  };

  # High throughput kernel optimizations
  boot.kernel.sysctl = {
    # TCP BBR congestion control for better throughput
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";

    # Increase network buffers for high throughput
    "net.core.rmem_max" = 134217728; # 128 MB
    "net.core.wmem_max" = 134217728; # 128 MB
    "net.core.rmem_default" = 16777216; # 16 MB
    "net.core.wmem_default" = 16777216; # 16 MB
    "net.ipv4.tcp_rmem" = "4096 87380 134217728";
    "net.ipv4.tcp_wmem" = "4096 65536 134217728";

    # Increase max connections
    "net.core.somaxconn" = 65535;
    "net.core.netdev_max_backlog" = 65536;
    "net.ipv4.tcp_max_syn_backlog" = 65536;

    # TCP optimizations
    "net.ipv4.tcp_fastopen" = 3;
    "net.ipv4.tcp_mtu_probing" = 1;
    "net.ipv4.tcp_slow_start_after_idle" = 0;
    "net.ipv4.tcp_tw_reuse" = 1;

    # Reduce TCP keepalive time
    "net.ipv4.tcp_keepalive_time" = 600;
    "net.ipv4.tcp_keepalive_intvl" = 60;
    "net.ipv4.tcp_keepalive_probes" = 3;
  };

  # Firewall configuration
  networking.firewall = {
    # RustDesk ports - allow both local network and Tailscale
    allowedTCPPorts = [
      hbbs_port # 21115 - ID/Rendezvous
      hbbr_port # 21117 - Relay
      hbbr_port_ws # 21119 - Relay WebSocket
      hbbs_port_web # 21114 - Web console (optional, mainly for Tailscale)
    ];
    allowedUDPPorts = [
      hbbs_port_udp # 21116 - ID/Rendezvous UDP
    ];

    # Allow these ports on Tailscale interface
    interfaces.tailscale0 = {
      allowedTCPPorts = [hbbs_port hbbr_port hbbr_port_ws hbbs_port_web];
      allowedUDPPorts = [hbbs_port_udp];
    };
  };

  # Monitoring and health check service
  systemd.services.rustdesk-monitor = {
    description = "RustDesk Server Health Monitor";
    after = ["rustdesk-hbbs.service" "rustdesk-hbbr.service"];
    wants = ["rustdesk-hbbs.service" "rustdesk-hbbr.service"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "simple";
      User = "rustdesk";
      Group = "rustdesk";
      Restart = "always";
      RestartSec = "30s";

      ExecStart = pkgs.writeShellScript "rustdesk-monitor" ''
        #!/bin/bash

        # Monitoring script for RustDesk services
        LOG_FILE="/var/lib/rustdesk/monitor.log"

        log() {
          echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
        }

        check_service() {
          local service="$1"
          local port="$2"

          # Check if service is running
          if ! systemctl is-active --quiet "$service"; then
            log "ERROR: $service is not running, attempting restart"
            systemctl restart "$service"
            sleep 5
          fi

          # Check if port is listening
          if ! ${pkgs.netcat}/bin/nc -z localhost "$port" 2>/dev/null; then
            log "ERROR: $service port $port is not responding, restarting service"
            systemctl restart "$service"
          else
            log "INFO: $service on port $port is healthy"
          fi
        }

        # Main monitoring loop
        while true; do
          check_service "rustdesk-hbbs" "${toString hbbs_port}"
          check_service "rustdesk-hbbr" "${toString hbbr_port}"

          # Clean old log entries (keep last 1000 lines)
          if [[ -f "$LOG_FILE" ]]; then
            tail -n 1000 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
          fi

          sleep 60  # Check every minute
        done
      '';
    };
  };

  # Log rotation for RustDesk logs
  services.logrotate.settings.rustdesk = {
    files = "/var/lib/rustdesk/*.log";
    frequency = "daily";
    rotate = 7;
    compress = true;
    delaycompress = true;
    missingok = true;
    notifempty = true;
    copytruncate = true;
  };

  # Backup script for RustDesk configuration
  systemd.services.rustdesk-backup = {
    description = "Backup RustDesk Configuration";
    serviceConfig = {
      Type = "oneshot";
      User = "rustdesk";
      Group = "rustdesk";
      ExecStart = pkgs.writeShellScript "rustdesk-backup" ''
        #!/bin/bash
        BACKUP_DIR="/var/lib/rustdesk/backups"
        mkdir -p "$BACKUP_DIR"

        # Create timestamped backup
        DATE=$(date +%Y%m%d_%H%M%S)
        tar -czf "$BACKUP_DIR/rustdesk_backup_$DATE.tar.gz" -C /var/lib/rustdesk \
          --exclude="backups" --exclude="*.log" .

        # Keep only last 5 backups
        cd "$BACKUP_DIR" && ls -t rustdesk_backup_*.tar.gz | tail -n +6 | xargs -r rm
      '';
    };
  };

  # Run backup daily
  systemd.timers.rustdesk-backup = {
    description = "Daily RustDesk Backup";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };

  # Add management tools to system (rustdesk server installed manually)
  environment.systemPackages = with pkgs; [
    netcat # For health checks

    # RustDesk management script
    (writeScriptBin "rustdesk-manage" ''
      #!/bin/bash

      show_status() {
        echo "=== RustDesk Server Status ==="
        echo "HBBS (ID Server):"
        systemctl status rustdesk-hbbs --no-pager -l
        echo -e "\nHBBR (Relay Server):"
        systemctl status rustdesk-hbbr --no-pager -l
        echo -e "\nMonitor Service:"
        systemctl status rustdesk-monitor --no-pager -l
        echo -e "\nPort Status:"
        netstat -tlnp | grep -E ":(${toString hbbs_port}|${toString hbbr_port})"
      }

      show_logs() {
        echo "=== Recent RustDesk Logs ==="
        journalctl -u rustdesk-hbbs -u rustdesk-hbbr -u rustdesk-monitor --since "1 hour ago" --no-pager
      }

      restart_all() {
        echo "Restarting all RustDesk services..."
        systemctl restart rustdesk-hbbs rustdesk-hbbr rustdesk-monitor
        sleep 3
        show_status
      }

      show_config() {
        echo "=== RustDesk Server Configuration ==="
        echo "Server Address: ${server_address}"
        echo "HBBS Port: ${toString hbbs_port}"
        echo "HBBR Port: ${toString hbbr_port}"
        echo "Web Console: ${toString hbbs_port_web}"
        echo "Data Directory: ${rustdesk_data}"
        echo -e "\nPublic Key:"
        if [[ -f "${rustdesk_data}/id_ed25519.pub" ]]; then
          cat "${rustdesk_data}/id_ed25519.pub"
        else
          echo "Key file not found. Server may not have started yet."
        fi
      }

      case "$1" in
        status|"")
          show_status
          ;;
        logs)
          show_logs
          ;;
        restart)
          restart_all
          ;;
        config)
          show_config
          ;;
        test)
          echo "Testing RustDesk connectivity..."
          nc -zv localhost ${toString hbbs_port}
          nc -zv localhost ${toString hbbr_port}
          ;;
        *)
          echo "Usage: $0 {status|logs|restart|config|test}"
          echo "  status  - Show service status and ports"
          echo "  logs    - Show recent logs"
          echo "  restart - Restart all services"
          echo "  config  - Show configuration and public key"
          echo "  test    - Test port connectivity"
          exit 1
          ;;
      esac
    '')
  ];
}
