#!/bin/bash

# toggle bar
$HOME/.config/polybar/module-toggler.sh

my_path=$HOME/.config/kitty

if [ $(cat $my_path/status) = "on" ]
then
    cp $my_path/new.conf $my_path/kitty.conf
    echo "off" > $my_path/status
    notify-send -t 1000 "cheating off"
else
    cp $my_path/cheat.conf $my_path/kitty.conf
    echo "on" > $my_path/status
    notify-send -t 1000 "cheating on"
fi
