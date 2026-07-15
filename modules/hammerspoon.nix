{
  config,
  pkgs,
  ...
}: let
  # defaults write org.hammerspoon.Hammerspoon MJConfigFile ~/.config/hammerspoon/init.lua
  hammerspoonPath = "${config.xdg.configHome}/hammerspoon";

  # Spoons are plain Lua directories, so we can link them straight from the
  # store. Previously these were `git clone`d in an activation script guarded
  # by `if [ ! -d ... ]`, which meant they were fetched once and then never
  # updated, and each host could end up on a different commit. Pinning the rev
  # keeps every host on the same code; bump rev + hash to update.
  spoons = {
    PaperWM = {
      owner = "mogenson";
      rev = "34787bf38ce429a84f94ae00a73418e32cc1abb8";
      hash = "sha256-hffz5Ae/INkYXRgZVX4FNejCbqC1l1aTigFRDFe8cYM=";
    };
    ActiveSpace = {
      owner = "mogenson";
      rev = "2c250f4aa8f8ebe3fe226335c5a5da74274f1793";
      hash = "sha256-x5AqQTS+c0Er6ZExhaN6SRwqO+GYJ5HXkzOJnZfCcSE=";
    };
    WarpMouse = {
      owner = "mogenson";
      rev = "e231f2a9079e303771bcc22e88e7494bbca37b07";
      hash = "sha256-moMnXaW7M/GxQvYXBc9eCvZD6mwRP+mxx6YU8fLBPVE=";
    };
    Swipe = {
      owner = "mogenson";
      rev = "c56520507d98e663ae0e1228e41cac690557d4aa";
      hash = "sha256-G0kuCrG6lz4R+LdAqNWiMXneF09pLI+xKCiagryBb5k=";
    };
    FocusMode = {
      owner = "selimacerbas";
      rev = "a37361fac8c5bd38d427ba2d9d53e6c4abb56183";
      hash = "sha256-+KP8o+DMfj9s7YPu0gzbpJMXS8rE+w7UnaFSosF7Aks=";
    };
  };

  mkSpoonFile = name: {
    owner,
    rev,
    hash,
  }: {
    name = "${hammerspoonPath}/Spoons/${name}.spoon";
    value.source = pkgs.fetchFromGitHub {
      inherit owner rev hash;
      repo = "${name}.spoon";
    };
  };
in {
  # Note: Hammerspoon itself is not installed by either Darwin host; install it
  # manually or add a `hammerspoon` cask. This module only manages its config.

  home.file =
    builtins.listToAttrs (
      builtins.attrValues (builtins.mapAttrs mkSpoonFile spoons)
    )
    // {
      "${hammerspoonPath}/Spoons/SpoonInstall.spoon/init.lua".source = builtins.fetchurl {
        url = "https://raw.githubusercontent.com/Hammerspoon/Spoons/master/Source/SpoonInstall.spoon/init.lua";
        sha256 = "0bm2cl3xa8rijmj6biq5dx4flr2arfn7j13qxbfi843a8dwpyhvk";
      };

      "${hammerspoonPath}/init.lua".source = ./hammerspoon/init.lua;
    };
}
