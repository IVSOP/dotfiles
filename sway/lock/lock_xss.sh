#!/bin/bash

# FIXME: need to make this work with multiple monitors


# adapted from /usr/share/doc/xss-lock/transfer-sleep-lock-i3lock.sh

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
    # this line basically takes screenshot, scales it way down (to blur) then blends with noise PNG. everything happens in pipes, only result is outputted
    grim - | magick png:- -scale 10% png:- | composite -blend 15 png:$NOISE png:- png:- | magick png:- -scale 1000% png:/tmp/lock.png

    #mpc pause
    return
}

# Run after the locker exits
post_lock() {
    rm /tmp/lock.png
    return
}

###############################################################################

pre_lock

lock_options="--image /tmp/lock.png"

# We set a trap to kill the locker if we get killed, then start the locker and
# wait for it to exit. The waiting is not that straightforward when the locker
# forks, so we use this polling only if we have a sleep lock to deal with.
if [[ -e /dev/fd/${XSS_SLEEP_LOCK_FD:--1} ]]; then
    kill_lock() {
        pkill -xu $EUID "$@" swaylock
    }

    trap kill_lock TERM INT

    # we have to make sure the locker does not inherit a copy of the lock fd
    swaylock $lock_options {XSS_SLEEP_LOCK_FD}<&-

    # now close our fd (only remaining copy) to indicate we're ready to sleep
    exec {XSS_SLEEP_LOCK_FD}<&-

    while kill_lock -0; do
        sleep 0.1
    done
else
    trap 'kill %%' TERM INT
    swaylock $lock_options -n &
    wait
fi

post_lock
