#!/usr/bin/env bash
set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/scripts/common.sh"
select_target "$@"
nix flake update nixpkgs --flake "$config_dir"
exec "$config_dir/rebuild.sh" "$target"
