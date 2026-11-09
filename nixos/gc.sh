#!/usr/bin/env bash
set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/scripts/common.sh"
select_target "$@"
sync_configuration
sudo nix-store --gc
sudo nix-collect-garbage -d
sudo nixos-rebuild boot --flake "path:/etc/nixos#$target"
