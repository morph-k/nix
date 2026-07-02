# Hardened sshd config for macOS (nix-darwin) hosts.
#
# macOS's /etc/ssh/sshd_config ends with `Include /etc/ssh/sshd_config.d/*`,
# so we drop a hardening file there. nix-darwin manages it via environment.etc.
#
# ⚠️  This enforces key-only auth. Make sure you can SSH in with a key (or via
#     Tailscale SSH) BEFORE `darwin-rebuild switch` — it disables password
#     login to this Mac. To revert, comment out PasswordAuthentication below.
{...}: {
  environment.etc."ssh/sshd_config.d/100-hardening.conf".text = ''
    # Managed by nix (modules/ssh-hardened-darwin.nix)
    PermitRootLogin no
    PasswordAuthentication no
    KbdInteractiveAuthentication no

    # Modern crypto only (per sshaudit.com hardening guides)
    KexAlgorithms mlkem768x25519-sha256,sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org
    Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes256-ctr
    MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com
  '';
}
