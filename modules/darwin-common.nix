# Shared nix-darwin system config for the Darwin hosts (macmini, mbp).
#
# Called as a function with the host's differing values; each host imports it
# and keeps only its host-unique config (casks, extra services, nix
# substituters, activation scripts).
#
#   imports = [ (import ../../modules/darwin-common.nix {
#     hostName = "macmini-darwin";
#     dockOrientation = "left";
#   }) ];
{
  hostName,
  dockOrientation,
}: {
  pkgs,
  user,
  ...
}: {
  imports = [
    ./rawtalk
    ./kanata
  ];

  users.users.${user} = {
    home = "/Users/${user}";
    shell = pkgs.zsh;
  };

  networking = {
    computerName = hostName;
    hostName = hostName;
  };

  # FiraCode is what dots/ghostty/.config/ghostty/config asks for; JetBrainsMono
  # is what dots/fontconfig expects. Installed here rather than as a cask so
  # both Darwin hosts get them (mbp previously had neither).
  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
  ];

  environment = {
    shells = with pkgs; [zsh];
    variables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      TERMINAL = "ghostty";
    };
  };

  programs = {
    zsh.enable = true;
  };

  homebrew = {
    enable = true;
    global = {
      brewfile = false;
    };
    onActivation = {
      autoUpdate = false;
      cleanup = "none";
      upgrade = false;
    };
    brews = [];
  };

  nixpkgs.config = {
    allowUnfree = true;
    allowUnsupportedSystem = true;
  };

  # Kanata key remapper (cross-platform, migrated from keyd)
  services.kanata-remapper = {
    enable = true;
  };

  # Rawtalk QMK Layer Switcher Service
  services.rawtalk = {
    enable = true;
  };

  system = {
    primaryUser = user;
    defaults = {
      NSGlobalDomain = {
        KeyRepeat = 1;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;

        # Disable/reduce animations
        NSAutomaticWindowAnimationsEnabled = false;
        NSWindowResizeTime = 0.001;
      };
      dock = {
        autohide = true;
        orientation = dockOrientation;
        showhidden = true;
        tilesize = 40;
        launchanim = false;

        # Remove Dock/Mission Control animation delays
        autohide-delay = 0.0;
        autohide-time-modifier = 0.0;
        expose-animation-duration = 0.1;
      };
      finder = {
        QuitMenuItem = false;
        AppleShowAllExtensions = true;
        ShowPathbar = true;
        ShowStatusBar = true;
        FXPreferredViewStyle = "Nlsv"; # Nlsv=List, icnv=Icon, clmv=Column, glyv=Gallery
        FXDefaultSearchScope = "SCcf"; # SCcf = search current folder
        FXEnableExtensionChangeWarning = false;
        _FXSortFoldersFirst = true;
      };
      trackpad = {
        Clicking = true;
        TrackpadRightClick = true;
      };
      spaces = {
        # Prevent other displays from going black when one is fullscreen
        spans-displays = true;
      };
    };
    keyboard = {
      enableKeyMapping = true;
    };

    stateVersion = 4;
  };
}
