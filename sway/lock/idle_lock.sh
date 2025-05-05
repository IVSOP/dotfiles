#!/bin/bash

# FIXME: need to make this work with multiple monitors


# this is now in a bash func
# function lock() {
#     NOISE_PATH=$($HOME/Desktop/Rofi-Themer/Scripts/read.sh "i3lock")
#
# 	if [[ -z $NOISE_PATH ]]
# 	then
# 		return
# 	fi
#
#     eval NOISE="$HOME/$NOISE_PATH"
#     # this line basically takes screenshot, scales it way down (to blur) then blends with noise PNG. everything happens in pipes, only result is outputted
#     grim - | magick png:- -scale 10% png:- | composite -blend 15 png:$NOISE png:- png:- | magick png:- -scale 1000% png:/tmp/lock.png
#
#     #mpc pause
#
#     swaylock -f --image /tmp/lock.png
# }

LOCK_TIMEOUT_SECS=$(fend "10min to s" | cut -d' ' -f1)
SCREEN_OFF_TIMEOUT_SECS=$(fend "11min to s" | cut -d' ' -f1)
SUSPEND_TIMEOUT_SECS=$(fend "20min to s" | cut -d' ' -f1)

swayidle -w \
    timeout $LOCK_TIMEOUT_SECS "$HOME/.config/sway/lock/lock.sh" \
    timeout $SCREEN_OFF_TIMEOUT_SECS 'swaymsg "output * dpms off"' resume 'swaymsg "output * dpms on"' \
    timeout $SUSPEND_TIMEOUT_SECS 'systemctl suspend' \
    lock "$HOME/.config/sway/lock/lock.sh" \
    before-sleep "$HOME/.config/sway/lock/lock.sh"

