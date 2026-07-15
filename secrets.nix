let
  # ── Recipient public keys (host SSH keys; agenix decrypts with the matching
  #    private key via each host's age.identityPaths). ──────────────────────
  mbp-darwin = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPpQReeKlZj9HBIJ3S6HwcTKj0gXADOn24zfoGduUj1U morph@morphys-macbook-pro.tailc585e.ts.net";
  macmini-darwin = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICVpvLJJJ9smtoSoKr44/1w+ycmMlSVGL+vdP7TTiIjp my-mac";
  optiplex-nixos = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICfHWXdhc5lgq/TWe8LfsVi7SsDTKjqD/GSSZtR5lPbx morph@nixos";

  # Admin identities = the machines you actually use today (both Macs).
  # Included as a recipient of EVERY secret so you can always decrypt and
  # `agenix --rekey` from a Mac, even for secrets a remote host consumes.
  admin = [mbp-darwin macmini-darwin];

  # Least-privilege helper: admin can always decrypt; add the consuming host(s).
  forHosts = hosts: admin ++ hosts;
in {
  # ── Mac-only secrets (admin is the consumer) ────────────────────────────
  "secrets/cachix-token.age".publicKeys = admin;
  "secrets/restic-borgbase/repo.age".publicKeys = admin;
  "secrets/restic-borgbase/password.age".publicKeys = admin;

  # ── optiplex-nixos secrets ──────────────────────────────────────────────
  "secrets/ts-optiplex-nixos.age".publicKeys = forHosts [optiplex-nixos];
  "secrets/silverbullet-optiplex-nixos.age".publicKeys = forHosts [optiplex-nixos];
  "secrets/rustdesk-optiplex-nixos.age".publicKeys = forHosts [optiplex-nixos];
  "secrets/rustdesk-key-optiplex-nixos.age".publicKeys = forHosts [optiplex-nixos];

  # ── Hosts whose public key isn't defined here yet (win-wsl, rpi3b).
  #    Admin-only for now; when the host returns, define its key above, change
  #    these to `forHosts [<host>]`, and run `agenix --rekey`. ──────────────
  "secrets/ts-win-wsl.age".publicKeys = admin;
  "secrets/ts-rpi3b-nixos.age".publicKeys = admin;
}
