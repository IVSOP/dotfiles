#!/usr/bin/env bash

date "+%H:%M:%S" | tee -a /tmp/polybar.log

echo "Terminating already running performance bar instances" | tee -a /tmp/polybar.log

polybar-msg -p $(xprop -name "polybar-performancebar_top_eDP-1" _NET_WM_PID | tr -dc '0-9') cmd quit 2>&1 | tee -a /tmp/polybar.log
if [ "${PIPESTATUS[$(( ${#PIPESTATUS[@]} - 2 ))]}" = 1 ]; then
    echo "!Error killing performance bar top, using nuclear option" | tee -a /tmp/polybar.log
    kill -q $(xprop -name "polybar-performancebar_top_eDP-1" _NET_WM_PID | tr -dc '0-9')
fi
polybar-msg -p $(xprop -name "polybar-performancebar_mid_eDP-1" _NET_WM_PID | tr -dc '0-9') cmd quit 2>&1 | tee -a /tmp/polybar.log
if [ "${PIPESTATUS[$(( ${#PIPESTATUS[@]} - 2 ))]}" = 1 ]; then
    echo "!Error killing performance bar mid, using nuclear option" | tee -a /tmp/polybar.log
    kill -q $(xprop -name "polybar-performancebar_mid_eDP-1" _NET_WM_PID | tr -dc '0-9')
fi
polybar-msg -p $(xprop -name "polybar-performancebar_bot_eDP-1" _NET_WM_PID | tr -dc '0-9') cmd quit 2>&1 | tee -a /tmp/polybar.log
if [ "${PIPESTATUS[$(( ${#PIPESTATUS[@]} - 2 ))]}" = 1 ]; then
    echo "!Error killing performance bar bot, using nuclear option" | tee -a /tmp/polybar.log
    kill -q $(xprop -name "polybar-performancebar_bot_eDP-1" _NET_WM_PID | tr -dc '0-9')
fi
