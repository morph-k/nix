SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

HOSTNAME ?= $(shell hostname)
UNAME_S := $(shell uname -s)

EDIT_FLAKE := nvim flake.nix

# Source files that affect the build — used for stamp-based caching
NIX_SOURCES := $(shell find . -path ./result -prune -o \( -name '*.nix' -o -name '*.kbd' -o -name '*.lock' \) -print 2>/dev/null)

ifeq ($(UNAME_S),Linux)
	# Local NixOS rebuild for the current host
	SWITCH_CMD := nixos-rebuild switch --flake '.\#$(HOSTNAME)' --impure --sudo
	BUILD_CMD  := nixos-rebuild build  --flake '.\#$(HOSTNAME)'
	EDIT_HOME := nvim hosts/$(HOSTNAME)/configuration.nix
	EDIT_CONF := nvim hosts/$(HOSTNAME)/home.nix
	EDIT_DEF := nvim hosts/$(HOSTNAME)/default.nix
endif
ifeq ($(UNAME_S),Darwin)
	BUILD_CMD  := nix build --experimental-features 'nix-command flakes' '.\#darwinConfigurations.$(HOSTNAME).system'
	SWITCH_CMD := sudo sh -c 'rm -rf /etc/shells && ./result/sw/bin/darwin-rebuild switch --flake .'
	EDIT_HOME := nvim hosts/$(HOSTNAME)/configuration.nix
	EDIT_CONF := nvim hosts/$(HOSTNAME)/home.nix
	EDIT_DEF := nvim hosts/$(HOSTNAME)/default.nix
endif

# Allow customizing SSH behavior (works fine over Tailscale IP or MagicDNS)
export NIX_SSHOPTS ?= -o ServerAliveInterval=30 -o ServerAliveCountMax=10

ef:
	$(EDIT_FLAKE)

ed:
	$(EDIT_DEF)
eh:
	$(EDIT_CONF)
ec:
	$(EDIT_HOME)

# .build-stamp tracks whether ./result is up-to-date with sources.
# If no .nix, .kbd, or .lock files changed since last build, skip rebuild.
.build-stamp: $(NIX_SOURCES)
	$(BUILD_CMD)
	@touch $@

build: .build-stamp

# Force a full rebuild regardless of source changes
rebuild:
	$(BUILD_CMD)
	@touch .build-stamp

switch: .build-stamp
	$(SWITCH_CMD)

.PHONY: build switch rebuild

wsl-build:
	nix build .#nixosConfigurations.win-wsl.config.system.build.installer
	echo "The rootfs tarball can then be found under ./result/tarball/nixos-wsl-x86_64-linux.tar.gz"
	echo "croc send ./result/tarball/nixos-wsl-x86_64-linux.tar.gz"

push-cachix: .build-stamp
	CACHIX_AUTH_TOKEN=$$(agenix -d secrets/cachix-token.age 2>/dev/null) cachix push jedimaster ./result

update:
	sudo nix flake update

fmt:
	alejandra .

# Build-and-switch targets for each host
# These combine build + switch for local execution on each host

# macmini-darwin (Darwin)
macmini-build-and-switch:
	nix build --experimental-features 'nix-command flakes' '.\#darwinConfigurations.macmini-darwin.system' --impure
	sudo sh -c 'rm -rf /etc/shells && ./result/sw/bin/darwin-rebuild switch --flake .'

# xps17-nixos (NixOS) — DISABLED: host not wired into flake outputs
# xps17-build-and-switch:
# 	nixos-rebuild build --flake '.\#xps17-nixos'
# 	nixos-rebuild switch --flake '.\#xps17-nixos' --impure --sudo

# optiplex-nixos (NixOS)
optiplex-build-and-switch:
	nixos-rebuild build --flake '.\#optiplex-nixos'
	nixos-rebuild switch --flake '.\#optiplex-nixos' --impure --sudo

# t480-nixos (NixOS)
t480-build-and-switch:
	nixos-rebuild build --flake '.\#t480-nixos'
	nixos-rebuild switch --flake '.\#t480-nixos' --impure --sudo

# Remote building from any machine (including Mac). Override REMOTE_HOST as needed.
# Requires: SSH access to the target via tailscale or direct connection
REMOTE_HOST ?= optiplex-nixos
REMOTE_USER ?= morph
REMOTE_NIX_DIR ?= ~/nix
REMOTE := $(REMOTE_USER)@$(REMOTE_HOST)

remote-switch:
	@echo "Building and switching on $(REMOTE_HOST)..."
	ssh $(REMOTE) "cd $(REMOTE_NIX_DIR) && git pull && make switch"

remote-build:
	@echo "Building on $(REMOTE_HOST)..."
	ssh $(REMOTE) "cd $(REMOTE_NIX_DIR) && git pull && make build"

# xps-deploy DISABLED: xps17-nixos not wired into flake outputs
# xps-deploy:
# 	nix run nixpkgs#nixos-rebuild -- switch --flake '.#xps17-nixos' \
# 		--target-host $(REMOTE) \
# 		--build-host $(REMOTE) \
# 		--sudo

optiplex-deploy:
	nix run nixpkgs#nixos-rebuild -- switch --flake '.#optiplex-nixos' \
		--target-host morph@optiplex-nixos \
		--build-host morph@optiplex-nixos \
		--sudo

optiplex-build-remote:
	nix run nixpkgs#nixos-rebuild -- build --flake '.#optiplex-nixos' \
		--build-host morph@optiplex-nixos

# Build only (no switch) on remote builder — DISABLED: xps17-nixos not in flake
# xps-build-remote:
# 	nix run nixpkgs#nixos-rebuild -- build --flake '.#xps17-nixos' \
# 		--build-host $(REMOTE)

clean:
	@if [ "$(UNAME_S)" = "Linux" ]; then \
		sudo nix-collect-garbage --delete-older-than 14d; \
		nix-collect-garbage --delete-older-than 14d; \
		echo "Optimizing store with hardlinks..."; \
		sudo nix-store --optimise; \
	else \
		nix-collect-garbage --delete-older-than 14d; \
		echo "Optimizing store with hardlinks..."; \
		nix-store --optimise; \
	fi
	@rm -f .build-stamp
	@if [ -e "result" ]; then \
		unlink result; \
	else \
		echo "'result' symlink does not exist."; \
	fi

optimize:
	@echo "Collecting garbage and optimizing nix store..."
	@if [ "$(UNAME_S)" = "Linux" ]; then \
		sudo nix-collect-garbage -d; \
		nix-collect-garbage -d; \
		sudo nix-store --optimise; \
	else \
		nix-collect-garbage -d; \
		nix-store --optimise; \
	fi
	@echo "Optimization complete!"
