#!/usr/bin/env bash
# Script to create Sway config based on i3 config with Wayland-compatible replacements

set -e

SWAY_CONFIG_DIR="$HOME/.config/sway"
I3_CONFIG="$HOME/dots/i3/.config/i3/config"

# Create sway config directory
mkdir -p "$SWAY_CONFIG_DIR"

# Copy i3 config as base
cp "$I3_CONFIG" "$SWAY_CONFIG_DIR/config"

# Apply Wayland-compatible replacements
sed -i 's/exec_always sxhkd/# exec_always sxhkd  # Removed: X11-only, use Sway bindings instead/g' "$SWAY_CONFIG_DIR/config"
sed -i 's/exec --no-startup-id picom -CGb/# exec --no-startup-id picom  # Removed: X11 compositor, Sway has built-in compositing/g' "$SWAY_CONFIG_DIR/config"
sed -i 's/xbacklight/brightnessctl set/g' "$SWAY_CONFIG_DIR/config"
sed -i 's/i3-sensible-terminal/ghostty/g' "$SWAY_CONFIG_DIR/config"

# Add Sway-specific configuration at the end
cat >> "$SWAY_CONFIG_DIR/config" << 'EOF'

# ==========================================
# SWAY-SPECIFIC CONFIGURATION
# ==========================================

# Output configuration (monitors)
# List outputs: swaymsg -t get_outputs
# output * bg ~/.config/sway/wallpaper.png fill

# Input configuration
input type:keyboard {
    xkb_options caps:escape
}

input type:touchpad {
    tap enabled
    natural_scroll enabled
}

# Idle configuration - DISABLED for headless VNC access
# Keep display always on for remote access
# exec swayidle -w \
#     timeout 300 'swaylock -f' \
#     timeout 600 'swaymsg "output * dpms off"' \
#     resume 'swaymsg "output * dpms on"' \
#     before-sleep 'swaylock -f'

# WayVNC auto-start (handled by systemd service)
# exec systemctl --user start wayvnc

# Clipboard manager for Wayland
exec wl-paste --watch cliphist store

# Include additional configs
include /etc/sway/config.d/*
include ~/.config/sway/config.d/*

EOF

echo "Sway config created at $SWAY_CONFIG_DIR/config"
echo "Based on i3 config with Wayland compatibility fixes"
