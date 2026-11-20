#!/usr/bin/env bash

# Use the same brightness scale for the adjustment and the popup.
result=$(brightnessctl -c backlight -m -e4 -n2 set "$1") || exit
IFS=, read -r _ _ _ percentage _ <<< "$result"

notify-send -t 1000 -c device -h string:x-canonical-private-synchronous:brightness \
    -h "int:value:${percentage%\%}" "Brightness $percentage"
