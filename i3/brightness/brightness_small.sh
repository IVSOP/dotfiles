#!/usr/bin/bash

# 100% is actually 60% of real
# increase 2% => real increase of 1.2%
if [[ $1 == "up" ]]
then
    NUM="+1.2%"
    DISPLAY_NUM="+2%"
else
    NUM="1.2%-"
    DISPLAY_NUM="-2%"
fi
brightnessctl set $NUM 2>&1 > /dev/null
BRIGHTNESS=$(brightnessctl -m | python $HOME/.config/i3/brightness/parser.py)
notify-send -t 1000 -c device -h string:x-canonical-private-synchronous:brightness\
    -h int:value:$BRIGHTNESS -i $HOME/.config/i3/brightness/display-brightness.png\
    -a "Brightness Script" "Brightness $DISPLAY_NUM [$BRIGHTNESS%]"
