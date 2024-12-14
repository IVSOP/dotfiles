#!/bin/bash
scrot $HOME/.config/i3/lock/screen.png
convert $HOME/.config/i3/lock/screen.png -scale 10% -scale 1000% $HOME/.config/i3/lock/screen.png
NOISE_PATH=$($HOME/I-Themer/ithemer "query0/i3lock")
eval NOISE="$HOME/$NOISE_PATH"
composite -blend 15 $NOISE $HOME/.config/i3/lock/screen.png $HOME/.config/i3/lock/screen.png
