# shellcheck shell=bash
#
# Shared bits for screenshot.sh and screenshot-output.sh.
#
# Screenshots are written straight to AVIF and no PNG is ever encoded on the
# way there: grim hands over raw pixels, ffmpeg turns them into a y4m stream
# and avifenc reads that from stdin. On a 6000x3840 grab the old path burned
# ~1.5s in grim's PNG encoder and another ~1.4s in avifenc's PNG decoder, for
# a file that got thrown away by png2avif.sh anyway.

SHOT_DIR="${SHOT_DIR:-$HOME/Pictures/Screenshots}"
NOTIF_TIMEOUT="${NOTIF_TIMEOUT:-5000}"

# The same knobs ~/Pictures/png2avif.sh uses, so a fresh screenshot is the kind
# of file the batch converter used to produce.
AVIF_QUALITY="${AVIF_QUALITY:-88}"
AVIF_SPEED="${AVIF_SPEED:-4}"

# Given a PNG, avifenc picks these itself: sRGB primaries (1) and transfer (13)
# with the BT.601 matrix (6). y4m carries the range but none of the rest, so we
# state it, and hand ffmpeg the matching matrix (smpte170m is CICP 6).
AVIF_CICP="1/13/6"

# hyprpicker paints a frozen copy of the screen over everything, which is what
# grim ends up capturing, so nothing moves while slurp is up. Hyprland only;
# on sway the selection just happens on the live screen.
freeze_screen() {
    [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || return 0
    command -v hyprpicker >/dev/null 2>&1 || return 0
    hyprpicker -r -z &
    FREEZE_PID=$!
    sleep 0.2
}

unfreeze_screen() {
    [ -n "${FREEZE_PID:-}" ] || return 0
    kill "$FREEZE_PID" 2>/dev/null
    FREEZE_PID=
}

select_region() {
    case "$1" in
        region) slurp -d ;;
        output) slurp -or ;;
        *) printf 'unknown mode: %s\n' "$1" >&2; return 2 ;;
    esac
}

# $1: geometry from select_region.  Writes uncompressed RGB to stdout.
# ~70MB for a full desktop, but it is a memcpy rather than a deflate: 90ms
# against the 1500ms grim spends producing the equivalent PNG.
capture_raw() {
    grim -g "$1" -t ppm -
}

# $1: input (any file ffmpeg reads, or "-" for raw pixels on stdin).
# $2: destination .avif
# Encodes into a .part file and renames on success, so an interrupted run can
# never leave a truncated .avif behind (same trick as png2avif.py).
encode_avif() {
    local src="$1" dst="$2" part="$2.part"

    mkdir -p "$(dirname "$dst")" || return 1

    if ffmpeg -v error -f image2pipe -i "$src" \
            -pix_fmt yuv444p10le -color_range pc -colorspace smpte170m \
            -strict -1 -f yuv4mpegpipe - 2>/dev/null |
        avifenc --stdin -q "$AVIF_QUALITY" -s "$AVIF_SPEED" \
            --cicp "$AVIF_CICP" "$part" >/dev/null 2>&1
    then
        mv -f "$part" "$dst"
    else
        rm -f "$part"
        return 1
    fi
}

# Nothing pastes image/avif yet, so the clipboard keeps getting a PNG.
# Compression level 1: this only ever lives in wl-copy's memory.
copy_png_to_clipboard() {
    ffmpeg -v error -f image2pipe -i "$1" -compression_level 1 \
        -f image2pipe -vcodec png - 2>/dev/null |
        wl-copy --type image/png
}

notify() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send "$1" "$2" -t "$NOTIF_TIMEOUT" -a Screenshot
}
