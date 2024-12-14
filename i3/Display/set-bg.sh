#!/usr/bin/bash

let SCREENS=$(xrandr --listactivemonitors| wc -l)-1
while [ $SCREENS -gt 0 ]
do
	let SCREENS-=1
	BG_PATH=$($HOME/Desktop/Rofi-Themer/Scripts/read.sh "background")
	if ! [[ -z $BG_PATH ]]
	then
		picture=$(echo "$BG_PATH")
		nitrogen --set-zoom-fill --no-recurse $picture --head=$SCREENS
	fi
done
