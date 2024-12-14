#!/usr/bin/bash

# if you uncomment this line, ehenever sound is increased or decreased it gets unmuted
#pactl set-sink-mute @DEFAULT_SINK@ 0 2>&1 > /dev/null
pactl set-sink-volume @DEFAULT_SINK@ $1% 2>&1 > /dev/null
VOL=$(pactl get-sink-volume @DEFAULT_SINK@ | python3 $HOME/.config/i3/sound/parser.py)
# scrapped this because icons were different sizes and looked weird
#if [ $VOL -ge 65 ]
#then
#    IMG="high"
#else 
#    if [ $VOL -ge 35 ]
#    then    
#        IMG="low"
#    else
#        IMG="off"
#    fi
#fi
# changes color of bar if muted
if [[ $(pactl get-sink-mute @DEFAULT_SINK@ | cut -c 7-) == "no" ]]
then
    COLOR=""
else
    COLOR="-h string:hlcolor:#707880"
fi

IMG="high"

DESC=$($HOME/.config/i3/sound/get-sink-description.sh)

# the first -h is to make repeated notifications replace each other
notify-send -t 1000 -c device -h string:x-canonical-private-synchronous:volume\
    -h int:value:$VOL $COLOR -i  $HOME/.config/i3/sound/volume-$IMG.png "Volume $1% $DESC"
