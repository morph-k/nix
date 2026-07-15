{
  config,
  lib,
  pkgs,
  ...
}: {
  # Simple working Stremio server using official web app
  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;

    virtualHosts = {
      # Serve on port 8080 for Tailscale access
      "default" = {
        listen = [
          {
            addr = "0.0.0.0";
            port = 8080;
          }
        ];
        locations = {
          "/" = {
            proxyPass = "https://app.strem.io";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_ssl_server_name on;
              proxy_set_header Host app.strem.io;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;

              # CORS headers for Stremio
              add_header Access-Control-Allow-Origin "*" always;
              add_header Access-Control-Allow-Methods "GET, POST, OPTIONS" always;
              add_header Access-Control-Allow-Headers "Origin, Content-Type, Accept, Authorization" always;

              if ($request_method = OPTIONS) {
                return 204;
              }

              # Handle redirects properly
              proxy_redirect https://app.strem.io/ /;
            '';
          };

          # Local streaming server fallback
          "/streaming/" = {
            return = "200 '{\"streaming_server_url\":\"https://app.strem.io\"}'";
            extraConfig = ''
              add_header Content-Type application/json;
              add_header Access-Control-Allow-Origin "*";
            '';
          };
        };
      };
    };
  };

  # Firewall configuration
  networking.firewall = {
    allowedTCPPorts = [
      8080 # Main Stremio access port
    ];
  };

  # Create Stremio management script
  environment.systemPackages = with pkgs; [
    (writeScriptBin "stremio-manager" ''
      #!${bash}/bin/bash

      case "$1" in
        "status")
          echo "Stremio Web Proxy Status:"
          systemctl status nginx.service | grep -E "(Active|Main PID)"
          echo ""
          echo "Access URLs:"
          echo "  Local: http://localhost:8080"
          echo "  Tailscale: https://$(${config.services.tailscale.package}/bin/tailscale ip -4):8080"
          echo ""
          echo "Direct Stremio Web: https://app.strem.io"
          ;;
        "restart")
          echo "Restarting Nginx proxy..."
          systemctl restart nginx.service
          systemctl status nginx.service
          ;;
        "logs")
          echo "Nginx logs:"
          journalctl -u nginx.service --no-pager -n 20
          ;;
        "test")
          echo "Testing connectivity..."
          curl -I http://localhost:8080 2>/dev/null && echo "✅ Local access works" || echo "❌ Local access failed"
          curl -I https://app.strem.io 2>/dev/null && echo "✅ Upstream Stremio works" || echo "❌ Upstream Stremio failed"
          ;;
        "addons")
          echo "🔌 Recommended Stremio Addons:"
          echo ""
          echo "🎬 Torrentio (Premium torrents):"
          echo "   https://torrentio.strem.fun"
          echo ""
          echo "📝 OpenSubtitles (Subtitles):"
          echo "   https://opensubtitles.strem.fun"
          echo ""
          echo "🎥 YouTube (YouTube content):"
          echo "   https://youtube.strem.fun"
          echo ""
          echo "📺 IPTV (Live TV):"
          echo "   https://iptv-org.strem.fun"
          echo ""
          echo "🎌 Anime Kitsu (Anime):"
          echo "   https://anime-kitsu.strem.fun"
          echo ""
          echo "💎 TMDB (Movie Database):"
          echo "   https://tmdb-addon.strem.fun"
          echo ""
          echo "To add an addon:"
          echo "1. Open Stremio at https://$(${config.services.tailscale.package}/bin/tailscale ip -4):8080"
          echo "2. Go to Addons section"
          echo "3. Click + and paste the addon URL"
          ;;
        *)
          echo "Stremio Web Proxy Manager"
          echo "Usage: $0 {status|restart|logs|test|addons}"
          echo ""
          echo "Commands:"
          echo "  status   - Show service status and access URLs"
          echo "  restart  - Restart the nginx proxy"
          echo "  logs     - Show nginx logs"
          echo "  test     - Test connectivity"
          echo "  addons   - List recommended addons"
          ;;
      esac
    '')
  ];

  # Update existing Tailscale serve configuration
  systemd.services.tailscale-serve-config = {
    serviceConfig.ExecStart = lib.mkForce (
      "${pkgs.bash}/bin/bash -euc '"
      +
      # Existing serves from tailscale.nix
      "${config.services.tailscale.package}/bin/tailscale serve --bg --https=445 http://127.0.0.1:3030; "
      + "${config.services.tailscale.package}/bin/tailscale serve --bg --https=443 --set-path=/search http://127.0.0.1:8888; "
      + "${config.services.tailscale.package}/bin/tailscale serve --bg --https=8443 http://127.0.0.1:8888; "
      + "${config.services.tailscale.package}/bin/tailscale serve --bg --https=444 http://127.0.0.1:3000; "
      + "${config.services.tailscale.package}/bin/tailscale serve --bg --https=8081 http://127.0.0.1:8081; "
      + "${config.services.tailscale.package}/bin/tailscale serve --bg --https=24153 http://127.0.0.1:24153; "
      + "${config.services.tailscale.package}/bin/tailscale serve --bg --https=6060 http://127.0.0.1:6060; "
      +
      # Add Stremio proxy on port 8080
      "${config.services.tailscale.package}/bin/tailscale serve --bg --https=8080 http://127.0.0.1:8080'"
    );

    serviceConfig.ExecStop = lib.mkForce (
      "${pkgs.bash}/bin/bash -euc '"
      + "${config.services.tailscale.package}/bin/tailscale serve --https=445 off || true; "
      + "${config.services.tailscale.package}/bin/tailscale serve --https=443 --set-path=/search off || true; "
      + "${config.services.tailscale.package}/bin/tailscale serve --https=8443 off || true; "
      + "${config.services.tailscale.package}/bin/tailscale serve --https=444 off || true; "
      + "${config.services.tailscale.package}/bin/tailscale serve --https=8081 off || true; "
      + "${config.services.tailscale.package}/bin/tailscale serve --https=24153 off || true; "
      + "${config.services.tailscale.package}/bin/tailscale serve --https=6060 off || true; "
      +
      # Remove Stremio serve
      "${config.services.tailscale.package}/bin/tailscale serve --https=8080 off || true'"
    );

    after = [
      "tailscale.service"
      "nginx.service"
    ];

    wants = [
      "tailscale.service"
      "nginx.service"
    ];
  };
}
