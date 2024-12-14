#!/usr/bin/bash

let ACTIVE_SCREENS=$(xrandr --listactivemonitors | wc -l)-1
# for some reason this does not list all monitors
#let AVAILABLE_SCREENS=$(xrandr --listmonitors | wc -l)-1
let AVAILABLE_SCREENS=$(xrandr | grep -wc "connected")

# just use the wait command??????
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
        xrandr --output HDMI-1 --off --output eDP-1 --auto
        waitForXrandr
        notify-send -u normal -t 1000 -h string:x-canonical-private-synchronous:display -i /usr/share/icons/HighContrast/32x32/devices/video-display.png "Screen script" "HDMI-1 is now off"
    else
        waitForXrandr
	xrandr --output HDMI-1 --mode 1920x1080 --rate 60.00 --output eDP-1 --off
        notify-send -u normal -t 1000 -h string:x-canonical-private-synchronous:display -i /usr/share/icons/HighContrast/32x32/devices/video-display.png "Screen script" "HDMI-1 is now on"
    fi
fi

