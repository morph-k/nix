# nix

System configurations for macOS, NixOS, and WSL.

## Hosts

| Host               | OS             | Arch      |
|--------------------|----------------|-----------|
| `macmini-darwin`   | macOS          | aarch64   |
| `mbp-darwin`       | macOS          | aarch64   |
| `optiplex-nixos`   | NixOS (ZFS)    | x86_64    |
| `win-wsl`          | NixOS (WSL)    | x86_64    |
| `rpi3b-nixos`      | NixOS          | aarch64 (cross-built from x86_64) |
| `utm-builder`      | NixOS (UTM VM) | aarch64   |
| `utm-installer`    | NixOS (UTM VM) | aarch64   |
| `riscv-vm`         | NixOS          | riscv64   |

## Usage

```bash
git clone https://github.com/morph-k/nix
cd nix
make build    # build the current host
make switch   # build and switch
```

`make` picks the host from the machine's `hostname`, so it only works when
`hostname` matches one of the names above. Target another host explicitly with
`make build HOSTNAME=optiplex-nixos`.

Other targets: `rebuild`, `update`, `fmt`, `clean`, `optimize`, `wsl-build`,
`push-cachix`, and the remote/deploy targets (`remote-switch`, `remote-build`,
`optiplex-deploy`, `optiplex-build-remote`).

## Images

Built for `aarch64-linux`; the SD card image needs `--impure` since it is built
off-platform.

```bash
NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1 nix build .#packages.aarch64-linux.rpi3b-sdcard --impure
nix build .#packages.aarch64-linux.utm-builder-image
nix build .#packages.aarch64-linux.utm-installer-iso
```

## Development

```bash
nix develop       # dev shell
nix fmt           # format with alejandra
nix flake check   # formatting + per-host eval
```
