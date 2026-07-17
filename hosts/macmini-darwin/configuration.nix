# macmini system config. Shared Darwin setup lives in
# modules/darwin-common.nix; only host-unique bits go here.
{pkgs, ...}: {
  imports = [
    (import ../../modules/darwin-common.nix {
      hostName = "macmini-darwin";
      dockOrientation = "left";
    })
  ];

  environment.systemPackages = with pkgs; [
    git
    fd
    ripgrep
    duti # sets default app associations (e.g. PDF viewer)
    cachix # push/pull the jedimaster binary cache (see `make push-cachix`)
  ];

  homebrew = {
    taps = [
      "deskflow/tap" # deskflow is not in homebrew/cask; trusted in home-darwin-common.nix
    ];
    # GUI apps that require homebrew casks
    casks = [
      "raycast"
      "barrier"
      "buzz"
      "deskflow"
      "flameshot"
      "free-gpgmail"
      "gcloud-cli"
      "ghostty"
      "gpg-suite-no-mail"
      "hiddenbar"
      "keycastr"
      "libndi"
      "mactex"
      "miniforge"
      "notunes"
      "qmk-toolbox"
      "raspberry-pi-imager"
      "utm"
      "vlc"
    ];
  };

  nix = {
    package = pkgs.nix;
    extraOptions = ''
      auto-optimise-store = true
      experimental-features = nix-command flakes
      gc-keep-outputs = true
      gc-keep-derivations = true
      extra-substituters = https://jedimaster.cachix.org https://nix-community.cachix.org
      extra-trusted-public-keys = jedimaster.cachix.org-1:d3z8VEyrrqcYEe/9wOhIa6iXb4ArWUoQLB5tz1b+CZA= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=
    '';
    enable = false;
  };

  # Cachix auth token for pushing to the jedimaster cache (used by
  # `make push-cachix`, which decrypts it via agenix).
  age.secrets.cachix-token.file = ../../secrets/cachix-token.age;

  # Finder configuration activation script
  system.activationScripts.postActivation.text = ''
    # Run user-specific Finder configuration as the morph user
    sudo -u morph bash -c '
      # Configure Finder to sort by Date Modified (newest first)
      defaults write com.apple.finder FXPreferredGroupBy -string "Date Modified"

      # Remove .DS_Store files to force Finder to use new defaults
      # Only remove from common user directories to avoid system issues
      find ~/Documents ~/Downloads ~/Desktop -name ".DS_Store" -depth -exec rm {} \; 2>/dev/null || true

      # Restart Finder to apply changes
      killall Finder 2>/dev/null || true
    '
  '';
}
