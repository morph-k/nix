# https://www.arthurkoziel.com/restic-backups-b6-nixos/
{
  config,
  pkgs,
  agenix,
  ...
}: {
  # use agenix for passwordFile
  age.identityPaths = [
    "/home/morph/.ssh/id_ed25519"
  ];

  age.secrets = {
    "restic/env".file = ../../secrets/restic/env.age;
    "restic/repo".file = ../../secrets/restic/repo.age;
    "restic/password".file = ../../secrets/restic/password.age;
  };

  environment.systemPackages = [pkgs.restic];

  services.restic.backups = {
    daily = {
      initialize = true;

      environmentFile = config.age.secrets."restic/env".path;
      repositoryFile = config.age.secrets."restic/repo".path;
      passwordFile = config.age.secrets."restic/password".path;

      paths = [
        "/home/morph/iCloud"
      ];

      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 5"
        "--keep-monthly 12"
      ];
    };
  };
}
