#!/bin/bash

# adapted from /usr/share/doc/xss-lock/transfer-sleep-lock-i3lock.sh

# Example locker script -- demonstrates how to use the --transfer-sleep-lock
# option with i3lock's forking mode to delay sleep until the screen is locked.

## CONFIGURATION ##############################################################

# Run before starting the locker
pre_lock() {
     # get screenshot and make it blurry with color
    # -q 10 ????????
    NOISE_PATH=$($HOME/Desktop/Rofi-Themer/Scripts/read.sh "i3lock")

	if [[ -z $NOISE_PATH ]]
	then
		return
	fi

    eval NOISE="$HOME/$NOISE_PATH" # cursed
    # "-" is used to receive from stding and output into stdout
    # just saving to file normally worked better wtf
    #SCREENSHOT=$(scrot -q 10 - | convert png:- -scale 10% -scale 1000% png:- | composite -blend 15 png:$NOISE png:- rgb:-) # | convert png:- RGB:-)
    # this is slower but puts convert in the end which doesnt bug when converting to rgb
    # wtf file doesnt seem to fit in variable will just store in a normal file
    #scrot -q 10 - | composite -blend 15 png:$NOISE png:- png:- | convert png:- -scale 10% -scale 1000% png:$HOME/.config/i3/lock/screen.png
    # scrot is weird, using 90 works 100 times faster for the same filesize
    # this line basically takes screenshot, scales it way down (to blur) then blends with noise PNG. everything happens in pipes, only result is outputted
    scrot -q 90 - | convert png:- -scale 10% png:- | composite -blend 15 png:$NOISE png:- png:- | convert png:- -scale 1000% png:/tmp/lock.png

    #mpc pause
    return
}

# Run after the locker exits
post_lock() {
    rm /tmp/screen.png
    return
}

###############################################################################

pre_lock

i3lock_options="--image /tmp/lock.png"

# We set a trap to kill the locker if we get killed, then start the locker and
# wait for it to exit. The waiting is not that straightforward when the locker
# forks, so we use this polling only if we have a sleep lock to deal with.
if [[ -e /dev/fd/${XSS_SLEEP_LOCK_FD:--1} ]]; then
    kill_i3lock() {
        pkill -xu $EUID "$@" i3lock
    }

    trap kill_i3lock TERM INT

    # we have to make sure the locker does not inherit a copy of the lock fd
    i3lock $i3lock_options {XSS_SLEEP_LOCK_FD}<&-

    # now close our fd (only remaining copy) to indicate we're ready to sleep
    exec {XSS_SLEEP_LOCK_FD}<&-

    while kill_i3lock -0; do
        sleep 0.1
    done
else
    trap 'kill %%' TERM INT
    # i3lock -n --image <(echo "$SCREENSHOT")
    i3lock $i3lock_options -n &
    wait
fi

post_lock
