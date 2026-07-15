# Restic backup of ~/Sync to BorgBase (shared by Darwin hosts).
# Uses agenix for secrets, launchd for scheduling (every 4 hours).
{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  home = "/Users/${user}";
in {
  # Agenix identity for decrypting secrets on macOS
  age.identityPaths = [
    "${home}/.ssh/id_ed25519"
  ];

  age.secrets = {
    "restic-borgbase/repo" = {
      file = ../secrets/restic-borgbase/repo.age;
      owner = user;
    };
    "restic-borgbase/password" = {
      file = ../secrets/restic-borgbase/password.age;
      owner = user;
    };
  };

  environment.systemPackages = [pkgs.restic];

  # Restic backup to BorgBase — runs every 4 hours
  launchd.user.agents.restic-backup = {
    serviceConfig = {
      Label = "com.morph.restic-backup";
      ProgramArguments = [
        "/bin/bash"
        "-c"
        ''
          export PATH="${lib.makeBinPath [pkgs.restic pkgs.coreutils]}:/usr/bin:/bin"
          export HOME="${home}"

          REPO_FILE="${config.age.secrets."restic-borgbase/repo".path}"
          PASS_FILE="${config.age.secrets."restic-borgbase/password".path}"

          # Wait for secrets to be available (agenix activation)
          for i in $(seq 1 30); do
            [ -f "$REPO_FILE" ] && [ -f "$PASS_FILE" ] && break
            sleep 2
          done

          if [ ! -f "$REPO_FILE" ] || [ ! -f "$PASS_FILE" ]; then
            echo "ERROR: Secrets not available after 60s"
            exit 1
          fi

          export RESTIC_REPOSITORY="$(cat "$REPO_FILE")"
          export RESTIC_PASSWORD="$(cat "$PASS_FILE")"

          LOG="/tmp/restic-backup.log"
          echo "=== Restic backup started: $(date) ===" >> "$LOG"

          # Initialize repo if needed (idempotent)
          restic snapshots > /dev/null 2>&1 || restic init >> "$LOG" 2>&1

          restic backup \
            --verbose \
            --exclude='.DS_Store' \
            --exclude='*.tmp' \
            --exclude='.Trash' \
            --exclude='node_modules' \
            --exclude='.git' \
            --exclude='__pycache__' \
            --exclude='.venv' \
            --exclude='*.pyc' \
            --exclude='.ruff_cache' \
            --exclude='result' \
            ${home}/Sync \
            >> "$LOG" 2>&1

          BACKUP_EXIT=$?

          # Prune old snapshots (only once a day at the 02:00 run)
          HOUR=$(date +%H)
          if [ "$HOUR" = "02" ]; then
            echo "Running prune..." >> "$LOG"
            restic forget \
              --keep-daily 7 \
              --keep-weekly 5 \
              --keep-monthly 12 \
              --prune \
              >> "$LOG" 2>&1
          fi

          echo "=== Restic backup finished: $(date) (exit: $BACKUP_EXIT) ===" >> "$LOG"
          exit $BACKUP_EXIT
        ''
      ];

      # Run every 4 hours (00:00, 04:00, 08:00, 12:00, 16:00, 20:00)
      StartCalendarInterval = [
        {
          Hour = 0;
          Minute = 0;
        }
        {
          Hour = 4;
          Minute = 0;
        }
        {
          Hour = 8;
          Minute = 0;
        }
        {
          Hour = 12;
          Minute = 0;
        }
        {
          Hour = 16;
          Minute = 0;
        }
        {
          Hour = 20;
          Minute = 0;
        }
      ];

      RunAtLoad = false;
      StandardOutPath = "/tmp/restic-backup.stdout.log";
      StandardErrorPath = "/tmp/restic-backup.stderr.log";
      Nice = 10;
      ProcessType = "Background";
      EnvironmentVariables = {
        HOME = "${home}";
      };
    };
  };
}
