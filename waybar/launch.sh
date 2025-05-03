#!/bin/bash

cd $HOME/.config/waybar

date "+%H:%M:%S" | tee /tmp/waybar.log

echo "Terminating already running bar instances" >> /tmp/waybar.log

killall waybar

mapfile -t CONFIGS < <($HOME/Desktop/Rofi-Themer/Scripts/read.sh "waybar")
LINK_NAMES=( "config.jsonc" "style.css" )
if [ ${#CONFIGS[@]} -eq ${#LINK_NAMES[@]} ] # check if correct number of data was received
then
	for (( i=0; i<${#CONFIGS[@]}; i++ ))
	do
	    if ! [[ -z ${CONFIGS[$i]} ]]
	    then
	        ln -sfT $HOME/${CONFIGS[$i]} ${LINK_NAMES[$i]} # &>> /tmp/rofi_theme_script.txt
	    fi
	done
fi

waybar

echo "Bars launched" | tee -a /tmp/waybar.log
