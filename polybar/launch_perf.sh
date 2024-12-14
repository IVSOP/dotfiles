#!/usr/bin/env bash

echo "Launching performance bars" | tee -a /tmp/polybar.log

date "+%H:%M:%S" | tee -a /tmp/polybar.log

mapfile -t bars < $HOME/.config/i3/themes/current-theme/perf-bar

polybar ${bars[0]} -c $HOME/.config/polybar/config.ini 2>&1 | tee -a /tmp/polybar.log & disown
polybar ${bars[1]} -c $HOME/.config/polybar/config.ini 2>&1 | tee -a /tmp/polybar.log & disown
polybar ${bars[2]} -c $HOME/.config/polybar/config.ini 2>&1 | tee -a /tmp/polybar.log & disown

echo "Bars launched" | tee -a /tmp/polybar.log
