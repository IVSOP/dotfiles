#!/bin/bash

THEME_PATH=$($HOME/Desktop/Rofi-Themer/Scripts/read.sh "i3")

if ! [[ -z $THEME_PATH ]]
then
	cd $HOME/.config/i3
	ln -sfT $HOME/$THEME_PATH i3theme
fi
