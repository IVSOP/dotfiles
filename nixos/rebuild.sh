#!/usr/bin/env bash
set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/scripts/common.sh"
select_target "$@"
sync_configuration
sudo nixos-rebuild switch --flake "path:/etc/nixos#$target"
