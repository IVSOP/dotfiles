#!/usr/bin/env bash
#
# Select a region (or a monitor), annotate it in satty, save the result as AVIF.
set -uo pipefail

. "$(dirname "$(realpath "$0")")/screenshot-common.sh"

# Pressing the key again while a selection is up cancels instead of stacking.
pkill slurp && exit 0

mode=region
while [ $# -gt 0 ]; do
    case "$1" in
        -m | --mode) mode="${2:-region}"; shift 2 ;;
        *) shift ;;
    esac
done

stamp="$(date +%Y_%m_%d-%H%M%S)"
scratch="${XDG_RUNTIME_DIR:-/tmp}"
raw="$scratch/screenshot-$stamp.ppm"
annotated="$scratch/screenshot-$stamp.png"

trap 'unfreeze_screen; rm -f "$raw" "$annotated"' EXIT INT TERM

freeze_screen
geometry="$(select_region "$mode")" || exit 0
[ -n "$geometry" ] || exit 0

capture_raw "$geometry" > "$raw" || exit 1
# Nothing else needs the screen held still, and the encode below is slow.
unfreeze_screen

# satty's image loader reads PNM, so it takes grim's raw pixels as-is and the
# PNG that used to sit between the two never gets encoded or decoded.
# satty would otherwise announce the scratch PNG below as if it were the
# screenshot; the only notification worth showing is the one for the AVIF.
satty --filename "$raw" \
    --disable-notifications \
    --early-exit \
    --actions-on-enter save-to-clipboard \
    --save-after-copy \
    --actions-on-escape "save-to-clipboard,save-to-file" \
    --output-filename "$annotated" \
    --copy-command 'wl-copy'

# satty can only write PNG/JPEG/WebP, so its output is a scratch file in the
# runtime dir; only the AVIF re-encode of it reaches ~/Pictures. No file at all
# means the annotation window was closed without saving.
[ -f "$annotated" ] || exit 0

out="$SHOT_DIR/$stamp.avif"
if encode_avif "$annotated" "$out"; then
    notify "Screenshot saved" "$out"
else
    notify "Screenshot failed" "Could not encode $out"
    exit 1
fi
