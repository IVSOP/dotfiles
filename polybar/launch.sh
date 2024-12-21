#!/usr/bin/env bash

# I hate not having relative paths but whatever
source $HOME/.config/polybar/env.sh

date "+%H:%M:%S" | tee /tmp/polybar.log

echo "Terminating already running bar instances" >> /tmp/polybar.log

# If all your bars have ipc enabled, you can use
polybar-msg cmd quit 2>&1 >> /tmp/polybar.log

# sometimes polybar-msg will glitch and lock the bar untill it is killed. it gets relauched with the bar
if [ $? = 0 ]; then
    echo "!polybar-msg quit sent, now killing" >> /tmp/polybar.log
    killall polybar-msg
fi

# wait / sleep???
pgrep -x polybar-msg 2>&1 > /dev/null
if [ $? = 0 ]; then
    echo "!Error, using nuclear option" >> /tmp/polybar.log
    #killall -q polybar
    for pid in pgrep polybar
    do
        kill -9 $pid
    done
fi

# this glitches because dunst is still loading when this usually gets executed
# notify-send "Polybar processing restart" -t 1000

# Wait until the processes have been shut down
while pgrep -x polybar >/dev/null; do sleep 0.25; echo "Waiting 0.25" | tee -a /tmp/polybar.log; done

# needs infinite loop, it is mandatory, otherwise no bar will show up

bars=$($HOME/Desktop/Rofi-Themer/Scripts/read.sh "polybar/bar")
while [ -z $bars ]
do
	bars=$($HOME/Desktop/Rofi-Themer/Scripts/read.sh "polybar/bar")
	sleep 0.1
done

for bar in $bars
do
    polybar $bar -c $HOME/.config/polybar/config.ini 2>&1 | tee -a /tmp/polybar.log & disown
done

echo "Bars launched" | tee -a /tmp/polybar.log
