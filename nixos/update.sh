#!/usr/bin/env bash
set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/scripts/common.sh"
select_target "$@"
"$config_dir/scripts/pins.sh"

# Update every input that is not explicitly fixed to a commit in flake.nix.
# Hyprland, hy3, Solana, Anchor, and Bootvine keep their reviewed revisions.
mapfile -t inputs < <(jq -r '
    . as $lock | .nodes[.root].inputs | to_entries[] |
    select(.value | type == "string") |
    select($lock.nodes[.value].original.rev == null) |
    .key
' "$config_dir/flake.lock")
if [[ ${#inputs[@]} -eq 0 ]]; then
    printf 'No branch-tracking flake inputs to update.\n' >&2
else
    nix flake update "${inputs[@]}" --flake "$config_dir"
fi
"$config_dir/scripts/update-sources.sh"
exec "$config_dir/rebuild.sh" "$target"
