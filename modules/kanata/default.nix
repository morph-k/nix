{
  config,
  lib,
  pkgs,
  ...
} @ args: let
  cfg = config.services.kanata-remapper;
  isDarwin = builtins.hasAttr "launchd" (args.options or {});
  kanataConfigFile = pkgs.writeText "kanata.kbd" cfg.config;
in {
  options.services.kanata-remapper = {
    enable = lib.mkEnableOption "Kanata key remapping daemon";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.kanata;
      defaultText = lib.literalExpression "pkgs.kanata";
      description = "The kanata package to use.";
    };

    config = lib.mkOption {
      type = lib.types.lines;
      default = builtins.readFile ./kanata.kbd;
      description = ''
        Kanata keyboard configuration in .kbd format.
        Defaults to the shared kanata.kbd (migrated from keyd).
      '';
    };

    devices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Linux only: list of /dev/input device paths.
        Empty list means all devices.
      '';
    };

    extraDefCfg = lib.mkOption {
      type = lib.types.str;
      default = "process-unmapped-keys yes";
      description = "Extra defcfg options passed to kanata.";
    };
  };

  config = lib.mkIf cfg.enable (
    if isDarwin
    then {
      # ── macOS (nix-darwin) ─────────────────────────────────────────
      environment.systemPackages = [cfg.package];

      # Copy kanata to a stable path AND sign it with a stable self-signed
      # identity so macOS TCC (Input Monitoring) permission survives upgrades.
      #
      # TCC keys the Input Monitoring grant on the binary's code requirement.
      # A nix-built (ad-hoc-signed) binary is keyed on its cdhash, which changes
      # on every kanata version bump -> grant revoked -> GUI re-grant needed.
      # Re-signing with a fixed self-signed cert makes the requirement
      #   identifier "com.morph.kanata" and certificate leaf = H"<cert>"
      # which does NOT change across version bumps, so the grant persists.
      #
      # The very first grant still has to be done once in System Settings (the
      # TCC db is SIP-protected; there is no supported way to write it). After
      # that, future upgrades re-sign with the same identity and need no GUI.
      system.activationScripts.postActivation.text = ''
        kc=/Library/Keychains/System.keychain
        identity=kanata-codesign
        # LibreSSL's `security import` fails MAC verification on empty-password
        # PKCS12 ("MAC verification failed (wrong password?)"), so the bundle
        # must carry a real passphrase. It is fixed and local-only: the bundle
        # never leaves this machine and the cert is just a stable signing anchor.
        p12pass=kanata-codesign
        stamp=/usr/local/bin/.kanata-source
        want=${cfg.package}/bin/kanata
        certCreated=0

        /bin/mkdir -p /usr/local/bin

        # 1. Ensure the stable self-signed code-signing identity exists.
        #    Query WITHOUT `-v`: the cert is self-signed and therefore untrusted
        #    (CSSMERR_TP_NOT_TRUSTED), so the valid-only `-v` listing never shows
        #    it — which would recreate the identity on every single activation.
        #    codesign can still sign with an untrusted identity by name.
        if ! /usr/bin/security find-identity -p codesigning "$kc" 2>/dev/null | /usr/bin/grep -q "$identity"; then
          tmp=$(/usr/bin/mktemp -d)
          # Guard the whole create+import chain: a failure here must never abort
          # the activation (it runs under `set -e`). Worst case we fall back to
          # ad-hoc signing and per-upgrade GUI re-grants — kanata still runs.
          if /usr/bin/openssl req -x509 -newkey rsa:2048 -nodes \
               -keyout "$tmp/key.pem" -out "$tmp/cert.pem" -days 36500 \
               -subj "/CN=$identity" \
               -addext "basicConstraints=critical,CA:FALSE" \
               -addext "keyUsage=critical,digitalSignature" \
               -addext "extendedKeyUsage=critical,codeSigning" >/dev/null 2>&1 \
             && /usr/bin/openssl pkcs12 -export -inkey "$tmp/key.pem" -in "$tmp/cert.pem" \
               -out "$tmp/id.p12" -passout pass:"$p12pass" >/dev/null 2>&1 \
             && /usr/bin/security import "$tmp/id.p12" -k "$kc" -P "$p12pass" -A -T /usr/bin/codesign >/dev/null 2>&1; then
            # Best-effort: let codesign use the key without an interactive prompt.
            /usr/bin/security set-key-partition-list -S apple-tool:,apple:,codesign: -k "" "$kc" >/dev/null 2>&1 || true
            certCreated=1
          else
            echo "  >>> WARNING: could not create kanata signing identity; using ad-hoc signature." >&2
          fi
          /bin/rm -rf "$tmp"
        fi

        # 2. Install + sign the binary only when the source store path changes.
        #    Re-signing every activation is unnecessary churn; the stamp records
        #    which /nix/store kanata is currently installed.
        if [ "$(/bin/cat "$stamp" 2>/dev/null)" != "$want" ] || [ ! -x /usr/local/bin/kanata ]; then
          /bin/cp -f "$want" /usr/local/bin/kanata.new
          /bin/chmod 755 /usr/local/bin/kanata.new
          # Sign before swapping so the live binary is never unsigned. Only sign
          # with the stable identity if it actually exists; otherwise the copied
          # binary keeps its ad-hoc signature and kanata still runs (just back to
          # per-upgrade GUI re-grants), so this never bricks.
          if /usr/bin/security find-identity -p codesigning "$kc" 2>/dev/null | /usr/bin/grep -q "$identity"; then
            /usr/bin/codesign --force --keychain "$kc" \
              --sign "$identity" --identifier com.morph.kanata \
              /usr/local/bin/kanata.new >/dev/null 2>&1 || true
          fi
          /bin/mv -f /usr/local/bin/kanata.new /usr/local/bin/kanata
          echo "$want" > "$stamp"
          /bin/launchctl kickstart -k system/org.kanata.daemon 2>/dev/null || true

          if [ "$certCreated" = 1 ]; then
            echo ""
            echo "  >>> kanata is now signed with a stable identity (com.morph.kanata)."
            echo "  >>> Grant Input Monitoring ONE last time:"
            echo "  >>>   System Settings -> Privacy & Security -> Input Monitoring"
            echo "  >>>   Remove any existing 'kanata' entry, click +, press Cmd-Shift-G,"
            echo "  >>>   enter /usr/local/bin/kanata, add it, and toggle it ON."
            echo "  >>> Future kanata upgrades will re-sign automatically and need NO re-grant."
            echo ""
          else
            echo "  >>> kanata upgraded and re-signed; Input Monitoring grant preserved."
          fi
        fi
      '';

      launchd.daemons.kanata = {
        serviceConfig = {
          Label = "org.kanata.daemon";
          ProgramArguments = [
            "/usr/local/bin/kanata"
            "--cfg"
            "${kanataConfigFile}"
            "--nodelay"
            "--no-wait"
          ];
          RunAtLoad = true;
          KeepAlive = true;
          ProcessType = "Interactive";
          StandardOutPath = "/tmp/kanata.log";
          StandardErrorPath = "/tmp/kanata.err.log";
        };
      };
    }
    else {
      # ── Linux (NixOS) ──────────────────────────────────────────────
      boot.kernelModules = ["uinput"];
      hardware.uinput.enable = true;

      services.udev.extraRules = ''
        KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"
      '';

      users.groups.uinput = {};

      systemd.services.kanata-internalKeyboard.serviceConfig = {
        SupplementaryGroups = ["input" "uinput"];
      };

      services.kanata = {
        enable = true;
        keyboards.internalKeyboard = {
          devices = cfg.devices;
          extraDefCfg = cfg.extraDefCfg;
          config = cfg.config;
        };
      };
    }
  );
}
