# Binary caches shared by every NixOS host in this flake.
#
# The Darwin hosts cannot use this module: Nix there is installed by the
# Determinate installer, which owns /etc/nix/nix.conf, so nix-darwin runs with
# `nix.enable = false` and the same substituters are written through
# `nix.extraOptions` in each host's configuration.nix instead.
#
# jedimaster is the personal Cachix cache (https://app.cachix.org/cache/jedimaster).
# Pushing to it needs the auth token in secrets/cachix-token.age; pulling only
# needs the public key below.
{lib, ...}: {
  nix.settings = {
    # `substituters` is a list, so hosts that add their own (e.g. win-wsl's
    # ai.cachix.org for nixified-ai) simply append to these.
    substituters = lib.mkBefore [
      "https://cache.nixos.org"
      "https://jedimaster.cachix.org"
      "https://nix-community.cachix.org"
    ];

    trusted-public-keys = lib.mkBefore [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "jedimaster.cachix.org-1:d3z8VEyrrqcYEe/9wOhIa6iXb4ArWUoQLB5tz1b+CZA="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
}
