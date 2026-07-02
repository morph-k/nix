{
  config,
  pkgs,
  lib,
  nixified-ai,
  ...
}: let
  # Get ComfyUI from nixified.ai flake input
  comfyui-nvidia = nixified-ai.packages.${pkgs.system}.comfyui-nvidia or null;

  comfyuiPort = 8188;
in {
  networking.firewall.allowedTCPPorts = [comfyuiPort];

  # SystemD service to run ComfyUI persistently
  systemd.services.comfyui = lib.mkIf (comfyui-nvidia != null) {
    description = "ComfyUI - Stable Diffusion WebUI with NVIDIA GPU support";
    after = ["network.target"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "simple";
      User = "morph";
      Group = "users";
      Restart = "on-failure";
      RestartSec = "10s";

      WorkingDirectory = "/home/morph/comfyui-data";

      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /home/morph/comfyui-data";

      ExecStart = "${comfyui-nvidia}/bin/comfyui --listen 0.0.0.0 --port ${toString comfyuiPort}";

      # Environment variables for NVIDIA GPU
      Environment = [
        "CUDA_VISIBLE_DEVICES=0"
        "LD_LIBRARY_PATH=/usr/lib/wsl/lib"
      ];
    };
  };

  # SystemD service to expose ComfyUI via Tailscale Funnel
  systemd.services.tailscale-funnel-comfyui = {
    description = "Expose ComfyUI via Tailscale Funnel";
    after = ["tailscale.service" "comfyui.service"];
    wants = ["tailscale.service" "comfyui.service"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "root";

      ExecStart = "${pkgs.tailscale}/bin/tailscale funnel --bg --https=${toString comfyuiPort} ${toString comfyuiPort}";

      ExecStop = "${pkgs.tailscale}/bin/tailscale funnel --https=${toString comfyuiPort} off";
    };
  };

  environment.variables = {
    COMFYUI_PORT = toString comfyuiPort;
  };
}
