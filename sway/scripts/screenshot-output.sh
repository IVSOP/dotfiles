#!/usr/bin/env bash
#
# Select a monitor, or capture the focused one with --focused; save as AVIF.
set -uo pipefail

. "$(dirname "$(realpath "$0")")/screenshot-common.sh"

focused=false
case "${1:-}" in
    --focused) focused=true ;;
    "") pkill slurp && exit 0 ;;
    *) printf 'Usage: %s [--focused]\n' "$0" >&2; exit 2 ;;
esac

stamp="$(date +%Y_%m_%d-%H%M%S)"
raw="${XDG_RUNTIME_DIR:-/tmp}/screenshot-$stamp.ppm"

trap 'unfreeze_screen; rm -f "$raw"' EXIT INT TERM

if "$focused"; then
    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        output="$(hyprctl -j monitors | jq -er '.[] | select(.focused) | .name')" || exit 1
    else
        output="$(swaymsg -t get_outputs -r | jq -er '.[] | select(.focused) | .name')" || exit 1
    fi
    # Capture by output name so grim handles scaling and rotation correctly.
    grim -o "$output" -t ppm - > "$raw" || exit 1
else
    freeze_screen
    geometry="$(select_region output)" || exit 0
    [ -n "$geometry" ] || exit 0
    capture_raw "$geometry" > "$raw" || exit 1
    unfreeze_screen
fi

out="$SHOT_DIR/$stamp.avif"

# The clipboard copy and the AVIF encode both read the same raw pixels and have
# nothing to say to each other, so they run at the same time.
#
# Fully detached, and deliberately never waited on: wl-copy forks a server that
# lives until the clipboard is replaced, and it keeps whatever descriptors it
# inherited open. Waiting on it, or leaving it holding this script's stdout,
# hangs the script forever. ffmpeg keeps its own handle on "$raw", so the trap
# below is free to unlink it out from under this.
copy_png_to_clipboard "$raw" </dev/null >/dev/null 2>&1 &

if encode_avif "$raw" "$out"; then
    notify "Screenshot saved" "$out"
else
    notify "Screenshot failed" "Could not encode $out"
    exit 1
fi
