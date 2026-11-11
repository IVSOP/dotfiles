#!/usr/bin/env bash
set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"

# Read actual selected versions and the shared package pins; no release lookup.
pins=$(nix eval --json --no-update-lock-file "path:$config_dir#lib.manualPins")
rows=$(jq '[.[] | [
    .component,
    (.version + if .revision == "" then "" else " @ " + .revision[0:12] end),
    .location
]]' <<< "$pins")

printf '\nWARNING: Check upstream for newer versions of these pinned components.\n'
printf 'You must update these pins manually; update.sh leaves them unchanged.\n\n'
if command -v gum >/dev/null 2>&1 && [[ -t 1 ]]; then
    jq -r '.[] | @csv' <<< "$rows" |
        gum table --print --columns 'Component,Version / revision,Pin location'
else
    # Keep redirected logs readable and work on machines without gum.
    table=$(jq -r '(["Component", "Version / revision", "Pin location"], .[]) | @tsv' <<< "$rows")
    if command -v column >/dev/null 2>&1; then
        column -t -s $'\t' <<< "$table"
    else
        printf '%s\n' "$table"
    fi
fi
printf '\nFor fixed flake commits: edit flake.nix, then run nix flake update INPUT --flake %q.\n' "$config_dir"
printf 'For package versions: edit pins.nix and refresh the associated source/Cargo hashes.\n'
printf 'General Rust and other unpinned inputs update automatically.\n\n'
