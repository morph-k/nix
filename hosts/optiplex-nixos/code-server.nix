{
  config,
  pkgs,
  ...
}: {
  services.code-server = {
    enable = true;
    user = "morph";
    group = "users";
    host = "127.0.0.1";
    port = 8081; # Using 8081 since qBittorrent uses 8080
    auth = "none"; # Tailscale provides authentication
    extraEnvironment = {
      CS_DISABLE_GETTING_STARTED_OVERRIDE = "1";
    };
  };

  # Tailscale serve for code-server is handled centrally in tailscale.nix
}
