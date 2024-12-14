#!/bin/bash

cd $HOME/.config/polybar/current-theme

THEME_PATH=$($HOME/Desktop/Rofi-Themer/Scripts/read.sh "polybar/theme")
WINS_PATH=$($HOME/Desktop/Rofi-Themer/Scripts/read.sh "polybar/polywins")

if ! [[ -z $THEME_PATH ]]
then
	ln -sfT $HOME/$THEME_PATH polybar
fi

if ! [[ -z $WINS_PATH ]]
then
	ln -sfT $HOME/$WINS_PATH polywins-colors
fi
