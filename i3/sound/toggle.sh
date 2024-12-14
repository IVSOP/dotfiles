#!/usr/bin/bash

pactl set-sink-mute @DEFAULT_SINK@ toggle 2>&1 > /dev/null
if [[ $(pactl get-sink-mute @DEFAULT_SINK@ | cut -c 7-) == "no" ]]
then
    IMG="high"
    MSG=" Unmuted"
    #COLOR="#f87272"
    COLOR=""
else
    IMG="xmark"
    MSG=" Muted"
    COLOR="-h string:hlcolor:#707880"
fi

DESC=$($HOME/.config/i3/sound/get-sink-description.sh)

VOL=$(pactl get-sink-volume @DEFAULT_SINK@ | python $HOME/.config/i3/sound/parser.py)
notify-send -t 1000 -c device -h string:x-canonical-private-synchronous:volume\
    $COLOR -h int:value:$VOL -i $HOME/.config/i3/sound/volume-$IMG.png "$MSG $DESC"
