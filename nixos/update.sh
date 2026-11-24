#!/usr/bin/env bash
set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/scripts/common.sh"
select_target "$@"
"$config_dir/scripts/pins.sh"

# Update every input that is not explicitly fixed to a commit in flake.nix.
# Hyprland, hy3, Solana, and Anchor keep their reviewed revisions.
mapfile -t inputs < <(jq -r '
    . as $lock | .nodes[.root].inputs | to_entries[] |
    select(.value | type == "string") |
    select($lock.nodes[.value].original.rev == null) |
    .key
' "$config_dir/flake.lock")
if [[ ${#inputs[@]} -eq 0 ]]; then
    printf 'No branch-tracking flake inputs to update.\n' >&2
else
    nix flake update "${inputs[@]}" --flake "path:$config_dir"
fi
"$config_dir/scripts/update-sources.sh"
"$config_dir/rebuild.sh" "$target"

# The rebuild installs Rustup. Update the invoking user's toolchains with it.
rustup_bin=/run/current-system/sw/bin/rustup
rustup_options=(
    --no-self-update
    --profile minimal
    --component rust-src,rustfmt,clippy
    --target wasm32-unknown-unknown
    --target aarch64-linux-android
    --target aarch64-unknown-linux-musl
    --target x86_64-linux-android
    --target x86_64-pc-windows-gnu
)
"$rustup_bin" toolchain install "${rustup_options[@]}" --component rust-analyzer stable
"$rustup_bin" toolchain install "${rustup_options[@]}" nightly
