{pkgs, ...}: {
  # ============================================================================
  # VERT File Converter - Complete Setup
  # ============================================================================
  # This module combines:
  # 1. VERT frontend (Docker container) - Web UI on port 3000
  # 2. vertd backend (systemd service) - Rust + ffmpeg conversion on port 24153
  # 3. vertd package override - Custom build with proper OpenSSL support
  # ============================================================================

  # --------------------------------------------------------------------------
  # PART 1: Package Override (from vertd-package.nix)
  # --------------------------------------------------------------------------
  # The vertd flake has a bug where buildDepsOnly doesn't get the nativeBuildInputs
  # So we need to override the package to fix the cargo dependency build

  # NOTE: This is currently disabled due to build issues. If you need vertd:
  # 1. Uncomment the nixpkgs.overlays section below
  # 2. Run the build once to get the correct cargoHash from the error
  # 3. Replace the placeholder hash with the real hash
  # 4. Rebuild

  # nixpkgs.overlays = [
  #   (final: prev: let
  #     crane = inputs.vertd.inputs.crane.mkLib prev;
  #     src = crane.cleanCargoSource inputs.vertd;
  #
  #     commonArgs = {
  #       inherit src;
  #       strictDeps = true;
  #       # Add build dependencies - openssl.dev in nativeBuildInputs so setup hooks run
  #       nativeBuildInputs = [
  #         prev.pkg-config
  #         prev.openssl.dev
  #       ];
  #       buildInputs = [
  #         prev.openssl
  #       ];
  #     };
  #
  #     # Build cargo dependencies (fixed-output) so the network can be used to vendor deps
  #     cargoArtifacts = crane.buildDepsOnly (commonArgs // {
  #       # Placeholder: rebuild once to get the correct hash from the error, then paste it here
  #       cargoHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  #     });
  #
  #     # Build vertd with the artifacts
  #     vertd-fixed = crane.buildPackage (commonArgs // {
  #       inherit cargoArtifacts;
  #       nativeBuildInputs = commonArgs.nativeBuildInputs ++ [
  #         prev.makeWrapper
  #       ];
  #       # Set environment variables for the final build too
  #       PKG_CONFIG_PATH = "${prev.openssl.dev}/lib/pkgconfig";
  #       OPENSSL_DIR = "${prev.openssl.dev}";
  #       OPENSSL_LIB_DIR = "${prev.openssl.out}/lib";
  #       OPENSSL_INCLUDE_DIR = "${prev.openssl.dev}/include";
  #       postFixup = ''
  #         wrapProgram $out/bin/vertd --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ prev.libGL ]}"
  #       '';
  #       meta = {
  #         description = "VERT's solution to video conversion";
  #         homepage = "https://github.com/vert-sh/vertd";
  #         license = lib.licenses.gpl3;
  #         platforms = lib.platforms.linux;
  #         mainProgram = "vertd";
  #       };
  #     });
  #   in {
  #     vertd = vertd-fixed;
  #   })
  # ];

  # --------------------------------------------------------------------------
  # PART 2: Docker Frontend (from vert-docker.nix)
  # --------------------------------------------------------------------------
  # VERT file converter Docker container
  # Note: Pre-built images have environment vars baked in at build time
  # To connect to local vertd, configure the backend URL in the VERT web UI:
  # Settings → Instance URL → https://optiplex-nixos.tailc585e.ts.net:24153

  virtualisation.oci-containers.containers.vert = {
    image = "ghcr.io/vert-sh/vert:latest";
    autoStart = true;
    ports = ["3000:80"];
    extraOptions = [
      "--health-cmd=curl --fail --silent --output /dev/null http://localhost || exit 1"
      "--health-interval=30s"
      "--health-timeout=10s"
      "--health-start-period=5s"
    ];
  };

  virtualisation.docker.enable = true;
  virtualisation.oci-containers.backend = "docker";

  # --------------------------------------------------------------------------
  # PART 3: vertd Backend Service (from vertd.nix) - DISABLED
  # --------------------------------------------------------------------------
  # NOTE: vertd service is currently disabled due to build issues
  # Port 24153 is being served directly by Tailscale without a backend
  # To re-enable:
  # 1. Fix the package overlay above (get correct cargoHash)
  # 2. Uncomment the systemd.services.vertd section below
  # 3. Uncomment inputs.vertd.nixosModules.default in default.nix

  # systemd.services.vertd = {
  #   description = "VERT's solution to video conversion";
  #   after = [ "network.target" ];
  #   wantedBy = [ "multi-user.target" ];
  #
  #   serviceConfig = {
  #     Type = "simple";
  #     ExecStart = "${pkgs.vertd}/bin/vertd --port 24153";
  #     Restart = "on-failure";
  #     RestartSec = "10s";
  #     # Security settings
  #     NoNewPrivileges = true;
  #     PrivateTmp = true;
  #     ProtectSystem = "strict";
  #     ProtectHome = false;
  #     ReadWritePaths = [ "/tmp" ];
  #   };
  #
  #   environment = {
  #     # Ensure ffmpeg is available - use mkForce to override default PATH
  #     PATH = lib.mkForce (lib.makeBinPath [
  #       pkgs.ffmpeg-full
  #       pkgs.coreutils
  #       pkgs.findutils
  #       pkgs.gnugrep
  #       pkgs.gnused
  #       pkgs.systemd
  #     ]);
  #   };
  # };

  # # Open firewall port for vertd
  # networking.firewall.allowedTCPPorts = [24153];

  # --------------------------------------------------------------------------
  # Common Dependencies
  # --------------------------------------------------------------------------

  # Ensure ffmpeg and git are available system-wide
  environment.systemPackages = with pkgs; [
    ffmpeg-full
    git
  ];
}
