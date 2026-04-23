#!/bin/bash
# Works with multiple monitors by handling each output separately

NOISE_PATH=$($HOME/Desktop/Rofi-Themer/Scripts/read.sh "i3lock")
if [[ -z $NOISE_PATH ]]; then
    exit
fi
eval NOISE="$HOME/$NOISE_PATH"

LOCK_ARGS="-f"

# Get all output names from swaymsg
outputs=$(swaymsg -t get_outputs | jq -r '.[].name')

for output in $outputs; do
    TMP_FILE="/tmp/lock_${output}.png"

    # Capture only this output with -o flag
    grim -o "$output" - \
        | magick png:- -scale 10% png:- \
        | composite -blend 15 png:$NOISE png:- png:- \
        | magick png:- -scale 1000% "$TMP_FILE"

    LOCK_ARGS="$LOCK_ARGS --image ${output}:${TMP_FILE}"
done

#mpc pause
swaylock $LOCK_ARGS

