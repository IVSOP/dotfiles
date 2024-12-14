#!/usr/bin/bash

brightnessctl set 30% &> /dev/null
BRIGHTNESS=$(brightnessctl -m | python $HOME/.config/i3/brightness/parser.py)
notify-send -t 1000 -c device -h string:x-canonical-private-synchronous:brightness\
    -h int:value:$BRIGHTNESS -i $HOME/.config/i3/brightness/display-brightness.png\
    -a "Brightness Script" "Brightness $NUM [$BRIGHTNESS%]"
