{
  pkgs,
  user,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/nix-caches.nix
  ];

  networking.hostName = "omarchy-linux";

  # Omarchy's own settings. The home-manager module picks these up from
  # osConfig, so they are declared once here.
  omarchy = {
    full_name = "Morphy Kuffour";
    email_address = "morpkuff@gmail.com";
    theme = "tokyo-night";
    # 1 for a standard 1x display; omarchy-nix defaults to 2 (HiDPI).
    scale = 1;
  };

  users.users.${user} = {
    isNormalUser = true;
    description = "Morphy Kuffour";
    extraGroups = ["wheel" "networkmanager" "video" "audio" "input"];
    shell = pkgs.zsh;
  };

  # zsh is the login shell; the actual config is stowed from ~/dots.
  programs.zsh.enable = true;

  # Keep this host in step with the rest of the flake.
  nix.settings.experimental-features = ["nix-command" "flakes"];

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  system.stateVersion = "25.05";
}
