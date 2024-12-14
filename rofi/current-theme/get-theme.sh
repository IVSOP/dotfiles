#!/bin/bash

cd $HOME/.config/rofi/current-theme

mapfile -t ROFI_PATHS < <($HOME/Desktop/Rofi-Themer/Scripts/read.sh "rofi/*")

LINK_NAMES=( "dmenu-theme.rasi" "menu-theme.rasi" "network-manager.conf" "network-manager.rasi" "theme.rasi" )

if [ ${#ROFI_PATHS[@]} -eq ${#LINK_NAMES[@]} ] # check if correct number of data was received
then
	for (( i=0; i<${#ROFI_PATHS[@]}; i++ ))
	do
	    if ! [[ -z ${ROFI_PATHS[$i]} ]]
	    then
	        ln -sfT $HOME/${ROFI_PATHS[$i]} ${LINK_NAMES[$i]} # &>> /tmp/rofi_theme_script.txt
	    fi
	done
fi
