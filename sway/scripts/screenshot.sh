#!/bin/sh

pkill slurp || hyprshot --freeze $@ --raw |
  satty --filename - \
    --early-exit \
    --actions-on-enter save-to-clipboard \
    --save-after-copy \
    --actions-on-escape "save-to-clipboard,save-to-file" \
    --output-filename "$HOME/Pictures/Screenshots/$(date +%Y_%m_%d-%H%M%S).png" \
    --copy-command 'wl-copy'

