#!/usr/bin/env bash

# process id is NOT received as argument into $1
#PID=$1
# I changed it to automatically get the bars pid, but it's sketchy

echo "Toggling modules" | tee -a /tmp/polybar.log

PID=$(xprop -name "polybar-custombar_eDP-1" _NET_WM_PID | tr -dc '0-9')

# was too lazy to do this automatically
# in the future make theme file that saves current bars' name
re='^[0-9]+$'
if ! [[ $PID =~ $re ]] ; then
   PID=$(xprop -name "polybar-custombar-blue_eDP-1" _NET_WM_PID | tr -dc '0-9')
fi

polybar-msg -p $PID action "#filesystem2.module_toggle" 2>&1 | tee -a /tmp/polybar.log
polybar-msg -p $PID action "#temperature.module_toggle" 2>&1 | tee -a /tmp/polybar.log
polybar-msg -p $PID action "#cpu2.module_toggle" 2>&1 | tee -a /tmp/polybar.log
polybar-msg -p $PID action "#memory2.module_toggle" 2>&1 | tee -a /tmp/polybar.log
# mesma cena que em cima
polybar-msg -p $PID action "#memory.module_toggle" 2>&1 | tee -a /tmp/polybar.log
polybar-msg -p $PID action "#memory2-blue.module_toggle" 2>&1 | tee -a /tmp/polybar.log
