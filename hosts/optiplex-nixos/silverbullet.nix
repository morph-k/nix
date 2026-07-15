{config, ...}: let
  user = "morph";
  uid = builtins.toString config.users.users.morph.uid;
  gid = builtins.toString config.users.groups.users.gid;
  timezone = config.time.timeZone or "Etc/UTC";

  # Use local zettelkasten notes directory
  notesPath = "/home/morph/Org/zettelkasten/notes";
  dataRoot = "/var/lib/silverbullet";
in {
  # Define agenix secret for SilverBullet auth
  age.secrets.silverbullet = {
    file = ../../secrets/silverbullet-optiplex-nixos.age;
    mode = "600";
    owner = user;
    group = "users";
  };

  virtualisation.oci-containers.containers.silverbullet = {
    image = "ghcr.io/silverbulletmd/silverbullet:latest";
    autoStart = true;
    ports = ["3030:3000"];
    volumes = [
      "${notesPath}:/space"
    ];
    environment = {
      TZ = timezone;
    };
    # Load SB_USER from agenix secret file
    environmentFiles = [config.age.secrets.silverbullet.path];
    # Run as morph user
    user = "${uid}:${gid}";
  };

  # Ensure directories exist
  systemd.tmpfiles.rules = [
    "d ${dataRoot} 0750 ${user} users - -"
    "d ${notesPath} 0750 ${user} users - -"
  ];

  networking.firewall.allowedTCPPorts = [3030];
}
