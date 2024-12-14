#!/bin/bash

# close any running dunst processes
pidof dunst && killall dunst

# start dunst in the background
# DUNST_PATH=$($HOME/I-Themer/themer "query0/dunst")
#dunst -config $(echo "$HOME/$DUNST_PATH") &
dunst &
