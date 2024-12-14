#!/usr/bin/bash

let ACTIVE_SCREENS=$(xrandr --listactivemonitors | wc -l)-1
# for some reason this does not list all monitors
#let AVAILABLE_SCREENS=$(xrandr --listmonitors | wc -l)-1
let AVAILABLE_SCREENS=$(xrandr | grep -wc "connected")

waitForXrandr () {
    while [ $(pgrep xrandr) ]
    do
        sleep 0.1;
    done
}

if [ $AVAILABLE_SCREENS = 1 ]
then
    notify-send -u normal -t 1000 -h string:x-canonical-private-synchronous:display -i /usr/share/icons/HighContrast/32x32/devices/video-display.png "No monitors detected"
else
    if [ $ACTIVE_SCREENS -gt 1 ]
    then 
        xrandr --output HDMI-1 --off
        waitForXrandr
        notify-send -u normal -t 1000 -h string:x-canonical-private-synchronous:display -i /usr/share/icons/HighContrast/32x32/devices/video-display.png "Screen script" "HDMI-1 is now off"
    else
        xrandr --output HDMI-1 --auto --same-as eDP-1
        waitForXrandr
        notify-send -u normal -t 1000 -h string:x-canonical-private-synchronous:display -i /usr/share/icons/HighContrast/32x32/devices/video-display.png "Screen script" "Output is now mirrored to HDMI-1"
    fi
fi
