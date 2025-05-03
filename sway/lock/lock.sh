#!/bin/bash

# FIXME: need to make this work with multiple monitors

NOISE_PATH=$($HOME/Desktop/Rofi-Themer/Scripts/read.sh "i3lock")

if [[ -z $NOISE_PATH ]]
then
    return
fi

eval NOISE="$HOME/$NOISE_PATH"
# this line basically takes screenshot, scales it way down (to blur) then blends with noise PNG. everything happens in pipes, only result is outputted
grim - | magick png:- -scale 10% png:- | composite -blend 15 png:$NOISE png:- png:- | magick png:- -scale 1000% png:/tmp/lock.png

#mpc pause

swaylock -f --image /tmp/lock.png

