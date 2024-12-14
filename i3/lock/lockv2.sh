#!/bin/bash
#take screenshot
scrot /tmp/screen.png
#create blurry screenshot
convert /tmp/screen.png -scale 10% -scale 1000% /tmp/screen.png
#add icon
[[ -f <ICON> ]] && convert /tmp/screen.png <ICON> -gravity center -composite -matte /tmp/screen.png
i3lock -i /tmp/screen.png
rm /tmp/screen.png
