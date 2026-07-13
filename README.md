# nix

System configurations for macOS, NixOS, and WSL.

## Hosts

| Host               | OS          | Arch    |
|--------------------|-------------|---------|
| `macmini-darwin`   | macOS       | aarch64 |
| `mbp-darwin`       | macOS       | aarch64 |
| `optiplex-nixos`   | NixOS (ZFS) | x86_64  |
| `win-wsl`          | NixOS (WSL) | x86_64  |
| `rpi3b-nixos`      | NixOS       | aarch64 |

## Usage

```bash
git clone https://github.com/morphykuffour/nix
cd nix
make build    # build the current host
make switch   # build and switch
```
