#!/bin/bash

cd $HOME/.config/dunst

DUNSTRC_PATH=$($HOME/Desktop/Rofi-Themer/Scripts/read.sh "dunst")

if [[ -z  $DUNSTRC_PATH ]]
then
	# invalid, maybe the daemon hasnt started yet, do nothing for now
	echo "Error"
else
    ln -sfT $HOME/$DUNSTRC_PATH dunstrc # &>> /tmp/dunst_theme_script.txt
fi
