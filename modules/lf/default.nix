# https://github.com/vimjoyer/lf-nix-video
{pkgs, ...}: let
  fzf_search = builtins.readFile ./fzf_search;
in {
  # Download the icons file
  # nix run nixpkgs#wget -- "https://raw.githubusercontent.com/gokcehan/lf/master/etc/icons.example" -O icons
  xdg.configFile."lf/icons".source = ./icons;

  programs.lf = {
    enable = true;
    commands = {
      dragon-out = ''xdragon -a -x "$fx"'';
      editor-open = ''$$EDITOR $f'';
      mkdir = ''
        ''${{
          printf "Directory Name: "
          read DIR
          mkdir $DIR
        }}
      '';
      fzf_jump = ''
        ''${{
            res="$(find . -maxdepth 1 | fzf --reverse --header='Jump to location')"
            if [ -n "$res" ]; then
                if [ -d "$res" ]; then
                    cmd="cd"
                else
                    cmd="select"
                fi
                res="$(printf '%s' "$res" | sed 's/\\/\\\\/g;s/"/\\"/g')"
                lf -remote "send $id $cmd \"$res\""
            fi
        }}
      '';

      fzf_search = ''${fzf_search}'';

      replace-space-in-dirs = ''
        ''${{
            REPLACE_SCRIPT="$HOME/.local/bin/replace_spaces"
            if [ ! -f "$REPLACE_SCRIPT" ]; then
                echo "Error: $REPLACE_SCRIPT not found" >&2
                exit 1
            fi
            [ -x "$REPLACE_SCRIPT" ] || chmod +x "$REPLACE_SCRIPT" 2>/dev/null
            if [ ! -x "$REPLACE_SCRIPT" ]; then
                echo "Error: $REPLACE_SCRIPT is not executable" >&2
                exit 1
            fi
            if [ -z "$fx" ]; then
                echo "No files selected" >&2
                exit 1
            fi
            printf '%s\n' "$fx" | while IFS= read -r d; do
                [ -n "$d" ] || continue
                if [ -d "$d" ]; then
                    echo "Processing: $d"
                    (cd "$d" && "$REPLACE_SCRIPT") || echo "Failed to process: $d" >&2
                else
                    echo "Skipping (not a directory): $d" >&2
                fi
            done
            lf -remote "send $id reload"
        }}
      '';

      open-file = ''
        ''${{
            case $(uname) in
                Linux)
                    if [[ "$fx" == *.pdf ]]; then
                        zathura "$fx" >/dev/null 2>&1 &
                    else
                        xdg-open "$fx" >/dev/null 2>&1 &
                    fi
                    ;;
                Darwin)
                    if [[ "$fx" == *.pdf ]]; then
                        open -a Zathura "$fx" >/dev/null 2>&1 &
                    else
                        open "$fx" >/dev/null 2>&1 &
                    fi
                    ;;
                CYGWIN*|MINGW*|MSYS*) explorer "$(cygpath -w "$fx")" ;;
            esac
        }}
      '';

      copy-path = ''
        ''${{
            case $(uname) in
                Linux) printf '%s' "$fx" | xclip -selection clipboard ;;
                Darwin) printf '%s' "$fx" | pbcopy ;;
            esac
            lf -remote "send $id echo 'Path copied to clipboard'"
        }}
      '';

      edir-bulk = ''
        ''${{
            set -f
            edir -a
            lf -remote "send $id reload"
        }}
      '';

      delete-file = ''
        ''${{
            set -f
            case $(uname) in
                Darwin)
                    echo "$fx" | tr '\n' '\0' | xargs -0 trash 2>/dev/null || rm -rf $fx
                    ;;
                Linux)
                    rm -rf $fx
                    ;;
            esac
            lf -remote "send $id reload"
        }}
      '';

      cdp = ''
                ''${{
                    if [ -z "$PROJECT_PATHES" ]; then
                        lf -remote "send $id echo 'PROJECT_PATHES not set'"
                        exit 0
                    fi
                    dirPaths=""
                    IFS=';' read -ra PD <<< "$PROJECT_PATHES"
                    for i in "''${PD[@]}"; do
                        case "$i" in
                            /*) base="$i" ;;
                            *)  base="$HOME/$i" ;;
                        esac
                        dirs=$(ls -d "$base/"* 2>/dev/null)
                        dirPaths="$dirPaths
        $dirs"
                    done
                    targetDir=$(printf '%s\n' "$dirPaths" | grep -v '^$' | fzf --reverse --header='Jump to project')
                    if [ -n "$targetDir" ]; then
                        lf -remote "send $id cd \"$targetDir\""
                        changes=$(git -C "$targetDir" status --porcelain 2>/dev/null)
                        if [ -z "$changes" ]; then
                            git -C "$targetDir" checkout main 2>/dev/null || git -C "$targetDir" checkout master 2>/dev/null
                            git -C "$targetDir" pull 2>/dev/null
                            lf -remote "send $id echo 'Pulled latest changes'"
                        else
                            lf -remote "send $id echo 'Uncommitted changes - skipping git update'"
                        fi
                    fi
                }}
      '';
    };

    keybindings = {
      "\\\"" = "";
      o = "open-file";
      c = "mkdir";
      "." = "set hidden!";
      "`" = "mark-load";
      "\\'" = "mark-load";
      "<enter>" = "open";
      "<c-f>" = "fzf_jump";
      "<c-s>" = "fzf_search";
      "<c-d>" = "dragon-out";
      "g~" = "cd";
      gh = "cd";
      "g/" = "/";

      ee = "editor-open";
      V = ''$bat --paging=always "$f"'';
      Y = "copy-path";
      R = "edir-bulk";
      dd = "delete-file";
      gp = "cdp";

      # ...
    };

    settings = {
      preview = true;
      hidden = true;
      drawbox = true;
      icons = true;
      ignorecase = true;
    };

    extraConfig = let
      previewer = pkgs.writeShellScriptBin "pv.sh" ''
        file=$1
        w=$2
        h=$3
        x=$4
        y=$5

        if [[ "$( ${pkgs.file}/bin/file -Lb --mime-type "$file")" =~ ^image ]]; then
            # ghostty speaks the kitty graphics protocol; chafa emits it (no kitten icat CLI in ghostty)
            ${pkgs.chafa}/bin/chafa -f kitty --polite on -s "''${w}x''${h}" "$file" < /dev/null > /dev/tty
            exit 1
        fi

        ${pkgs.pistol}/bin/pistol "$file"
      '';
      cleaner = pkgs.writeShellScriptBin "clean.sh" ''
        # delete all images placed via the kitty graphics protocol
        printf '\033_Ga=d\033\\' > /dev/tty
      '';
    in ''
      set cleaner ${cleaner}/bin/clean.sh
      set previewer ${previewer}/bin/pv.sh
    '';
  };
}
