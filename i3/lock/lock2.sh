#!/bin/bash
i3lock -i $HOME/.config/i3/lock/screen.png
# & PID=$!
#wait $PID
rm $HOME/.config/i3/lock/screen.png
#pgrep polybar > /dev/null
#if [ $? -eq 1 ]
#then
#	notify-send -t 1500 -h string:x-canonical-private-synchronous:volume "Polybar was shut down, relaunching"
#	$HOME/.config/polybar/launch.sh & disown
#	echo "hello" > ~/hello.txt
#fi
