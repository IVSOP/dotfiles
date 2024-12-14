#!/usr/bin/bash

# 100% is actually 60% of real with the math in python script
# increase 5% => real increase of 3%
if [[ $1 == "up" ]]
then
    REAL_NUM="+3%" # used in script
    NUM="+5%" # used to print value
else
    REAL_NUM="3%-"
    NUM="-5%"
fi
brightnessctl set $REAL_NUM &> /dev/null
BRIGHTNESS=$(brightnessctl -m | python $HOME/.config/i3/brightness/parser.py)
notify-send -t 1000 -c device -h string:x-canonical-private-synchronous:brightness\
    -h int:value:$BRIGHTNESS -i $HOME/.config/i3/brightness/display-brightness.png\
    -a "Brightness Script" "Brightness $NUM [$BRIGHTNESS%]"
