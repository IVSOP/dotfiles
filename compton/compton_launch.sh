#!/bin/bash

# killall compton
# while pgrep -x compton >/dev/null; do sleep 1; done
# compton --unredir-if-possible --config $HOME/.config/compton/compton.conf -b > /dev/null

killall picom
while pgrep -x picom >/dev/null; do sleep 1; done
#picom --unredir-if-possible --config $HOME/.config/compton/compton.conf -b > /dev/null
picom --config $HOME/.config/compton/picom.conf -b > /dev/null

# killall compfy
# while pgrep -x compfy >/dev/null; do sleep 1; done
# compfy --config $HOME/.config/compton/compfy.conf -b > /dev/null
