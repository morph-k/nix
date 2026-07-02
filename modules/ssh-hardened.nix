# Shared hardened OpenSSH defaults for NixOS hosts.
#
# NixOS-only — darwin hosts use macOS's own sshd and must be hardened
# separately (or accessed via Tailscale SSH). Do not import on WSL hosts
# that don't run sshd.
#
# All values use lib.mkDefault so any host can override a single setting.
# Crypto sets follow the sshaudit.com hardening guides.
{lib, ...}: {
  services.openssh = {
    enable = lib.mkDefault true;
    settings = {
      # Auth: keys/certs only, no root password login.
      PasswordAuthentication = lib.mkDefault false;
      KbdInteractiveAuthentication = lib.mkDefault false;
      PermitRootLogin = lib.mkDefault "prohibit-password";

      # Modern crypto only.
      KexAlgorithms = lib.mkDefault [
        "mlkem768x25519-sha256" # ML-KEM (NIST FIPS 203) post-quantum KEX
        "sntrup761x25519-sha512@openssh.com"
        "curve25519-sha256"
        "curve25519-sha256@libssh.org"
      ];
      Ciphers = lib.mkDefault [
        "chacha20-poly1305@openssh.com"
        "aes256-gcm@openssh.com"
        "aes256-ctr"
      ];
      Macs = lib.mkDefault [
        "hmac-sha2-512-etm@openssh.com"
        "hmac-sha2-256-etm@openssh.com"
        "umac-128-etm@openssh.com"
      ];
    };
  };
}
