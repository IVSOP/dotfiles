#!/usr/bin/bash

# Usage: sound.sh +5 | -5 | toggle-mute

case "$1" in
    toggle-mute)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        ;;
    *)
        wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ "${1#[+-]}%${1:0:1}"
        ;;
esac

VOL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
PCT=$(echo "$VOL" | awk '{printf "%.0f", $2 * 100}')

if echo "$VOL" | grep -q MUTED; then
    COLOR="-h string:hlcolor:#707880"
    MUTED=" [MUTED]"
else
    COLOR=""
    MUTED=""
fi

DESC=$(wpctl inspect @DEFAULT_AUDIO_SINK@ | grep 'node.description' | sed 's/.*= "\(.*\)"/\1/')

notify-send -t 1000 -c device -h string:x-canonical-private-synchronous:volume \
    -h "int:value:$PCT" $COLOR "Volume ${PCT}%${MUTED}" "$DESC"
