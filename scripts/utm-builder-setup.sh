#!/usr/bin/env bash
# Stand up a small aarch64-linux NixOS VM under UTM and register it as a Nix
# remote builder for this Darwin host.
#
# Why a VM rather than cross-compilation: anything whose build step executes
# the artifact it produces cannot be cross-compiled. SBCL's save-lisp-and-die
# dumps a *running* image, so a Linux binary can only come out of a running
# Linux process. Because the guest is aarch64 on aarch64 Apple Silicon there is
# no emulation, so it runs at native speed.
#
# Why not nix-darwin's `nix.linux-builder`: that option asserts `nix.enable`,
# and Nix here is managed by the Determinate installer, which owns
# /etc/nix/nix.conf. Nix reads /etc/nix/machines by default regardless of who
# manages nix.conf, so registering there coexists with it.
#
# Usage:
#   utm-builder-setup.sh create     # create the VM from the NixOS ISO and boot it
#   utm-builder-setup.sh install    # partition and install NixOS over SSH
#   utm-builder-setup.sh register   # wire the VM up as a Nix remote builder (needs sudo)
#
# `register` is only needed for *transparent* offloading, where plain
# `nix build` on a Linux derivation is handed to the VM automatically. It edits
# /etc/nix/machines, hence sudo, and it only has any effect because this host's
# trusted-users is just `root` — an untrusted user's --builders flag is ignored.
#
# Without registering, the VM is still usable as a build machine by targeting
# its store directly, which needs no sudo and no system files:
#
#   export NIX_SSHOPTS="-i ~/.ssh/utm_builder"
#   nix build --store ssh-ng://builder@<vm-ip> <installable>
#
# The difference: --store builds *into the VM's store* and leaves the result
# there, whereas a registered builder copies results back to the local store.
#
# Between the two, install NixOS in the VM console using
# modules/utm-builder.nix as the configuration.

set -euo pipefail

VM_NAME="utm-builder"
ISO="${ISO:-$HOME/utm-images/nixos-minimal-aarch64.iso}"
DISK_MIB=40960
VM_MEMORY=6144
VM_CORES=4
SSH_KEY="$HOME/.ssh/utm_builder"
ROOT_SSH_DIR="/var/root/.ssh"
MACHINES_FILE="/etc/nix/machines"
CUSTOM_CONF="/etc/nix/nix.custom.conf"

print_step() { echo -e "\033[1;34m[STEP]\033[0m $1"; }
print_warn() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
print_err() { echo -e "\033[1;31m[FAIL]\033[0m $1" >&2; }

vm_exists() { utmctl list | awk 'NR>1 {print $3}' | grep -qx "$VM_NAME"; }

cmd_create() {
  [ -f "$ISO" ] || {
    print_err "ISO not found: $ISO"
    exit 1
  }

  # Never boot an unverified installer image.
  if [ -f "$(dirname "$ISO")/expected.sha256" ]; then
    print_step "Verifying ISO checksum"
    local expected actual
    expected="$(awk '{print $1}' "$(dirname "$ISO")/expected.sha256")"
    actual="$(shasum -a 256 "$ISO" | awk '{print $1}')"
    [ "$expected" = "$actual" ] || {
      print_err "ISO checksum mismatch — refusing to boot it."
      print_err "  expected $expected"
      print_err "  actual   $actual"
      exit 1
    }
  else
    print_warn "No expected.sha256 alongside the ISO; skipping verification"
  fi

  # UTM is sandboxed and cannot open arbitrary paths handed to it over
  # AppleScript — creation succeeds but starting fails with "Cannot access
  # resource". Staging the ISO inside UTM's own container avoids this, since
  # the app has unrestricted access there.
  local utm_docs="$HOME/Library/Containers/com.utmapp.UTM/Data/Documents"
  local staged_iso="$utm_docs/$(basename "$ISO")"
  if [ ! -f "$staged_iso" ]; then
    print_step "Staging ISO inside UTM's container (sandbox requirement)"
    mkdir -p "$utm_docs"
    cp "$ISO" "$staged_iso"
  fi
  ISO="$staged_iso"

  if vm_exists; then
    print_warn "VM '$VM_NAME' already exists, skipping creation"
  else
    # utmctl has no create subcommand, but UTM's AppleScript interface does.
    print_step "Creating VM '$VM_NAME' (${VM_CORES} cores, ${VM_MEMORY}M, ${DISK_MIB}M disk)"
    osascript <<EOF
tell application "UTM"
  make new virtual machine with properties {backend:apple, configuration:{ ¬
    name:"$VM_NAME", ¬
    memory:$VM_MEMORY, ¬
    cpu cores:$VM_CORES, ¬
    drives:{ ¬
      {removable:true, source:POSIX file "$ISO"}, ¬
      {guest size:$DISK_MIB}}}}
end tell
EOF
  fi

  # UTM accepts `source` on a removable drive at creation but does not act on
  # it: the resulting Drive entry has ReadOnly=true and no ImageName, so
  # starting fails with "Cannot access resource". UTM keeps drive images inside
  # the bundle's Data/ directory, keyed by ImageName, so place the ISO there and
  # point the entry at it.
  local bundle="$utm_docs/$VM_NAME.utm"
  local iso_id
  iso_id="$(/usr/libexec/PlistBuddy -c "Print :Drive:0:Identifier" "$bundle/config.plist" 2>/dev/null || true)"
  if [ -n "$iso_id" ] &&
    ! /usr/libexec/PlistBuddy -c "Print :Drive:0:ImageName" "$bundle/config.plist" >/dev/null 2>&1; then
    print_step "Attaching ISO to the removable drive (UTM ignores 'source' here)"
    cp "$ISO" "$bundle/Data/$iso_id.iso"
    /usr/libexec/PlistBuddy -c "Add :Drive:0:ImageName string $iso_id.iso" "$bundle/config.plist"
    # UTM caches bundle config in memory; make it re-read from disk.
    osascript -e 'tell application "UTM" to quit' 2>/dev/null || true
    sleep 3
    open -a UTM
    sleep 5
  fi

  print_step "Starting VM"
  utmctl start "$VM_NAME"

  cat <<'GUIDE'

The VM is booting the NixOS installer. In its console:

  sudo -i
  # partition (GPT, 512M ESP + rest as root)
  parted /dev/vda -- mklabel gpt
  parted /dev/vda -- mkpart ESP fat32 1MiB 512MiB
  parted /dev/vda -- set 1 esp on
  parted /dev/vda -- mkpart root ext4 512MiB 100%
  mkfs.fat -F 32 -n ESP /dev/vda1
  mkfs.ext4 -L nixos /dev/vda2
  mount /dev/disk/by-label/nixos /mnt
  mkdir -p /mnt/boot && mount /dev/disk/by-label/ESP /mnt/boot

  nixos-generate-config --root /mnt
  # replace /mnt/etc/nixos/configuration.nix with modules/utm-builder.nix
  nixos-install --no-root-passwd
  reboot

Then, back here:

  scripts/utm-builder-setup.sh register

GUIDE
}

cmd_register() {
  vm_exists || {
    print_err "VM '$VM_NAME' does not exist. Run 'create' first."
    exit 1
  }
  [ -f "$SSH_KEY" ] || {
    print_err "SSH key not found: $SSH_KEY"
    exit 1
  }

  local utm_docs="$HOME/Library/Containers/com.utmapp.UTM/Data/Documents"

  print_step "Ensuring VM is running"
  utmctl start "$VM_NAME" 2>/dev/null || true

  # `utmctl ip-address` only works on the QEMU backend — on Apple
  # Virtualization it fails with "Operation not supported by the backend",
  # because that backend has no guest agent. The VM's NIC is in Shared (NAT)
  # mode, so macOS's bootpd hands out the lease and records it; look the
  # address up by MAC instead.
  local mac
  mac="$(/usr/libexec/PlistBuddy -c "Print :Network:0:MacAddress" \
    "$utm_docs/$VM_NAME.utm/config.plist" 2>/dev/null || true)"
  [ -n "$mac" ] || {
    print_err "Could not read the VM's MAC from its config.plist"
    exit 1
  }
  # Two normalisations are needed: UTM records the MAC uppercase while bootpd
  # writes it lowercase, and bootpd drops leading zeros in each octet
  # (e.g. b6:1c:d9:c4:c7:8 for ...:08).
  mac="$(echo "$mac" | tr '[:upper:]' '[:lower:]')"
  local mac_short
  mac_short="$(echo "$mac" | sed 's/:0\([0-9a-f]\)/:\1/g')"

  print_step "Waiting for the guest's DHCP lease (MAC $mac)"
  local vm_ip=""
  for _ in $(seq 1 60); do
    vm_ip="$(awk -v m1="$mac" -v m2="$mac_short" '
      /^{/ {ip=""; hw=""}
      /ip_address=/ {sub(/.*ip_address=/,""); ip=$0}
      /hw_address=/ {sub(/.*hw_address=1,/,""); hw=tolower($0)}
      /^}/ {if (hw==m1 || hw==m2) print ip}
    ' /var/db/dhcpd_leases 2>/dev/null | tail -1)"
    [ -n "$vm_ip" ] && break
    sleep 5
  done
  [ -n "$vm_ip" ] || {
    print_err "No IP after 5 minutes. Check the VM console in UTM."
    exit 1
  }
  print_step "Guest is at $vm_ip"

  # Offloading is done by the nix daemon, which runs as root, so the key and
  # host key must be readable by root rather than by the logged-in user.
  print_step "Installing builder key for root (sudo)"
  sudo mkdir -p "$ROOT_SSH_DIR"
  sudo cp "$SSH_KEY" "$ROOT_SSH_DIR/utm_builder"
  sudo chmod 600 "$ROOT_SSH_DIR/utm_builder"

  print_step "Recording host key"
  ssh-keyscan -H "$vm_ip" 2>/dev/null | sudo tee -a "$ROOT_SSH_DIR/known_hosts" >/dev/null

  # Format: URI system key maxJobs speedFactor features mandatoryFeatures
  print_step "Registering in $MACHINES_FILE"
  local line="ssh-ng://builder@$vm_ip aarch64-linux $ROOT_SSH_DIR/utm_builder $VM_CORES 1 big-parallel,benchmark"
  if sudo test -f "$MACHINES_FILE" && sudo grep -q "aarch64-linux" "$MACHINES_FILE"; then
    print_warn "An aarch64-linux builder is already registered; review $MACHINES_FILE by hand:"
    sudo grep "aarch64-linux" "$MACHINES_FILE"
  else
    echo "$line" | sudo tee -a "$MACHINES_FILE" >/dev/null
  fi

  # Determinate Nix rewrites /etc/nix/nix.conf, so user settings belong in
  # nix.custom.conf, which that file !includes.
  print_step "Enabling distributed builds in $CUSTOM_CONF"
  sudo grep -q "^builders-use-substitutes" "$CUSTOM_CONF" 2>/dev/null ||
    echo "builders-use-substitutes = true" | sudo tee -a "$CUSTOM_CONF" >/dev/null

  print_step "Restarting the nix daemon"
  sudo launchctl kickstart -k system/systems.determinate.nix-daemon 2>/dev/null ||
    print_warn "Could not restart the daemon; do it manually or reboot"

  print_step "Verifying offload with a trivial aarch64-linux build"
  if nix build --no-link --print-out-paths --impure \
    --expr 'let p = import <nixpkgs> { system = "aarch64-linux"; }; in p.runCommand "offload-test" {} "echo ok > $out"'; then
    print_step "Builder is live. Linux derivations now offload to $VM_NAME."
  else
    print_err "Offload test failed. Debug with:"
    print_err "  sudo ssh -i $ROOT_SSH_DIR/utm_builder builder@$vm_ip"
    exit 1
  fi
}

guest_ip() {
  local utm_docs="$HOME/Library/Containers/com.utmapp.UTM/Data/Documents"
  local mac mac_short
  mac="$(/usr/libexec/PlistBuddy -c "Print :Network:0:MacAddress" \
    "$utm_docs/$VM_NAME.utm/config.plist" 2>/dev/null | tr '[:upper:]' '[:lower:]')"
  mac_short="$(echo "$mac" | sed 's/:0\([0-9a-f]\)/:\1/g')"
  awk -v m1="$mac" -v m2="$mac_short" '
    /^{/ {ip=""; hw=""}
    /ip_address=/ {sub(/.*ip_address=/,""); ip=$0}
    /hw_address=/ {sub(/.*hw_address=1,/,""); hw=tolower($0)}
    /^}/ {if (hw==m1 || hw==m2) print ip}
  ' /var/db/dhcpd_leases 2>/dev/null | tail -1
}

# Drive the NixOS install over SSH. Only possible because the installer ISO is
# our own build with the key baked in (modules/utm-installer.nix); the stock
# ISO has no password and no authorized key, so it can only be driven from the
# VM's graphical console.
cmd_install() {
  local ip
  ip="$(guest_ip)"
  [ -n "$ip" ] || {
    print_err "Could not determine the guest IP"
    exit 1
  }
  print_step "Installing NixOS on $ip"

  local ssh_opts=(-i "$SSH_KEY" -o StrictHostKeyChecking=no
    -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10)

  ssh "${ssh_opts[@]}" "root@$ip" 'bash -s' <<'REMOTE'
set -euxo pipefail
DISK=/dev/vda

# Tolerate a re-run after a failed attempt: unmount anything left over and
# clear existing signatures, otherwise parted stops to ask whether to destroy
# the existing label — and stdin is this heredoc, so the prompt is fatal.
umount -R /mnt 2>/dev/null || true
wipefs -a "$DISK" 2>/dev/null || true

# -s (script mode) so parted never prompts.
parted -s "$DISK" -- mklabel gpt
parted -s "$DISK" -- mkpart ESP fat32 1MiB 512MiB
parted -s "$DISK" -- set 1 esp on
parted -s "$DISK" -- mkpart root ext4 512MiB 100%
udevadm settle

mkfs.fat -F 32 -n ESP "${DISK}1"
mkfs.ext4 -F -L nixos "${DISK}2"

# Mount by device path, not by label: udev has not necessarily created the
# /dev/disk/by-label symlinks yet, and mounting by label here fails with
# "Can't lookup blockdev". The installed system still uses labels, where udev
# is fully up by the time the mounts happen.
udevadm settle
mount "${DISK}2" /mnt
mkdir -p /mnt/boot && mount "${DISK}1" /mnt/boot
nixos-generate-config --root /mnt
curl -fsS -o /mnt/etc/nixos/configuration.nix http://192.168.64.1:8000/configuration.nix

# The installer's nix has flakes disabled, but evaluating the configuration
# trips the flakes gate, so enable it for this invocation rather than
# rebuilding the ISO. The installed system enables both via nix.settings.
nixos-install --no-root-passwd \
  --option extra-experimental-features "nix-command flakes"
REMOTE

  print_step "Install finished; detaching installer media"
  ssh "${ssh_opts[@]}" "root@$ip" 'umount -R /mnt 2>/dev/null; sync' 2>/dev/null || true

  # The whole CD drive has to go, not just its image. Deleting only ImageName
  # leaves an empty USB CD device behind, and with that present the firmware
  # never boots the disk — the VM comes up on something that answers SSH but
  # rejects every key, which looks like a broken install rather than a boot
  # order problem. Removing Drive:0 outright is what actually boots the system.
  local utm_docs="$HOME/Library/Containers/com.utmapp.UTM/Data/Documents"
  utmctl stop "$VM_NAME" 2>/dev/null || true
  sleep 8
  osascript -e 'tell application "UTM" to quit' 2>/dev/null || true
  sleep 4
  if /usr/libexec/PlistBuddy -c "Print :Drive:0:ImageType" \
    "$utm_docs/$VM_NAME.utm/config.plist" 2>/dev/null | grep -q CD; then
    /usr/libexec/PlistBuddy -c "Delete :Drive:0" "$utm_docs/$VM_NAME.utm/config.plist"
    print_step "Removed the installer CD drive"
  fi
  open -a UTM
  sleep 6

  print_step "Booting the installed system"
  utmctl start "$VM_NAME" 2>/dev/null || true
}

case "${1:-}" in
create) cmd_create ;;
install) cmd_install ;;
register) cmd_register ;;
*)
  echo "usage: $(basename "$0") {create|install|register}" >&2
  exit 2
  ;;
esac
