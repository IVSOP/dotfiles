#!/usr/bin/bash


BG_PATH=$($HOME/Desktop/Rofi-Themer/Scripts/read.sh "background")
while [ -z $BG_PATH ]
do
    BG_PATH=$($HOME/Desktop/Rofi-Themer/Scripts/read.sh "background")
    sleep 0.1
done

killall swaybg
# so it gets expanded. use eval instead???
picture=$(echo "$BG_PATH")
swaybg --image $picture --mode fill
# nitrogen --set-zoom-fill --no-recurse $picture --head=$SCREENS
# swaymsg output "*" bg $picture fill

