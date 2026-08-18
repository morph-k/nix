# Compatibility shims for omarchy-nix against current nixpkgs-unstable.
#
# omarchy-nix is in maintenance mode (last release Nov 2025) and its README
# targets nixos-25.05, while this flake tracks unstable. Rather than fork it,
# patch the specific attribute drift here so the upstream input stays a plain
# pinned reference.
#
# Remove an entry once upstream catches up.
final: prev: {
  # nixpkgs used to expose tuigreet as `greetd.tuigreet`; it is now a
  # top-level package, and `greetd` is the greetd derivation itself.
  # omarchy-nix's modules/nixos/system.nix still uses the old path.
  greetd =
    prev.greetd
    // {
      inherit (prev) tuigreet;
    };

  # `blueberry` was removed from nixpkgs as unmaintained upstream; the removal
  # notice points at blueman, which omarchy-nix already enables as a service
  # (services.blueman.enable in its modules/nixos/system.nix). Its
  # modules/packages.nix still lists blueberry, so alias it.
  blueberry = prev.blueman;
}
