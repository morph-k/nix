{
  config,
  pkgs,
  ...
}: {
  # tailscale
  services.tailscale = {
    enable = true;
  };

  age.identityPaths = [
    "/home/morph/.ssh/id_ed25519"
  ];
  age.secrets.ts-win-wsl.file = ../../secrets/ts-win-wsl.age;

  # create a oneshot job to authenticate to Tailscale
  systemd.services.tailscale-autoconnect = {
    description = "Automatic connection to Tailscale";

    # make sure tailscale is running before trying to connect to tailscale
    after = ["network-pre.target" "tailscale.service"];
    wants = ["network-pre.target" "tailscale.service"];
    wantedBy = ["multi-user.target"];

    serviceConfig.Type = "oneshot";

    script = with pkgs; ''
      # wait for tailscaled to settle
      sleep 2

      # check if we are already authenticated to tailscale
      status="$(${tailscale}/bin/tailscale status -json | ${jq}/bin/jq -r .BackendState)"
      if [ $status = "Running" ]; then # if so, then do nothing
        exit 0
      fi

      # otherwise authenticate with tailscale
      ${tailscale}/bin/tailscale up --authkey=$(cat ${config.age.secrets.ts-win-wsl.path})
    '';
  };

  networking = {
    hostName = "win-wsl";
    firewall = {
      # warning: Strict reverse path filtering breaks Tailscale
      # exit node use and some subnet routing setups.
      checkReversePath = "loose";

      # always allow traffic from your Tailscale network
      trustedInterfaces = ["tailscale0"];

      # allow the Tailscale UDP port through the firewall
      allowedUDPPorts = [config.services.tailscale.port];

      # allow SSH over tailscale
      allowedTCPPorts = [22];
    };
    nameservers = ["100.100.100.100" "8.8.8.8" "1.1.1.1"];
    search = ["tailc585e.ts.net"];
  };
}
